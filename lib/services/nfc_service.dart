import 'dart:async';
import 'dart:convert';

// `Uint8List` llega vía foundation, que ya se importa para kIsWeb.
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

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
  });

  const NfcOperationResult.success(String payload)
    : this._(success: true, payload: payload);

  const NfcOperationResult.error(String message)
    : this._(success: false, errorMessage: message);

  const NfcOperationResult.cancelled()
    : this._(success: false, cancelled: true);

  final bool success;
  final String? payload;
  final String? errorMessage;

  /// La operación se abortó desde la interfaz, no es un fallo que mostrar.
  final bool cancelled;
}

/// Acceso NFC limitado intencionalmente a Android mientras se define el flujo
/// operativo para otras plataformas.
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
  /// acerque al teléfono. Formatea la tarjeta si aún no tiene estructura NDEF.
  Future<NfcOperationResult> writeTextPayload(
    String payload, {
    Duration timeout = defaultTimeout,
  }) {
    return _runSession(
      timeout: timeout,
      failureMessage:
          'No se pudo escribir la tarjeta. Mantenla apoyada en el teléfono.',
      onTag: (tag, complete) async {
        final message = _buildTextMessage(payload);
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
      onTag: (tag, complete) async {
        final ndef = NdefAndroid.from(tag);
        if (ndef == null) {
          complete(
            const NfcOperationResult.error(
              'La tarjeta no contiene datos NDEF.',
            ),
          );
          return;
        }

        final message = await ndef.getNdefMessage();
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

  Future<NfcOperationResult> _runSession({
    required Duration timeout,
    required String failureMessage,
    required Future<void> Function(NfcTag tag, _Complete complete) onTag,
  }) async {
    final availabilityError = await _availabilityError();
    if (availabilityError != null) {
      return NfcOperationResult.error(availabilityError);
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
    try {
      await NfcManager.instance.startSession(
        pollingOptions: NfcPollingOption.values.toSet(),
        onDiscovered: (tag) async {
          try {
            await onTag(tag, complete);
          } catch (_) {
            complete(NfcOperationResult.error(failureMessage));
          }
        },
      );
      timer = Timer(timeout, () {
        complete(
          const NfcOperationResult.error(
            'No se detectó ninguna tarjeta a tiempo. Inténtalo de nuevo.',
          ),
        );
      });
      return await result.future;
    } catch (_) {
      return NfcOperationResult.error(failureMessage);
    } finally {
      timer?.cancel();
      _activeResult = null;
      _activeClosed = null;
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {
        // El lector pudo cerrarse solo; no hay nada que recuperar aquí.
      }
      closed.complete();
    }
  }

  Future<String?> _availabilityError() async {
    // `NfcManager.instance` lanza UnsupportedError fuera de Android e iOS, así
    // que la plataforma se comprueba antes de tocarlo.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'La lectura y escritura NFC están disponibles por ahora solo en Android.';
    }

    switch (await NfcManager.instance.checkAvailability()) {
      case NfcAvailability.enabled:
        return null;
      case NfcAvailability.disabled:
        return 'El NFC está desactivado. Actívalo en los ajustes del teléfono.';
      case NfcAvailability.unsupported:
        return 'Este teléfono no tiene NFC.';
    }
  }

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
