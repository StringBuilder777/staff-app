import 'dart:async';

import 'package:flutter/material.dart';

/// Movimiento de la app. Ver DESIGN.md, sección 09.
///
/// Corto y sutil. La app se usa de pie y con prisa: una animación que se note
/// como espera es peor que no tener ninguna.
class Motion {
  const Motion._();

  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 240);

  /// Retardo entre elementos consecutivos de una misma pantalla.
  static const stagger = Duration(milliseconds: 45);

  /// Tope del escalonado.
  ///
  /// Sin tope, una lista de diez elementos dejaría el último entrando a los
  /// 450 ms y la pantalla se sentiría lenta. A partir de aquí todos entran a
  /// la vez, que es lo que nadie nota.
  static const maxSteps = 4;
}

/// Entrada de un bloque: desvanecido con un desplazamiento mínimo.
///
/// `step` escalona la entrada respecto a los hermanos. Se recorta a
/// [Motion.maxSteps] para que la pantalla termine de montarse siempre en el
/// mismo tiempo, tenga dos elementos o veinte.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.step = 0});

  final Widget child;
  final int step;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.base,
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    final steps = widget.step.clamp(0, Motion.maxSteps);
    if (steps == 0) {
      _controller.forward();
    } else {
      _delay = Timer(Motion.stagger * steps, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respeta "quitar animaciones" del sistema. No es una preferencia
    // estética: hay gente a la que el movimiento le provoca mareo.
    if (MediaQuery.of(context).disableAnimations) return widget.child;

    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
            ),
        child: widget.child,
      ),
    );
  }
}

/// Línea que se expande de izquierda a derecha al aparecer.
///
/// Es el gesto que DESIGN.md llama «expansión de línea», y sustituye al
/// separador estático cuando la sección entra por primera vez.
class RevealLine extends StatefulWidget {
  const RevealLine({super.key, this.step = 0, this.color, this.thickness = 1});

  final int step;
  final Color? color;
  final double thickness;

  @override
  State<RevealLine> createState() => _RevealLineState();
}

class _RevealLineState extends State<RevealLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.base,
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    final steps = widget.step.clamp(0, Motion.maxSteps);
    if (steps == 0) {
      _controller.forward();
    } else {
      _delay = Timer(Motion.stagger * steps, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = Container(
      height: widget.thickness,
      color: widget.color ?? Theme.of(context).dividerColor,
    );

    if (MediaQuery.of(context).disableAnimations) return line;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: Curves.easeOutCubic.transform(_controller.value),
        child: child,
      ),
      child: line,
    );
  }
}
