import 'dart:async';
import 'dart:convert';

// `Uint8List` llega vía foundation, que ya se importa para kIsWeb.
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

/// Tipo de registro NFC Forum RTD Text ('T').
const int _rtdTextType = 0x54;

/// Bit 7 del byte de estado RTD Text: 0 = UTF-8, 1 = UTF-16.
const int _utf16Flag = 0x80;

/// Bits 0-5 del byte de estado RTD Text: longitud del código de idioma.
const int _languageLengthMask = 0x3f;

/// Resultado de una operación NFC. El payload siempre es el texto NDEF leído
/// o escrito, por ejemplo: `staffapp:nfc:<token>`.
class NfcOperationResult {
  const NfcOperationResult._({
    required this.success,
    this.payload,
    this.errorMessage,
    this.cancelled = false,
    this.unavailable = false,
  });

  const NfcOperationResult.success(String payload)
    : this._(success: true, payload: payload);

  const NfcOperationResult.error(String message)
    : this._(success: false, errorMessage: message);

  const NfcOperationResult.cancelled()
    : this._(success: false, cancelled: true);

  const NfcOperationResult.unavailable(String message)
    : this._(success: false, errorMessage: message, unavailable: true);

  final bool success;
  final String? payload;
  final String? errorMessage;

  /// La operación se abortó desde la interfaz, no es un fallo que mostrar.
  final bool cancelled;

  /// El lector no se puede usar: el teléfono no tiene NFC, está apagado o la
  /// plataforma no lo admite. Reintentar no sirve hasta que cambie algo fuera
  /// de la app, así que quien lee en bucle tiene que parar aquí.
  final bool unavailable;
}

/// Acceso NFC para Android e iOS.
///
/// En iOS cada operación abre la hoja de lectura del sistema, que tapa la app
/// y se cierra sola a los 60 segundos. Ver [canStayArmed].
///
/// El lector es un recurso único del teléfono, así que la sesión activa se
/// controla con estado estático: empezar una operación invalida la anterior y
/// el lector siempre se cierra al terminar, aunque sea por timeout o por
/// cancelación desde la interfaz. Dejarlo abierto haría que la siguiente
/// tarjeta que se acerque dispare la operación anterior.
class NfcService {
  const NfcService();

  /// Tiempo máximo con el lector abierto esperando una tarjeta.
  static const Duration defaultTimeout = Duration(seconds: 60);

  /// Si el lector puede quedarse armado mientras la pantalla siga visible.
  ///
  /// Solo en Android. En iOS cada lectura abre la hoja del sistema, que tapa la
  /// pantalla y se cierra sola, así que se lee una tarjeta cada vez que el
  /// operador lo pide.
  static bool get canStayArmed => _isAndroid;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// En iOS se deja fuera ISO 18092 (FeliCa): pedirlo obliga a declarar en
  /// Info.plist los códigos de sistema FeliCa y, sin ellos, la sesión falla.
  static Set<NfcPollingOption> get _pollingOptions => _isIos
      ? const {NfcPollingOption.iso14443, NfcPollingOption.iso15693}
      : NfcPollingOption.values.toSet();

  /// La hoja de iOS se cierra a los 60 segundos y lo avisa por
  /// `onSessionErrorIos`. Pero el plugin pierde ese aviso con los códigos de
  /// error que añadió iOS 26, porque no los tiene en su enum. Por eso en iOS la
  /// espera nunca pasa de aquí: sin este tope la pantalla seguiría esperando
  /// una hoja que ya no está.
  static const Duration _iosSheetLimit = Duration(seconds: 65);

  static const String _noCardMessage =
      'No se detectó ninguna tarjeta a tiempo. Inténtalo de nuevo.';

  static Completer<NfcOperationResult>? _activeResult;
  static Completer<void>? _activeClosed;

  /// Cierra la sesión NFC en curso, si la hay, y espera a que el lector quede
  /// libre. La operación pendiente se resuelve como cancelada.
  ///
  /// Hay que llamarla al cerrar la pantalla o el sheet que inició la lectura o
  /// la escritura.
  Future<void> cancel() async {
    final result = _activeResult;
    final closed = _activeClosed;
    if (result == null || closed == null) return;
    if (!result.isCompleted) {
      result.complete(const NfcOperationResult.cancelled());
    }
    await closed.future;
  }

  /// Escribe el payload como registro NDEF de texto en la tarjeta que se
  /// acerque al teléfono. En Android formatea la tarjeta si aún no tiene
  /// estructura NDEF; iOS solo escribe en tarjetas que ya la traen.
  Future<NfcOperationResult> writeTextPayload(
    String payload, {
    Duration timeout = defaultTimeout,
  }) {
    return _runSession(
      timeout: timeout,
      failureMessage:
          'No se pudo escribir la tarjeta. Mantenla apoyada en el teléfono.',
      promptIos: 'Acerca a la parte de arriba del iPhone la tarjeta que vas a '
          'escribir.',
      successMessageIos: 'Tarjeta escrita',
      keepPollingIos: false,
      onTag: (tag, complete) async {
        final message = _buildTextMessage(payload);

        if (_isIos) {
          final ndef = NdefIos.from(tag);
          // A diferencia de Android, iOS no sabe dar formato NDEF a una
          // tarjeta virgen: solo escribe en las que ya traen esa estructura.
          if (ndef == null || ndef.status == NdefStatusIos.notSupported) {
            complete(
              const NfcOperationResult.error(
                'La tarjeta no es compatible con NDEF.',
              ),
            );
            return;
          }
          if (ndef.status == NdefStatusIos.readOnly) {
            complete(
              const NfcOperationResult.error(
                'La tarjeta está protegida contra escritura.',
              ),
            );
            return;
          }
          if (message.byteLength > ndef.capacity) {
            complete(
              NfcOperationResult.error(
                'La credencial ocupa ${message.byteLength} bytes y la tarjeta '
                'solo admite ${ndef.capacity}.',
              ),
            );
            return;
          }
          await ndef.writeNdef(message);
          complete(NfcOperationResult.success(payload));
          return;
        }

        final ndef = NdefAndroid.from(tag);

        if (ndef == null) {
          // Tarjeta virgen sin estructura NDEF: se formatea y se escribe de una
          // sola pasada.
          final formatable = NdefFormatableAndroid.from(tag);
          if (formatable == null) {
            complete(
              const NfcOperationResult.error(
                'La tarjeta no es compatible con NDEF.',
              ),
            );
            return;
          }
          await formatable.format(message);
          complete(NfcOperationResult.success(payload));
          return;
        }

        if (!ndef.isWritable) {
          complete(
            const NfcOperationResult.error(
              'La tarjeta está protegida contra escritura.',
            ),
          );
          return;
        }

        if (message.byteLength > ndef.maxSize) {
          complete(
            NfcOperationResult.error(
              'La credencial ocupa ${message.byteLength} bytes y la tarjeta '
              'solo admite ${ndef.maxSize}.',
            ),
          );
          return;
        }

        await ndef.writeNdefMessage(message);
        complete(NfcOperationResult.success(payload));
      },
    );
  }

  /// Lee el texto NDEF de la tarjeta que se acerque al teléfono.
  Future<NfcOperationResult> readTextPayload({
    Duration timeout = defaultTimeout,
  }) {
    return _runSession(
      timeout: timeout,
      failureMessage: 'No se pudo leer la tarjeta NFC.',
      promptIos: 'Acerca la tarjeta a la parte de arriba del iPhone.',
      successMessageIos: 'Tarjeta leída',
      // El mensaje ya llega leído con la detección, así que seguir buscando
      // tarjetas no estorba.
      keepPollingIos: true,
      onTag: (tag, complete) async {
        const notNdef = NfcOperationResult.error(
          'La tarjeta no contiene datos NDEF.',
        );
        final NdefMessage? message;
        if (_isIos) {
          final ndef = NdefIos.from(tag);
          if (ndef == null || ndef.status == NdefStatusIos.notSupported) {
            complete(notNdef);
            return;
          }
          // El plugin ya leyó el mensaje al detectar la tarjeta. Pedirlo otra
          // vez sería una ida y vuelta más, que falla si la tarjeta se aparta.
          message = ndef.cachedNdefMessage;
        } else {
          final ndef = NdefAndroid.from(tag);
          if (ndef == null) {
            complete(notNdef);
            return;
          }
          message = await ndef.getNdefMessage();
        }

        final payload = message == null ? null : _extractTextPayload(message);
        if (payload == null || payload.isEmpty) {
          complete(
            const NfcOperationResult.error(
              'La tarjeta no contiene una credencial Staff válida.',
            ),
          );
          return;
        }
        complete(NfcOperationResult.success(payload));
      },
    );
  }

  /// [promptIos] y [successMessageIos] son los textos de la hoja de lectura de
  /// iOS: el primero mientras espera la tarjeta y el segundo al cerrarse con
  /// éxito. En Android no se muestran.
  ///
  /// Con [keepPollingIos] la hoja de iOS sigue buscando tarjetas después de
  /// cada detección. Sin eso, una detección fallida (la tarjeta se apartó a
  /// medias) deja la hoja abierta sin leer nada hasta que se cierra sola. La
  /// escritura no lo usa: necesita la tarjeta conectada hasta escribirla y
  /// reiniciar la búsqueda puede desconectarla.
  Future<NfcOperationResult> _runSession({
    required Duration timeout,
    required String failureMessage,
    required String promptIos,
    required String successMessageIos,
    required bool keepPollingIos,
    required Future<void> Function(NfcTag tag, _Complete complete) onTag,
  }) async {
    final availabilityError = await _availabilityError();
    if (availabilityError != null) {
      return NfcOperationResult.unavailable(availabilityError);
    }

    // El lector es único: una operación nueva invalida la que estuviera activa.
    await cancel();

    final result = Completer<NfcOperationResult>();
    final closed = Completer<void>();
    _activeResult = result;
    _activeClosed = closed;

    void complete(NfcOperationResult value) {
      if (!result.isCompleted) result.complete(value);
    }

    Timer? timer;
    NfcOperationResult? outcome;
    try {
      await NfcManager.instance.startSession(
        pollingOptions: _pollingOptions,
        onDiscovered: (tag) async {
          try {
            await onTag(tag, complete);
          } catch (_) {
            complete(NfcOperationResult.error(failureMessage));
          }
        },
        alertMessageIos: promptIos,
        invalidateAfterFirstReadIos: !keepPollingIos,
        // La hoja de iOS se cierra sola al cancelarla o a los 60 segundos. Sin
        // este aviso la operación seguiría esperando una tarjeta que ya no
        // puede llegar.
        onSessionErrorIos: (error) => complete(_sessionClosedResult(error)),
      );
      final limit = _isIos && timeout > _iosSheetLimit
          ? _iosSheetLimit
          : timeout;
      timer = Timer(limit, () {
        complete(const NfcOperationResult.error(_noCardMessage));
      });
      outcome = await result.future;
      return outcome;
    } catch (_) {
      return NfcOperationResult.error(failureMessage);
    } finally {
      timer?.cancel();
      _activeResult = null;
      _activeClosed = null;
      try {
        // En iOS el resultado queda escrito en la hoja mientras se cierra.
        await NfcManager.instance.stopSession(
          alertMessageIos: outcome?.success == true ? successMessageIos : null,
          errorMessageIos:
              outcome != null && !outcome.success && !outcome.cancelled
              ? outcome.errorMessage
              : null,
        );
      } catch (_) {
        // El lector pudo cerrarse solo; no hay nada que recuperar aquí.
      }
      closed.complete();
    }
  }

  Future<String?> _availabilityError() async {
    // `NfcManager.instance` lanza UnsupportedError fuera de Android e iOS, así
    // que la plataforma se comprueba antes de tocarlo.
    if (!_isAndroid && !_isIos) {
      return 'La lectura y escritura NFC solo están disponibles en Android e iOS.';
    }

    try {
      switch (await NfcManager.instance.checkAvailability()) {
        case NfcAvailability.enabled:
          return null;
        case NfcAvailability.disabled:
          return 'El NFC está desactivado. Actívalo en los ajustes del teléfono.';
        case NfcAvailability.unsupported:
          // Es también lo que responde el simulador de iOS.
          return 'Este teléfono no tiene NFC.';
      }
    } catch (_) {
      return 'No se pudo comprobar el NFC del teléfono.';
    }
  }

  /// Traduce el cierre de la hoja de iOS, que llega aparte del resultado, a un
  /// resultado de la operación.
  static NfcOperationResult _sessionClosedResult(
    NfcReaderSessionErrorIos error,
  ) => switch (error.code) {
    NfcReaderErrorCodeIos.readerSessionInvalidationErrorUserCanceled =>
      const NfcOperationResult.cancelled(),
    NfcReaderErrorCodeIos.readerSessionInvalidationErrorSessionTimeout =>
      const NfcOperationResult.error(_noCardMessage),
    // Pasa si se abre otra lectura mientras la hoja anterior aún se cierra.
    NfcReaderErrorCodeIos.readerSessionInvalidationErrorSystemIsBusy =>
      const NfcOperationResult.error(
        'El lector NFC está ocupado. Espera un momento e inténtalo de nuevo.',
      ),
    NfcReaderErrorCodeIos.readerErrorRadioDisabled =>
      const NfcOperationResult.unavailable(
        'El NFC del iPhone está desactivado.',
      ),
    // Es lo que devuelve iOS cuando la app se firmó sin la capacidad NFC.
    NfcReaderErrorCodeIos.readerErrorSecurityViolation =>
      const NfcOperationResult.unavailable(
        'Esta versión de la app no tiene permiso de NFC. Revisa la firma en '
        'Xcode.',
      ),
    _ => const NfcOperationResult.error(
      'Se cerró el lector NFC. Inténtalo de nuevo.',
    ),
  };

  /// Construye un registro RTD Text en UTF-8 con el payload.
  NdefMessage _buildTextMessage(String payload, {String languageCode = 'en'}) {
    final language = ascii.encode(languageCode);
    return NdefMessage(
      records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: Uint8List.fromList([_rtdTextType]),
          identifier: Uint8List(0),
          payload: Uint8List.fromList([
            language.length,
            ...language,
            ...utf8.encode(payload),
          ]),
        ),
      ],
    );
  }

  String? _extractTextPayload(NdefMessage message) {
    for (final record in message.records) {
      // Solo registros RTD Text: una tarjeta puede traer además registros URI o
      // externos que decodificados como texto darían basura.
      if (record.typeNameFormat != TypeNameFormat.wellKnown) continue;
      if (record.type.length != 1 || record.type.first != _rtdTextType) {
        continue;
      }

      final data = record.payload;
      if (data.isEmpty) continue;

      final status = data.first;
      // Las credenciales Staff se escriben siempre como texto UTF-8.
      if ((status & _utf16Flag) != 0) continue;

      final textStart = (status & _languageLengthMask) + 1;
      if (data.length <= textStart) continue;

      try {
        final text = utf8.decode(data.sublist(textStart));
        if (text.trim().isNotEmpty) return text.trim();
      } catch (_) {
        // Registro corrupto: se intenta con el siguiente.
      }
    }
    return null;
  }
}

typedef _Complete = void Function(NfcOperationResult result);
