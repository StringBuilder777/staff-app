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

  /// Check-in: flecha entrando por una puerta.
  static const checkin = [
    '00000000000',
    '00000001110',
    '00000001000',
    '00100001000',
    '00010001000',
    '11111111000',
    '00010001000',
    '00100001000',
    '00000001000',
    '00000001110',
    '00000000000',
  ];

  /// Desayuno: taza humeante.
  static const breakfast = [
    '00100010000',
    '01000100000',
    '00100010000',
    '00000000000',
    '11111111000',
    '10000001000',
    '10000001111',
    '10000001001',
    '10000001111',
    '01111110000',
    '00000000000',
  ];

  /// Comida: pata de pollo. La masa arriba, el hueso con su nudo abajo.
  static const lunch = [
    '00011110000',
    '00111111000',
    '01111111100',
    '01111111100',
    '01111111000',
    '00111110000',
    '00011100000',
    '00011100000',
    '00111110000',
    '00111110000',
    '00011100000',
  ];

  /// Microchip: identidad del hackathon.
  static const chip = [
    '00100010100',
    '00100010100',
    '01111111110',
    '01000000010',
    '11000000011',
    '01000000010',
    '11000000011',
    '01000000010',
    '01111111110',
    '00100010100',
    '00100010100',
  ];

  /// Terminal con cursor.
  static const terminal = [
    '11111111111',
    '10000000001',
    '10000000001',
    '10110000001',
    '10011000001',
    '10110000001',
    '10000000001',
    '10001111001',
    '10000000001',
    '10000000001',
    '11111111111',
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
    this.motion,
  });

  final String text;
  final double dot;
  final double gap;
  final Color color;
  final DotMotion? motion;

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
    child: motion == null
        ? DotMatrix(_rows, dot: dot, gap: gap, color: color)
        : AnimatedDotMatrix(
            _rows,
            motion: motion!,
            dot: dot,
            gap: gap,
            color: color,
          ),
  );
}

/// Esfera de puntos.
///
/// El círculo grande es el elemento gráfico de más peso del lenguaje Nothing.
/// Aquí se construye con la misma rejilla que el resto, así que no desentona
/// con los glifos ni necesita imágenes.
class DotCircle extends StatelessWidget {
  const DotCircle({
    super.key,
    this.cells = 13,
    this.dot = 5,
    this.gap = 3,
    this.color = Nothing.ink,
    this.motion,
    this.hollow = false,
  });

  /// Lado de la rejilla, en puntos. Impar da un centro nítido.
  final int cells;
  final double dot;
  final double gap;
  final Color color;
  final DotMotion? motion;

  /// Solo el contorno, para usarla como marco en lugar de como masa.
  final bool hollow;

  List<String> get _pattern {
    final radius = cells / 2;
    final inner = radius - 1.6;

    return List.generate(cells, (y) {
      final row = StringBuffer();
      for (var x = 0; x < cells; x++) {
        final dx = x - radius + 0.5;
        final dy = y - radius + 0.5;
        final distance = dx * dx + dy * dy;
        final inside = distance <= radius * radius;
        final lit = hollow ? inside && distance > inner * inner : inside;
        row.write(lit ? '1' : '0');
      }
      return row.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pattern = _pattern;
    return ExcludeSemantics(
      child: motion == null
          ? DotMatrix(pattern, dot: dot, gap: gap, color: color)
          : AnimatedDotMatrix(
              pattern,
              motion: motion!,
              dot: dot,
              gap: gap,
              color: color,
            ),
    );
  }
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
    this.motion,
  });

  final int columns;
  final int rows;
  final double dot;
  final double gap;
  final Color color;
  final DotMotion? motion;

  @override
  Widget build(BuildContext context) {
    final pattern = List.filled(rows, '1' * columns);
    return ExcludeSemantics(
      child: motion == null
          ? DotMatrix(pattern, dot: dot, gap: gap, color: color)
          : AnimatedDotMatrix(
              pattern,
              motion: motion!,
              dot: dot,
              gap: gap,
              color: color,
            ),
    );
  }
}

/// Cómo se mueven los puntos.
enum DotMotion {
  /// Se encienden en diagonal, una sola vez. Para entradas.
  reveal,

  /// Banda de brillo que recorre la rejilla en bucle. Reservado a estados de
  /// espera: comunica «esto sigue vivo» sin ocupar sitio ni texto.
  sweep,

  /// Respiración suave del conjunto. Para marcas y decoración.
  pulse,
}

/// Matriz de puntos animada.
///
/// El bucle solo debe usarse donde signifique algo —esperando una tarjeta, por
/// ejemplo—: animar en bucle por decorar gasta batería y distrae a quien está
/// intentando leer la pantalla.
class AnimatedDotMatrix extends StatefulWidget {
  const AnimatedDotMatrix(
    this.pattern, {
    super.key,
    this.motion = DotMotion.reveal,
    this.dot = 4,
    this.gap = 2,
    this.color = Nothing.ink,
  });

  final List<String> pattern;
  final DotMotion motion;
  final double dot;
  final double gap;
  final Color color;

  @override
  State<AnimatedDotMatrix> createState() => _AnimatedDotMatrixState();
}

class _AnimatedDotMatrixState extends State<AnimatedDotMatrix>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: switch (widget.motion) {
        DotMotion.reveal => const Duration(milliseconds: 420),
        DotMotion.sweep => const Duration(milliseconds: 1700),
        DotMotion.pulse => const Duration(milliseconds: 1600),
      },
    );

    switch (widget.motion) {
      case DotMotion.reveal:
        _controller.forward();
      case DotMotion.sweep:
        _controller.repeat();
      case DotMotion.pulse:
        _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cols = widget.pattern.isEmpty ? 0 : widget.pattern.first.length;
    final stepSize = widget.dot + widget.gap;

    // Con las animaciones desactivadas en el sistema, matriz quieta y opaca.
    if (MediaQuery.of(context).disableAnimations) {
      return DotMatrix(
        widget.pattern,
        dot: widget.dot,
        gap: widget.gap,
        color: widget.color,
      );
    }

    return SizedBox(
      width: cols * stepSize - widget.gap,
      height: widget.pattern.length * stepSize - widget.gap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _DotPainter(
            pattern: widget.pattern,
            dot: widget.dot,
            step: stepSize,
            color: widget.color,
            motion: widget.motion,
            progress: _controller.value,
          ),
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter({
    required this.pattern,
    required this.dot,
    required this.step,
    required this.color,
    this.motion,
    this.progress = 1,
  });

  final List<String> pattern;
  final double dot;
  final double step;
  final Color color;
  final DotMotion? motion;
  final double progress;

  /// Opacidad de un punto concreto según el movimiento activo.
  double _alpha(int x, int y, int cols, int rows) {
    switch (motion) {
      case null:
        return 1;
      case DotMotion.reveal:
        // Barrido diagonal: el borde es suave para que no parezca un corte.
        final position = (x + y) / (cols + rows);
        return ((progress - position) * 4).clamp(0.0, 1.0);
      case DotMotion.sweep:
        // La banda entra y sale por fuera de la rejilla, así que no hay
        // saltos al reiniciar el bucle.
        final band = progress * (cols + 8) - 4;
        final distance = (x - band).abs();
        return (0.35 + 0.65 * (1 - distance / 3).clamp(0.0, 1.0)).clamp(
          0.0,
          1.0,
        );
      case DotMotion.pulse:
        return 0.45 + 0.55 * progress;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final radius = dot / 2;
    final rows = pattern.length;
    final cols = pattern.isEmpty ? 0 : pattern.first.length;
    final paint = Paint();

    for (var y = 0; y < rows; y++) {
      final row = pattern[y];
      for (var x = 0; x < row.length; x++) {
        if (row[x] != '1') continue;
        final alpha = _alpha(x, y, cols, rows);
        if (alpha <= 0) continue;
        paint.color = color.withValues(alpha: color.a * alpha);
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
      old.motion != motion ||
      old.progress != progress ||
      !identical(old.pattern, pattern);
}
