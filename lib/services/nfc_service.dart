import 'dart:async';
import 'dart:convert';

// `Uint8List` llega vía foundation, que ya se importa para kIsWeb.
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import '../config/backend_config.dart';

/// Tipo de registro NFC Forum RTD Text ('T').
const int _rtdTextType = 0x54;

/// Bit 7 del byte de estado RTD Text: 0 = UTF-8, 1 = UTF-16.
const int _utf16Flag = 0x80;

/// Bits 0-5 del byte de estado RTD Text: longitud del código de idioma.
const int _languageLengthMask = 0x3f;

/// Tipo de registro NFC Forum RTD URI ('U').
const int _rtdUriType = 0x55;

/// Abreviatura RTD URI de `https://`: ahorra esos 8 bytes en la tarjeta.
const int _uriHttpsPrefix = 0x04;

/// Paquete de la app en Android (`applicationId` en
/// android/app/build.gradle.kts). Va en el AAR de las tarjetas con dirección.
const String _androidPackage = 'com.stringbuilder.staffapp.staff_app';

/// Prefijo de las credenciales que emite el backend.
const String _payloadPrefix = 'staffapp:nfc:';

/// Bytes NDEF de una NTAG213, la tarjeta más pequeña para la que se escribe la
/// dirección (ver [NfcService.cardUrl]).
const int _ntag213Capacity = 137;

/// Final de la dirección de una tarjeta (ver [NfcService.cardUrl]): el evento
/// y el token.
final RegExp _cardUrlEnding = RegExp(
  r'#[a-z]/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{12})$',
);

/// Resultado de una operación NFC. El payload siempre es la credencial leída
/// o escrita, por ejemplo: `staffapp:nfc:<token>`.
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

/// Evento de una tarjeta. Va en su dirección (ver [NfcService.cardUrl]) para
/// que la página de `lector-web/` sepa a qué función de accesos llamar.
enum NfcCardEvent {
  hackathon('h'),
  sitec('s');

  const NfcCardEvent(this.code);

  final String code;
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

  /// Cuántas veces se ha llamado a [cancel]. Hasta registrarse en
  /// [_activeResult], una operación compara esta cuenta con la que vio al
  /// empezar: si cambió, la cancelaron mientras arrancaba y no abre el lector.
  static int _cancelCount = 0;

  /// Cierra la sesión NFC en curso, si la hay, y espera a que el lector quede
  /// libre. Las operaciones pendientes se resuelven como canceladas; las que
  /// aún arrancaban, sin llegar a abrir el lector.
  ///
  /// Hay que llamarla al cerrar la pantalla o el sheet que inició la lectura o
  /// la escritura.
  Future<void> cancel() async {
    _cancelCount++;
    await _closeActiveSession();
  }

  /// Cierra la sesión abierta sin tocar las operaciones que aún arrancan. Es
  /// lo que hace una operación nueva con la anterior: con [cancel] se
  /// cancelaría también a sí misma.
  Future<void> _closeActiveSession() async {
    final result = _activeResult;
    final closed = _activeClosed;
    if (result == null || closed == null) return;
    if (!result.isCompleted) {
      result.complete(const NfcOperationResult.cancelled());
    }
    await closed.future;
  }

  /// Dirección que se graba en la tarjeta para abrirla desde un iPhone sin la
  /// app: `<base>/#<evento>/<token>`, con [base] la página publicada de
  /// `lector-web/` ([BackendConfig.cardWebUrl]). El token va tras `#`, que el
  /// navegador no manda al servidor que publica la página.
  ///
  /// Devuelve null si no hay página configurada, si el payload no es una
  /// credencial Staff o si la dirección no cabría en una NTAG213 (unos 38
  /// caracteres entre dominio y ruta). Entonces la tarjeta se escribe como
  /// siempre.
  static String? cardUrl(
    String payload, {
    required NfcCardEvent event,
    String base = BackendConfig.cardWebUrl,
  }) {
    final page = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    if (page.isEmpty || !payload.startsWith(_payloadPrefix)) return null;
    final token = payload.substring(_payloadPrefix.length);
    final url = '$page/#${event.code}/$token';
    if (!_cardUrlEnding.hasMatch(url)) return null;
    // Las tarjetas vírgenes se formatean sin saber cuánto les cabe: una
    // dirección que no entraría en la más pequeña no se usa.
    return _buildUrlMessage(url).byteLength <= _ntag213Capacity ? url : null;
  }

  /// Escribe la credencial en la tarjeta que se acerque al teléfono. En
  /// Android formatea la tarjeta si aún no tiene estructura NDEF; iOS solo
  /// escribe en tarjetas que ya la traen.
  ///
  /// Sin [webUrl] la credencial va como registro de texto. Con [webUrl] (ver
  /// [cardUrl]) va dentro de esa dirección, para que un iPhone sin la app abra
  /// la tarjeta en Safari. Si la dirección no cabe, se escribe solo el texto.
  /// La lectura entiende los dos formatos.
  Future<NfcOperationResult> writeTextPayload(
    String payload, {
    Duration timeout = defaultTimeout,
    String? webUrl,
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
        final text = _buildTextMessage(payload);
        final withUrl = webUrl == null ? null : _buildUrlMessage(webUrl);
        // Donde la dirección no cabe, el texto basta para la app: solo se
        // pierde la lectura sin app en iPhone.
        NdefMessage fitting(int capacity) =>
            withUrl != null && withUrl.byteLength <= capacity ? withUrl : text;

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
          final message = fitting(ndef.capacity);
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
          // Sin estructura NDEF no se sabe cuánto cabe hasta formatear. Va la
          // dirección: [cardUrl] solo da las que caben en una NTAG213.
          await formatable.format(withUrl ?? text);
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

        final message = fitting(ndef.maxSize);
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

  /// Lee la credencial de la tarjeta que se acerque al teléfono, escrita como
  /// texto o como dirección (ver [writeTextPayload]).
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
    // Hasta registrarse en `_activeResult`, `cancel()` no tiene sesión que
    // cerrar: se mira tras cada espera si la cancelaron entretanto. Si no, el
    // lector se abriría igual y la siguiente tarjeta dispararía esta operación.
    final cancelCount = _cancelCount;
    bool cancelledWhileStarting() => _cancelCount != cancelCount;

    final availabilityError = await _availabilityError();
    if (cancelledWhileStarting()) return const NfcOperationResult.cancelled();
    if (availabilityError != null) {
      return NfcOperationResult.unavailable(availabilityError);
    }

    // El lector es único: una operación nueva invalida la que estuviera activa.
    await _closeActiveSession();
    if (cancelledWhileStarting()) return const NfcOperationResult.cancelled();

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

  /// La dirección va primero: el iPhone sin app solo abre la tarjeta si su
  /// primer registro es una dirección. Detrás va un AAR, que Android busca en
  /// todo el mensaje: con él, aunque el lector no esté armado, Android abre
  /// esta app en vez de la dirección en el navegador, y el operador no sale de
  /// la app. No cabe además el texto en una NTAG213, así que la credencial se
  /// lee de la dirección.
  static NdefMessage _buildUrlMessage(String url) {
    final https = url.startsWith('https://');
    return NdefMessage(
      records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          type: Uint8List.fromList([_rtdUriType]),
          identifier: Uint8List(0),
          payload: Uint8List.fromList([
            if (https) _uriHttpsPrefix else 0x00,
            ...utf8.encode(https ? url.substring('https://'.length) : url),
          ]),
        ),
        NdefRecord(
          typeNameFormat: TypeNameFormat.external,
          type: Uint8List.fromList(ascii.encode('android.com:pkg')),
          identifier: Uint8List(0),
          payload: Uint8List.fromList(ascii.encode(_androidPackage)),
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
    return _extractUrlPayload(message);
  }

  /// Credencial de una tarjeta escrita con dirección: el token sale del final
  /// de la dirección, sea cual sea la página, para que las tarjetas sigan
  /// valiendo aunque la página cambie de sitio.
  String? _extractUrlPayload(NdefMessage message) {
    for (final record in message.records) {
      if (record.typeNameFormat != TypeNameFormat.wellKnown) continue;
      if (record.type.length != 1 || record.type.first != _rtdUriType) {
        continue;
      }

      // El primer byte es la abreviatura del esquema, que aquí no hace falta.
      final data = record.payload;
      if (data.length < 2) continue;

      try {
        final match = _cardUrlEnding.firstMatch(utf8.decode(data.sublist(1)));
        if (match != null) return '$_payloadPrefix${match.group(1)}';
      } catch (_) {
        // Registro corrupto: se intenta con el siguiente.
      }
    }
    return null;
  }
}

typedef _Complete = void Function(NfcOperationResult result);
