import 'package:flutter/material.dart';

/// Sistema de diseño de la app. Ver DESIGN.md en la raíz del repositorio.
///
/// Centraliza lo que antes estaba repetido en tres paletas privadas. Cualquier
/// color nuevo se añade aquí, no en la pantalla que lo necesite.
class Nothing {
  const Nothing._();

  // Color ---------------------------------------------------------------

  static const bg = Color(0xFFF3F3F1);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111111);
  static const muted = Color(0xFF8A8A86);
  static const border = Color(0xFFCBCBC6);
  static const accent = Color(0xFFE53935);

  /// Semáforos operativos. No son color de marca: comunican estado y por eso
  /// sobreviven a la paleta acotada.
  static const ok = Color(0xFF0F7B6C);
  static const warn = Color(0xFFB45309);
  static const warnBg = Color(0xFFFDF6E3);

  // Ritmo ---------------------------------------------------------------

  /// Márgenes de pantalla. Móvil es el único cliente real.
  static const gutter = 24.0;

  /// Altura mínima de cualquier control pulsable: se opera de pie y con prisa.
  static const tapTarget = 56.0;

  static const mono = 'monospace';

  // Tipografía ----------------------------------------------------------

  /// Etiqueta técnica: `01 / EVENTO`.
  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: muted,
    fontFamily: mono,
  );

  /// Título grande. Apretado a propósito: el aire va alrededor, no dentro.
  static TextStyle display(double size) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w800,
    height: 0.94,
    letterSpacing: -1.2,
    color: ink,
  );

  static const section = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: ink,
  );

  static const body = TextStyle(fontSize: 15, height: 1.45, color: muted);

  /// Metadato. Monoespaciada para que las cifras no bailen al actualizarse.
  static const meta = TextStyle(
    fontSize: 13,
    fontFamily: mono,
    color: ink,
    letterSpacing: 0.2,
  );

  static ThemeData theme() => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ink,
      primary: ink,
      surface: bg,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: ink,
      titleTextStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: ink,
        fontFamily: mono,
      ),
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
  );
}

/// Etiqueta de sección numerada: `01 / REGISTRO`.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.index, this.text, {super.key});

  final String index;
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text('$index / ${text.toUpperCase()}', style: Nothing.label);
}

/// Separador de 1 px. Bordes antes que sombras.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.top = 0, this.bottom = 0});

  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: bottom),
    child: const Divider(height: 1),
  );
}

/// Cifra grande con etiqueta minúscula: los números son identidad, no adorno.
class DisplayNumber extends StatelessWidget {
  const DisplayNumber({
    super.key,
    required this.value,
    required this.caption,
    this.color = Nothing.ink,
    this.size = 52,
  });

  final String value;
  final String caption;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: Nothing.display(size).copyWith(color: color)),
      const SizedBox(height: 4),
      Text(caption.toUpperCase(), style: Nothing.label),
    ],
  );
}

/// Fila de metadato: etiqueta a la izquierda, valor monoespaciado a la derecha.
class MetaRow extends StatelessWidget {
  const MetaRow(this.label, this.value, {super.key, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label.toUpperCase(), style: Nothing.label)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Nothing.meta.copyWith(
              color: valueColor ?? Nothing.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Acción primaria: negro sólido, esquinas mínimas, sin sombra.
class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.color = Nothing.ink,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: Nothing.tapTarget,
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      onPressed: busy ? null : onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else if (icon != null)
            Icon(icon, size: 20),
          if (busy || icon != null) const SizedBox(width: 12),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Acción secundaria: solo borde.
class SecondaryAction extends StatelessWidget {
  const SecondaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: Nothing.tapTarget,
    width: double.infinity,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Nothing.ink,
        side: const BorderSide(color: Nothing.border),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 12),
          ],
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Campo de texto sin caja: solo borde inferior.
class UnderlineField extends StatelessWidget {
  const UnderlineField({
    super.key,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final bool enabled;
  final bool readOnly;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: Nothing.label),
      TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        readOnly: readOnly,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        autocorrect: false,
        style: Nothing.meta.copyWith(fontSize: 15),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: const UnderlineInputBorder(
            borderSide: BorderSide(color: Nothing.border),
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Nothing.border),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Nothing.ink, width: 1.5),
          ),
          suffixIcon: suffix,
        ),
      ),
    ],
  );
}

/// Aviso en línea. Ámbar para duplicado, acento para error.
class Notice extends StatelessWidget {
  const Notice({super.key, required this.message, this.danger = false});

  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Nothing.accent : Nothing.warn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFDF2F2) : Nothing.warnBg,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 14, height: 1.4, color: color),
      ),
    );
  }
}
