import 'package:flutter/material.dart';

import '../theme/dot_matrix.dart';
import '../theme/motion.dart';
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
    required this.sitec,
    this.actions = const [],
  });

  /// Pantalla del hackathon: registro de equipos y sus accesos.
  final Widget hackathon;

  /// Pantalla de SITEC: accesos por día. Vive en main.dart junto al lector
  /// NFC, igual que la del hackathon.
  final Widget sitec;

  /// Acciones de la barra superior (conexión y cerrar sesión), que viven en
  /// main.dart junto al resto del estado de sesión.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const DotText(
        'STAFF',
        dot: 2.5,
        gap: 1.5,
        motion: DotMotion.reveal,
      ),
      actions: actions,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Nothing.gutter,
          8,
          Nothing.gutter,
          Nothing.gutter,
        ),
        children: [
          Reveal(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(child: SectionLabel('01', 'Eventos')),
                // Textura de rejilla en la cabecera: da densidad sin competir
                // con el texto, que es de lo que se quejaba la pantalla vacía.
                DotField(
                  columns: 7,
                  rows: 4,
                  dot: 2.5,
                  gap: 7,
                  motion: DotMotion.sweep,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Reveal(
            step: 1,
            child: Text('SELECCIONA\nEL EVENTO', style: Nothing.display(44)),
          ),
          const SizedBox(height: 16),
          const Reveal(
            step: 2,
            child: Text(
              'Los accesos que registres se guardan en el evento que elijas.',
              style: Nothing.body,
            ),
          ),
          const SizedBox(height: 36),
          const RevealLine(step: 3),
          Reveal(
            step: 3,
            child: _EventRow(
              index: '01',
              title: 'Hackathon',
              subtitle: 'Registro de equipos, credenciales y accesos',
              glyph: DotGlyphs.qr,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => hackathon)),
            ),
          ),
          const RevealLine(step: 4),
          Reveal(
            step: 4,
            child: _EventRow(
              index: '02',
              title: 'SITEC',
              subtitle: 'Accesos de jueves y viernes',
              glyph: DotGlyphs.nfc,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => sitec)),
            ),
          ),
          const RevealLine(step: 4),
          const SizedBox(height: 36),
          const Reveal(step: 4, child: _Footer()),
        ],
      ),
    ),
  );
}

/// Fila de evento. Sin tarjeta: número grande, glifo de puntos y separador.
///
/// El área pulsable es alta a propósito; se elige de pie y con prisa, así que
/// el objetivo táctil manda sobre la densidad de información.
class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.glyph,
    required this.onTap,
  });

  final String index;
  final String title;
  final String subtitle;
  final List<String> glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 54, child: Text(index, style: Nothing.display(34))),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 18),
            child: AnimatedDotMatrix(
              glyph,
              motion: DotMotion.reveal,
              dot: 3,
              gap: 1.5,
              color: Nothing.accent,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: Nothing.display(24)),
                const SizedBox(height: 8),
                Text(subtitle, style: Nothing.body),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, left: 8),
            child: Text(
              '→',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Nothing.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Cierre de la pantalla: cifra grande en puntos y marca.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      const DotText(
        '02',
        dot: 6,
        gap: 3,
        color: Nothing.ink,
        motion: DotMotion.reveal,
      ),
      const SizedBox(width: 14),
      const Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Text('EVENTOS\nACTIVOS', style: Nothing.label),
      ),
      const Spacer(),
      DotField(columns: 5, rows: 5, dot: 3, gap: 7, color: Nothing.border),
    ],
  );
}
