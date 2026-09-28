import 'package:flutter/material.dart';

import 'nothing.dart';

/// Puntillismo: el lenguaje gráfico de la app. Ver DESIGN.md, sección 06.
///
/// Todo se dibuja con un único primitivo, el punto, sobre una rejilla. Es lo
/// que da carácter sin recurrir a sombras, degradados ni imágenes, y escala a
/// cualquier tamaño sin perder nitidez.
class DotFont {
  const DotFont._();

  /// Fuente 5×7. Cada carácter son siete filas de cinco bits.
  static const Map<String, List<String>> glyphs = {
    '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
    '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
    '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
    '3': ['11111', '00010', '00100', '00010', '00001', '10001', '01110'],
    '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
    '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
    '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
    '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
    '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
    '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
    'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
    'B': ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
    'C': ['01110', '10001', '10000', '10000', '10000', '10001', '01110'],
    'D': ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
    'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
    'F': ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
    'G': ['01110', '10001', '10000', '10111', '10001', '10001', '01111'],
    'H': ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
    'I': ['01110', '00100', '00100', '00100', '00100', '00100', '01110'],
    'J': ['00111', '00010', '00010', '00010', '00010', '10010', '01100'],
    'K': ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
    'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
    'M': ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
    'N': ['10001', '10001', '11001', '10101', '10011', '10001', '10001'],
    'O': ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
    'P': ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
    'Q': ['01110', '10001', '10001', '10001', '10101', '10010', '01101'],
    'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
    'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
    'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
    'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
    'V': ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
    'W': ['10001', '10001', '10001', '10101', '10101', '11011', '10001'],
    'X': ['10001', '10001', '01010', '00100', '01010', '10001', '10001'],
    'Y': ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
    'Z': ['11111', '00001', '00010', '00100', '01000', '10000', '11111'],
    ' ': ['00000', '00000', '00000', '00000', '00000', '00000', '00000'],
    '/': ['00001', '00010', '00010', '00100', '01000', '01000', '10000'],
    '-': ['00000', '00000', '00000', '11111', '00000', '00000', '00000'],
  };
}

/// Glifos grandes de 11×11, para usar como marca o icono de sección.
class DotGlyphs {
  const DotGlyphs._();

  /// Ondas de radio: la marca de las pantallas NFC.
  static const nfc = [
    '00000000000',
    '00001110000',
    '00110001100',
    '01000000010',
    '10001110001',
    '10010001001',
    '10100000101',
    '00100100100',
    '00001110000',
    '00000100000',
    '00000000000',
  ];

  /// Retícula de código: la marca de las pantallas de QR.
  static const qr = [
    '11100010111',
    '10100000101',
    '11100010111',
    '00000000000',
    '00100101001',
    '01001010010',
    '00100001100',
    '00000000000',
    '11100011001',
    '10100001010',
    '11100010110',
  ];

  /// Acceso concedido.
  static const check = [
    '00000000000',
    '00000000010',
    '00000000100',
    '00000001000',
    '00000010000',
    '01000100000',
    '00101000000',
    '00010000000',
    '00000000000',
    '00000000000',
    '00000000000',
  ];

  /// Acceso denegado o duplicado.
  static const cross = [
    '00000000000',
    '01000000010',
    '00100000100',
    '00010001000',
    '00001010000',
    '00000100000',
    '00001010000',
    '00010001000',
    '00100000100',
    '01000000010',
    '00000000000',
  ];

  /// Persona: cabecera de la ficha de participante.
  static const person = [
    '00001110000',
    '00010001000',
    '00010001000',
    '00001110000',
    '00000000000',
    '00011111000',
    '00100000100',
    '01000000010',
    '01000000010',
    '01000000010',
    '01000000010',
  ];
}

/// Pinta una rejilla de puntos a partir de filas de bits.
///
/// El patrón usa '1' para punto encendido; cualquier otro carácter se ignora,
/// lo que permite escribir los mapas con ceros y leerlos de un vistazo.
class DotMatrix extends StatelessWidget {
  const DotMatrix(
    this.pattern, {
    super.key,
    this.dot = 4,
    this.gap = 2,
    this.color = Nothing.ink,
  });

  final List<String> pattern;
  final double dot;
  final double gap;
  final Color color;

  double get _step => dot + gap;

  @override
  Widget build(BuildContext context) {
    final cols = pattern.isEmpty ? 0 : pattern.first.length;
    return SizedBox(
      width: cols * _step - gap,
      height: pattern.length * _step - gap,
      child: CustomPaint(
        painter: _DotPainter(
          pattern: pattern,
          dot: dot,
          step: _step,
          color: color,
        ),
      ),
    );
  }
}

/// Texto renderizado en matriz de puntos con la fuente 5×7.
///
/// Solo admite mayúsculas, dígitos y unos pocos signos: los caracteres que no
/// estén en la fuente se omiten en vez de romper el trazado.
class DotText extends StatelessWidget {
  const DotText(
    this.text, {
    super.key,
    this.dot = 4,
    this.gap = 2,
    this.color = Nothing.ink,
    this.letterGap = 1,
  });

  final String text;
  final double dot;
  final double gap;
  final Color color;

  /// Separación entre caracteres, en columnas de la rejilla.
  final int letterGap;

  List<String> get _rows {
    final chars = text
        .toUpperCase()
        .split('')
        .where(DotFont.glyphs.containsKey)
        .toList();
    if (chars.isEmpty) return const [];

    final spacer = '0' * letterGap;
    return List.generate(
      7,
      (row) => chars.map((c) => DotFont.glyphs[c]![row]).join(spacer),
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: text,
    child: DotMatrix(_rows, dot: dot, gap: gap, color: color),
  );
}

/// Campo decorativo de puntos apagados.
///
/// Da textura de fondo sin competir con el contenido. Se usa detrás de bloques
/// grandes, nunca bajo texto pequeño.
class DotField extends StatelessWidget {
  const DotField({
    super.key,
    this.columns = 12,
    this.rows = 6,
    this.dot = 3,
    this.gap = 9,
    this.color = Nothing.border,
  });

  final int columns;
  final int rows;
  final double dot;
  final double gap;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DotMatrix(
      List.filled(rows, '1' * columns),
      dot: dot,
      gap: gap,
      color: color,
    ),
  );
}

class _DotPainter extends CustomPainter {
  const _DotPainter({
    required this.pattern,
    required this.dot,
    required this.step,
    required this.color,
  });

  final List<String> pattern;
  final double dot;
  final double step;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final radius = dot / 2;

    for (var y = 0; y < pattern.length; y++) {
      final row = pattern[y];
      for (var x = 0; x < row.length; x++) {
        if (row[x] != '1') continue;
        canvas.drawCircle(
          Offset(x * step + radius, y * step + radius),
          radius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.color != color ||
      old.dot != dot ||
      old.step != step ||
      !identical(old.pattern, pattern);
}
