import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

/// Estado de conexión con las Edge Functions.
///
/// Sustituye al aviso de texto con el modo activo: al operar siempre contra
/// Supabase, lo único que el staff necesita saber de un vistazo es si el
/// backend responde.
class ConnectionStatus {
  const ConnectionStatus._();

  /// `null` mientras se comprueba por primera vez, para no pintar rojo antes
  /// de haber intentado nada.
  static final ValueNotifier<bool?> isOnline = ValueNotifier<bool?>(null);

  static const Duration _interval = Duration(seconds: 30);
  static const Duration _timeout = Duration(seconds: 8);

  static Timer? _timer;

  /// Arranca el sondeo periódico. Es idempotente.
  static void start() {
    if (_timer != null) return;
    unawaited(check());
    _timer = Timer.periodic(_interval, (_) => unawaited(check()));
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Comprueba si el backend responde.
  ///
  /// Cualquier respuesta HTTP cuenta como conectado, incluido un 401 o un 405:
  /// lo que se mide es si hay servidor al otro lado, no si la petición era
  /// válida. Solo un fallo de red o un tiempo agotado cuentan como caído.
  static Future<void> check() async {
    final base = BackendConfig.functionsUrl;
    if (base.isEmpty) {
      isOnline.value = null;
      return;
    }

    try {
      await http.head(Uri.parse('$base/staff-team-from-qr')).timeout(_timeout);
      isOnline.value = true;
    } catch (_) {
      isOnline.value = false;
    }
  }
}
