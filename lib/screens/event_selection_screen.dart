import 'package:flutter/material.dart';

import '../theme/nothing.dart';

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

  /// Acciones de la barra superior (conexión y cerrar sesión), que viven en
  /// main.dart junto al resto del estado de sesión.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('STAFF'), actions: actions),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Nothing.gutter,
          8,
          Nothing.gutter,
          Nothing.gutter,
        ),
        children: [
          const SectionLabel('01', 'Eventos'),
          const SizedBox(height: 20),
          Text('SELECCIONA\nEL EVENTO', style: Nothing.display(44)),
          const SizedBox(height: 16),
          const Text(
            'Los accesos que registres se guardan en el evento que elijas.',
            style: Nothing.body,
          ),
          const SizedBox(height: 40),
          const Hairline(),
          _EventRow(
            index: '01',
            title: 'Hackathon',
            subtitle: 'Registro de equipos, credenciales y accesos',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => hackathon)),
          ),
          const Hairline(),
          _EventRow(
            index: '02',
            title: 'SITEC',
            subtitle: 'Pendiente de configurar',
            enabled: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _SitecScreen()),
            ),
          ),
          const Hairline(),
        ],
      ),
    ),
  );
}

/// Fila de evento. Sin tarjeta: número grande, título y separador de 1 px.
///
/// El área pulsable es alta a propósito; se elige de pie y con prisa, así que
/// el objetivo táctil manda sobre la densidad de información.
class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final String index;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Un evento no configurado se pinta apagado pero sigue siendo pulsable: el
  /// staff debe ver que existe y por qué no está listo, no un botón muerto.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ink = enabled ? Nothing.ink : Nothing.muted;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Text(
                index,
                style: Nothing.display(
                  40,
                ).copyWith(color: enabled ? Nothing.accent : Nothing.border),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: Nothing.display(26).copyWith(color: ink),
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, style: Nothing.body),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '→',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Nothing.ink : Nothing.border,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marcador para SITEC mientras no se definan sus pantallas.
class _SitecScreen extends StatelessWidget {
  const _SitecScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SITEC')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Nothing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('02', 'SITEC'),
            const SizedBox(height: 20),
            Text('TODAVÍA\nNO ESTÁ\nLISTO', style: Nothing.display(40)),
            const SizedBox(height: 20),
            const Text(
              'El flujo de SITEC está pendiente de definir. Mientras tanto, '
              'usa Hackathon para registrar accesos.',
              style: Nothing.body,
            ),
            const Spacer(),
            SecondaryAction(
              label: 'Volver a los eventos',
              icon: Icons.arrow_back_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
