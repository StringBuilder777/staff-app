import 'package:flutter/material.dart';

/// Misma paleta que el resto de la app; la `_Colors` de main.dart es privada.
class _Palette {
  static const navy = Color(0xFF102A43);
  static const teal = Color(0xFF0FA99A);
  static const muted = Color(0xFF627D98);
  static const indigo = Color(0xFF4F46E5);
  static const background = Color(0xFFF4F7FA);
}

/// Primera pantalla tras el acceso: elegir sobre qué evento se va a trabajar.
///
/// La app da servicio a dos eventos distintos, y el staff necesita saber en
/// cuál está operando antes de tocar nada: los accesos que registre se imputan
/// a ese evento.
class EventSelectionScreen extends StatelessWidget {
  const EventSelectionScreen({
    super.key,
    required this.hackathon,
    this.actions = const [],
  });

  /// Pantalla del hackathon, que es el flujo ya operativo.
  final Widget hackathon;

  /// Acciones de la barra superior (configuración y cerrar sesión), que viven
  /// en main.dart junto al resto del estado de sesión.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _Palette.background,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: actions,
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Selecciona el evento',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: _Palette.navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Los accesos que registres se guardan en el evento que elijas.',
              style: TextStyle(color: _Palette.muted, fontSize: 15),
            ),
            const SizedBox(height: 28),
            _EventCard(
              title: 'Hackathon',
              subtitle: 'Registro de equipos, credenciales y accesos',
              icon: Icons.code_rounded,
              color: _Palette.teal,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => hackathon)),
            ),
            const SizedBox(height: 16),
            _EventCard(
              title: 'SITEC',
              subtitle: 'Pendiente de configurar',
              icon: Icons.school_rounded,
              color: _Palette.indigo,
              enabled: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const _SitecScreen()),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Tarjeta grande de evento. Alta a propósito: se pulsa de pie y con prisa, así
/// que el objetivo táctil manda sobre la densidad de información.
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// Un evento no configurado se pinta apagado pero sigue siendo pulsable: el
  /// staff debe poder ver que existe y por qué no está listo, en vez de
  /// encontrarse un botón muerto.
  final bool enabled;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 132,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.35)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: enabled
                    ? color.withValues(alpha: 0.12)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                size: 32,
                color: enabled ? color : _Palette.muted,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: enabled ? _Palette.navy : _Palette.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _Palette.muted,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: enabled ? color : const Color(0xFFCBD5E1),
              size: 28,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Marcador para SITEC mientras no se definan sus pantallas.
class _SitecScreen extends StatelessWidget {
  const _SitecScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _Palette.background,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: _Palette.navy,
      title: const Text('SITEC', style: TextStyle(fontWeight: FontWeight.w800)),
    ),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: _Palette.indigo.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  size: 44,
                  color: _Palette.indigo,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Todavía no está configurado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _Palette.navy,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'El flujo de SITEC está pendiente de definir. Mientras tanto, '
                'usa Hackathon para registrar accesos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _Palette.muted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Volver a los eventos'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
