/// Configuración de endpoints y autenticación para el backend de Staff.
class BackendConfig {
  /// Modo de conexión actual.
  /// - `tunnel`: Usa localtunnel o ngrok para pruebas remotas sin tocar SSL/HTTP.
  /// - `localNetwork`: Usa la IP de tu Mac en la red Wi-Fi (10.0.40.78).
  /// - `cloud`: Conecta directo a Supabase Edge Functions en la nube.
  /// - `simulation`: Simulación local para UI sin backend.
  static BackendMode mode = BackendMode.simulation;

  /// URL de túnel HTTPS (ej. Cloudflare Tunnel `cloudflared tunnel --url http://localhost:54321` o `localtunnel`)
  static String tunnelBaseUrl = 'https://tu-subdominio.trycloudflare.com/functions/v1';

  /// IP local de la Mac en la red Wi-Fi
  static String localNetworkBaseUrl = 'http://10.0.40.78:54321/functions/v1';

  /// URL de producción directa de Supabase Cloud
  static const String cloudBaseUrl =
      'https://uopfoekxkluotowilzaa.supabase.co/functions/v1';

  /// Token JWT del usuario con rol staff/admin para autorizar peticiones.
  static String staffAuthToken = '';

  /// Devuelve la URL base según el modo seleccionado.
  static String get functionsUrl {
    switch (mode) {
      case BackendMode.tunnel:
        return tunnelBaseUrl;
      case BackendMode.localNetwork:
        return localNetworkBaseUrl;
      case BackendMode.cloud:
        return cloudBaseUrl;
      case BackendMode.simulation:
        return '';
    }
  }
}

enum BackendMode {
  tunnel,
  localNetwork,
  cloud,
  simulation,
}
