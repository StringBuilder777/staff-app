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

  /// Pantallas que muestran la luz ahora mismo. Se apilan (SITEC, Registro,
  /// lector…), y la que se cierra no debe dejar sin sondeo a la de debajo.
  static int _users = 0;

  /// Arranca el sondeo periódico si nadie lo había arrancado. Cada llamada
  /// necesita su [stop].
  static void start() {
    _users++;
    if (_timer != null) return;
    unawaited(check());
    _timer = Timer.periodic(_interval, (_) => unawaited(check()));
  }

  /// Para el sondeo cuando ya no queda ninguna pantalla que lo use.
  static void stop() {
    if (_users > 0) _users--;
    if (_users > 0) return;
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
