import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Shared building blocks for the "종이 수첩" art direction.
///
/// Every screen composes from these so the paper stock, dashed rules, hard
/// offset shadows, and stamp motif stay identical across tabs.

// ─────────────────────────────────────────────────────────────── surfaces ──

/// A sheet of card stock resting on the page: hairline outline, 3px corners,
/// and a 1px hard shadow.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    this.child,
    this.padding = const EdgeInsets.all(MasilPetSpacing.lg),
    this.color = MasilPetPalette.paper,
    this.border = MasilPetBorders.hairlineBox,
    this.shadows = MasilPetShadows.card,
    this.radius = MasilPetRadii.cardBorder,
    this.clipContent = false,
    this.width,
    this.height,
    this.alignment,
  });

  /// A card that carries weight: 1.5px ink outline and a `5px 5px` shadow.
  const PaperCard.stamped({
    super.key,
    this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = MasilPetPalette.paper,
    this.radius = MasilPetRadii.cardBorder,
    this.clipContent = false,
    this.width,
    this.height,
    this.alignment,
  })  : border = MasilPetBorders.inkBox,
        shadows = MasilPetShadows.stamped;

  /// A framed area with no shadow — used for the map and the yard.
  const PaperCard.frame({
    super.key,
    this.child,
    this.padding = EdgeInsets.zero,
    this.color = MasilPetPalette.paper,
    this.radius = MasilPetRadii.cardBorder,
    this.width,
    this.height,
    this.alignment,
  })  : border = MasilPetBorders.controlBox,
        shadows = const <BoxShadow>[],
        clipContent = true;

  final Widget? child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final BoxBorder? border;
  final List<BoxShadow> shadows;
  final BorderRadius radius;
  final bool clipContent;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      clipBehavior: clipContent ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: color,
        border: border,
        borderRadius: radius,
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}

/// What a pet says: ink-outlined paper with a `3px 3px` shadow.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.text,
    this.style,
    this.maxWidth,
    this.textAlign = TextAlign.center,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.color = MasilPetPalette.paper,
    this.shadows = MasilPetShadows.bubble,
  });

  final String text;
  final TextStyle? style;
  final double? maxWidth;
  final TextAlign textAlign;
  final EdgeInsetsGeometry padding;
  final Color color;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    Widget bubble = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: MasilPetBorders.inkBox,
        borderRadius: MasilPetRadii.bubbleBorder,
        boxShadow: shadows,
      ),
      child: Text(
        text,
        textAlign: textAlign,
        style: style ?? MasilPetType.bubble,
      ),
    );
    if (maxWidth != null) {
      bubble = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: bubble,
      );
    }
    return bubble;
  }
}

/// A callout drawn with a dashed rule instead of a solid outline.
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.color = MasilPetPalette.outline,
    this.fill = MasilPetPalette.paper,
    this.radius = MasilPetRadii.card,
    this.strokeWidth = 1,
    this.dash = 4,
    this.gap = 3,
  });

  final Widget? child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? fill;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        fill: fill,
        radius: radius,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A dashed horizontal rule — the system's only divider.
class DashedRule extends StatelessWidget {
  const DashedRule({
    super.key,
    this.color = MasilPetPalette.outlineSoft,
    this.dash = 4,
    this.gap = 3,
    this.thickness = 1,
  });

  final Color color;
  final double dash;
  final double gap;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thickness,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: color,
          dash: dash,
          gap: gap,
          thickness: thickness,
        ),
      ),
    );
  }
}

/// A vertical dashed rule — the spine of the timeline and step lists.
class DashedSpine extends StatelessWidget {
  const DashedSpine({
    super.key,
    this.color = MasilPetPalette.outline,
    this.dash = 4,
    this.gap = 3,
    this.thickness = 1,
  });

  final Color color;
  final double dash;
  final double gap;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: thickness,
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: color,
          dash: dash,
          gap: gap,
          thickness: thickness,
          vertical: true,
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.fill,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final Color? fill;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    if (fill != null) {
      canvas.drawRRect(rrect, Paint()..color = fill!);
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      _dashPath(Path()..addRRect(rrect), dash, gap),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) {
    return old.color != color ||
        old.fill != fill ||
        old.radius != radius ||
        old.strokeWidth != strokeWidth ||
        old.dash != dash ||
        old.gap != gap;
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({
    required this.color,
    required this.dash,
    required this.gap,
    required this.thickness,
    this.vertical = false,
  });

  final Color color;
  final double dash;
  final double gap;
  final double thickness;
  final bool vertical;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness;
    final extent = vertical ? size.height : size.width;
    final center = vertical ? size.width / 2 : size.height / 2;
    var position = 0.0;
    while (position < extent) {
      final end = math.min(position + dash, extent);
      canvas.drawLine(
        vertical ? Offset(center, position) : Offset(position, center),
        vertical ? Offset(center, end) : Offset(end, center),
        paint,
      );
      position = end + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) {
    return old.color != color ||
        old.dash != dash ||
        old.gap != gap ||
        old.thickness != thickness ||
        old.vertical != vertical;
  }
}

Path _dashPath(Path source, double dash, double gap) {
  final result = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = math.min(distance + dash, metric.length);
      result.addPath(metric.extractPath(distance, end), Offset.zero);
      distance = end + gap;
    }
  }
  return result;
}

// ────────────────────────────────────────────────────────────────── text ──

/// A note scribbled in the margin.
class HandNote extends StatelessWidget {
  const HandNote(
    this.text, {
    super.key,
    this.style,
    this.color,
    this.fontSize,
    this.textAlign,
    this.maxLines,
  });

  final String text;
  final TextStyle? style;
  final Color? color;
  final double? fontSize;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: (style ?? MasilPetType.hand).copyWith(
        color: color,
        fontSize: fontSize,
      ),
    );
  }
}

/// A stamp-red monospaced eyebrow above a title.
class Eyebrow extends StatelessWidget {
  const Eyebrow(
    this.text, {
    super.key,
    this.color = MasilPetPalette.stamp,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: MasilPetType.eyebrow.copyWith(color: color));
  }
}

/// The section label used above lists — handwritten, never bold.
class SectionEyebrow extends StatelessWidget {
  const SectionEyebrow(
    this.text, {
    super.key,
    this.trailing,
  });

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (trailing == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: MasilPetSpacing.sm),
        child: HandNote(text),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: MasilPetSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: HandNote(text)),
          trailing!,
        ],
      ),
    );
  }
}

/// A serif section heading with an optional trailing control.
class SectionTitleRow extends StatelessWidget {
  const SectionTitleRow({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: MasilPetType.sectionTitle)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A monospaced reward tag: `EXP +18`, `알 +3걸음`.
class MonoChip extends StatelessWidget {
  const MonoChip(
    this.label, {
    super.key,
    this.color = MasilPetPalette.inkSoft,
    this.background = MasilPetPalette.subtle,
    this.border = MasilPetPalette.outlineSoft,
  });

  final String label;
  final Color color;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: MasilPetRadii.tightBorder,
      ),
      child: Text(
        label,
        style: MasilPetType.metaMono.copyWith(
          letterSpacing: 0.66,
          color: color,
        ),
      ),
    );
  }
}

/// A rotated rarity tag, as if inked by hand at a slight angle.
class RarityStamp extends StatelessWidget {
  const RarityStamp(
    this.label, {
    super.key,
    this.angleDegrees = -4,
    this.color = MasilPetPalette.stamp,
    this.border = MasilPetPalette.stampPale,
  });

  final String label;
  final double angleDegrees;
  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angleDegrees * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: MasilPetRadii.tightBorder,
        ),
        child: Text(
          label,
          style: MasilPetType.metaMono.copyWith(color: color),
        ),
      ),
    );
  }
}

/// A ✓ line inside a dashed callout.
class CheckLine extends StatelessWidget {
  const CheckLine(
    this.text, {
    super.key,
    this.color = MasilPetPalette.forest,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '✓',
          style: MasilPetType.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            height: 1.55,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: MasilPetType.bodySmall.copyWith(
              fontSize: 13.5,
              height: 1.55,
              color: MasilPetPalette.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────── buttons ──

enum PaperButtonTone { ink, stamp, ghost }

/// The primary control: flat paper with a hard bottom lip that compresses on
/// press, like a rubber stamp meeting the page.
class PaperButton extends StatefulWidget {
  const PaperButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = PaperButtonTone.ink,
    this.expand = true,
    this.fontSize = 17,
    this.padding = const EdgeInsets.symmetric(
      horizontal: MasilPetSpacing.xl,
      vertical: 16,
    ),
    this.maxWidth,
  });

  const PaperButton.stamp({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
    this.fontSize = 18,
    this.padding = const EdgeInsets.symmetric(
      horizontal: MasilPetSpacing.xl,
      vertical: 16,
    ),
    this.maxWidth,
  }) : tone = PaperButtonTone.stamp;

  const PaperButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
    this.fontSize = 16,
    this.padding = const EdgeInsets.symmetric(
      horizontal: MasilPetSpacing.lg,
      vertical: 14,
    ),
    this.maxWidth,
  }) : tone = PaperButtonTone.ghost;

  final String label;
  final VoidCallback? onPressed;
  final PaperButtonTone tone;
  final bool expand;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double? maxWidth;

  @override
  State<PaperButton> createState() => _PaperButtonState();
}

class _PaperButtonState extends State<PaperButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final tone = widget.tone;

    final Color background;
    final Color foreground;
    final List<BoxShadow> lip;
    final BoxBorder? border;

    switch (tone) {
      case PaperButtonTone.ink:
        background = enabled ? MasilPetPalette.ink : MasilPetPalette.outline;
        foreground = MasilPetPalette.sheet;
        lip = enabled ? MasilPetShadows.inkButton : const <BoxShadow>[];
        border = null;
      case PaperButtonTone.stamp:
        background = enabled ? MasilPetPalette.stamp : MasilPetPalette.outline;
        foreground = MasilPetPalette.paper;
        lip = enabled ? MasilPetShadows.stampButton : const <BoxShadow>[];
        border = null;
      case PaperButtonTone.ghost:
        background = Colors.transparent;
        foreground = enabled ? MasilPetPalette.ink : MasilPetPalette.disabled;
        lip = const <BoxShadow>[];
        border = Border.all(
          color: enabled ? MasilPetPalette.ink : MasilPetPalette.outline,
          width: 1,
        );
    }

    final pressed = _down && enabled && lip.isNotEmpty;

    Widget button = AnimatedContainer(
      duration: MasilPetMotion.press,
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, pressed ? 3 : 0, 0),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: background,
        border: border,
        borderRadius: MasilPetRadii.smallBorder,
        boxShadow: pressed ? const <BoxShadow>[] : lip,
      ),
      child: Text(
        widget.label,
        textAlign: TextAlign.center,
        style: MasilPetType.button.copyWith(
          fontSize: widget.fontSize,
          color: foreground,
        ),
      ),
    );

    if (widget.maxWidth != null) {
      button = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth!),
        child: button,
      );
    }

    final tappable = Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: button,
        ),
      ),
    );

    if (!widget.expand) {
      return IntrinsicWidth(child: tappable);
    }
    return SizedBox(width: double.infinity, child: tappable);
  }
}

/// A small outlined control with a monospaced label: `위치 새로고침`.
class MonoButton extends StatelessWidget {
  const MonoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = MasilPetPalette.muted,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: onPressed,
        borderRadius: MasilPetRadii.tightBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: MasilPetPalette.paper,
            border: Border.all(color: MasilPetPalette.outline),
            borderRadius: MasilPetRadii.tightBorder,
          ),
          child: Text(
            label,
            style: MasilPetType.microMono.copyWith(
              fontSize: 10,
              letterSpacing: 1,
              color: enabled ? color : MasilPetPalette.disabled,
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact serif action used inside list rows: `도장`.
class InkTag extends StatelessWidget {
  const InkTag({
    super.key,
    required this.label,
    this.onPressed,
    this.background = MasilPetPalette.ink,
    this.foreground = MasilPetPalette.sheet,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onPressed != null,
      child: InkWell(
        onTap: onPressed,
        borderRadius: MasilPetRadii.tightBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: MasilPetRadii.tightBorder,
          ),
          child: Text(
            label,
            style: MasilPetType.rowTitle.copyWith(
              fontSize: 13,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// An outlined status tag: `완료`.
class OutlineTag extends StatelessWidget {
  const OutlineTag({
    super.key,
    required this.label,
    this.color = MasilPetPalette.forest,
    this.border = MasilPetPalette.forestPale,
  });

  final String label;
  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: MasilPetRadii.tightBorder,
      ),
      child: Text(
        label,
        style: MasilPetType.microMono.copyWith(
          fontSize: 10,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of pill filters.
class FilterPillRow<T> extends StatefulWidget {
  const FilterPillRow({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  State<FilterPillRow<T>> createState() => _FilterPillRowState<T>();
}

class _FilterPillRowState<T> extends State<FilterPillRow<T>> {
  static const _fadeWidth = 26.0;

  final _controller = ScrollController();
  bool _showLeadingFade = false;
  bool _showTrailingFade = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateFadeVisibility);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateFadeVisibility());
  }

  @override
  void dispose() {
    _controller.removeListener(_updateFadeVisibility);
    _controller.dispose();
    super.dispose();
  }

  void _updateFadeVisibility() {
    if (!_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    final showLeading = position.pixels > 4;
    final showTrailing = position.pixels < position.maxScrollExtent - 4;
    if (showLeading == _showLeadingFade && showTrailing == _showTrailingFade) {
      return;
    }
    setState(() {
      _showLeadingFade = showLeading;
      _showTrailingFade = showTrailing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: widget.padding,
          child: Row(
            children: [
              for (final value in values) ...[
                FilterPill(
                  label: widget.labelOf(value),
                  selected: value == widget.selected,
                  onTap: () => widget.onSelected(value),
                ),
                if (value != values.last) const SizedBox(width: 7),
              ],
            ],
          ),
        ),
        if (_showLeadingFade)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _fadeWidth,
            child: const EdgeFade(alignEnd: false),
          ),
        if (_showTrailingFade)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _fadeWidth,
            child: const EdgeFade(alignEnd: true),
          ),
      ],
    );
  }
}

/// A ruled line of the notebook you can write on, used to narrow a long list.
///
/// The parent owns [value] so a "reset filters" action elsewhere on the page
/// can clear the line too.
class PaperSearchField extends StatefulWidget {
  const PaperSearchField({
    super.key,
    required this.label,
    required this.hintText,
    required this.value,
    required this.onChanged,
  });

  /// The monospaced tag written in the left margin, e.g. `찾기`.
  final String label;
  final String hintText;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<PaperSearchField> createState() => _PaperSearchFieldState();
}

class _PaperSearchFieldState extends State<PaperSearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant PaperSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only follow the parent when it actually diverged, so typing never has
    // its cursor yanked back.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.value.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
      decoration: BoxDecoration(
        color: MasilPetPalette.paper,
        border: Border.all(color: MasilPetPalette.outlineSoft),
        borderRadius: MasilPetRadii.smallBorder,
      ),
      child: Row(
        children: [
          Text(
            widget.label,
            style: MasilPetType.microMono.copyWith(
              fontSize: 10,
              letterSpacing: 1.1,
              color: MasilPetPalette.stamp,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: MasilPetPalette.stamp,
              cursorWidth: 1.5,
              style: MasilPetType.bodySmall.copyWith(
                fontSize: 14,
                height: 1.3,
                color: MasilPetPalette.ink,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: widget.hintText,
                hintStyle: MasilPetType.bodySmall.copyWith(
                  fontSize: 14,
                  height: 1.3,
                  color: MasilPetPalette.disabled,
                ),
              ),
            ),
          ),
          if (hasText)
            Semantics(
              button: true,
              label: '검색어 지우기',
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () => widget.onChanged(''),
                  borderRadius: MasilPetRadii.tightBorder,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 10,
                    ),
                    child: Text(
                      '지우기',
                      style: MasilPetType.caption.copyWith(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A soft fade to the page background, hinting that a horizontal list has
/// more content just off-screen.
class EdgeFade extends StatelessWidget {
  const EdgeFade({required this.alignEnd, super.key});

  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: alignEnd ? Alignment.centerLeft : Alignment.centerRight,
            end: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              MasilPetPalette.canvas.withValues(alpha: 0),
              MasilPetPalette.canvas,
            ],
          ),
        ),
      ),
    );
  }
}

class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: MasilPetRadii.pillBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? MasilPetPalette.ink : MasilPetPalette.paper,
            border: Border.all(
              color:
                  selected ? MasilPetPalette.ink : MasilPetPalette.outlineSoft,
            ),
            borderRadius: MasilPetRadii.pillBorder,
          ),
          child: Text(
            label,
            style: MasilPetType.bodySmall.copyWith(
              fontSize: 13,
              height: 1.2,
              color: selected ? MasilPetPalette.sheet : MasilPetPalette.muted,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── metrics ──

/// A care stat: label, monospaced value, and a bordered 9px track.
class PaperStatBar extends StatelessWidget {
  const PaperStatBar({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.ratio,
    required this.color,
  });

  final String label;
  final String valueLabel;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = ratio.clamp(0.0, 1.0);
    return Semantics(
      label: '$label $valueLabel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: MasilPetType.bodySmall.copyWith(
                    fontSize: 13.5,
                    height: 1.2,
                    color: MasilPetPalette.inkSoft,
                  ),
                ),
              ),
              Text(valueLabel, style: MasilPetType.metaMono),
            ],
          ),
          const SizedBox(height: 6),
          PaperTrack(ratio: clamped, color: color),
        ],
      ),
    );
  }
}

/// The bordered progress track used by stat bars and the dex meter.
class PaperTrack extends StatelessWidget {
  const PaperTrack({
    super.key,
    required this.ratio,
    required this.color,
    this.height = 9,
  });

  final double ratio;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: MasilPetPalette.track,
        border: Border.all(color: MasilPetPalette.outlineStrong),
        borderRadius: MasilPetRadii.pillBorder,
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: ratio.clamp(0.0, 1.0),
          child: AnimatedContainer(
            duration: MasilPetMotion.rise,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: color,
              borderRadius: MasilPetRadii.pillBorder,
            ),
          ),
        ),
      ),
    );
  }
}

/// A boxed total: big serif number over a small label.
class PaperTotal extends StatelessWidget {
  const PaperTotal({
    super.key,
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: MasilPetType.rowTitle.copyWith(
              fontSize: 23,
              letterSpacing: -0.46,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: MasilPetType.caption.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────  stamp ──

/// The circular double-ring stamp: `VISITED / 인증 / 07.29`.
class RoundStamp extends StatelessWidget {
  const RoundStamp({
    super.key,
    required this.top,
    required this.middle,
    this.bottom,
    this.size = 78,
    this.color = MasilPetPalette.stamp,
    this.angleDegrees = -9,
    this.middleFontSize = 13,
  });

  final String top;
  final String middle;
  final String? bottom;
  final double size;
  final Color color;
  final double angleDegrees;
  final double middleFontSize;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angleDegrees * math.pi / 180,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
            // A rubber stamp is a fixed object: its ink follows the reader's
            // text size up to the edge of the die, then stops rather than
            // spilling over the ring.
            child: Padding(
              padding: EdgeInsets.all(size * 0.12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      top,
                      style: MasilPetType.microMono.copyWith(
                        fontSize: 8,
                        letterSpacing: 0.8,
                        color: color,
                      ),
                    ),
                    Text(
                      middle,
                      style: MasilPetType.rowTitle.copyWith(
                        fontSize: middleFontSize,
                        height: 1.1,
                        color: color,
                      ),
                    ),
                    if (bottom != null)
                      Text(
                        bottom!,
                        style: MasilPetType.microMono.copyWith(
                          fontSize: 7.5,
                          letterSpacing: 0,
                          color: color,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Touch feedback for the beats that are meant to feel physical: rubber
/// meeting paper, a shell cracking, a hand on a pet.
///
/// Every call is a no-op on platforms without a vibrator (web, desktop), so
/// callers never have to branch on the platform.
abstract final class MasilPetHaptics {
  /// A stamp landing or an egg opening — the loop's two loud moments.
  static void stamp() {
    unawaited(HapticFeedback.mediumImpact());
  }

  /// A hand on the pet, or a care action taking hold.
  static void touch() {
    unawaited(HapticFeedback.lightImpact());
  }

  /// Turning to another page of the notebook.
  static void select() {
    unawaited(HapticFeedback.selectionClick());
  }
}

/// Where a hand-pressed stamp comes to rest: never quite square to the page.
const _stampRestAngle = -9 * math.pi / 180;

/// The full-screen stamp that lands when a visit is verified.
class StampOverlay extends StatefulWidget {
  const StampOverlay({
    super.key,
    required this.dateLabel,
    this.title = '방문 인증',
    this.brand = 'MASILPET',
  });

  final String dateLabel;
  final String title;
  final String brand;

  @override
  State<StampOverlay> createState() => _StampOverlayState();
}

class _StampOverlayState extends State<StampOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: MasilPetMotion.stamp,
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = CurvedAnimation(
      parent: _controller,
      curve: MasilPetMotion.stampCurve,
    );
    final muted = _motionMuted(context);

    return IgnorePointer(
      child: ColoredBox(
        color: MasilPetPalette.ink.withValues(alpha: 0.42),
        child: Center(
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, child) {
              final t = progress.value;
              final opacity = t.clamp(0.0, 1.0);
              // Reduced motion keeps the stamp — it is the reward — but lands
              // it by fading, without the swing down from 1.9×.
              if (muted) {
                return Opacity(
                  opacity: opacity,
                  child: Transform.rotate(angle: _stampRestAngle, child: child),
                );
              }
              final scale = ui.lerpDouble(1.9, 1.0, t)!;
              final angle = ui.lerpDouble(-26, -9, t)! * math.pi / 180;
              return Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: angle,
                  child: Transform.scale(scale: scale, child: child),
                ),
              );
            },
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MasilPetPalette.paper.withValues(alpha: 0.14),
                border: Border.all(color: MasilPetPalette.stamp, width: 5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MasilPetPalette.stamp,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.brand,
                        style: MasilPetType.metaMono.copyWith(
                          letterSpacing: 3.08,
                          color: MasilPetPalette.stamp,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.title,
                        style: MasilPetType.heroTitle.copyWith(
                          fontSize: 30,
                          color: MasilPetPalette.stamp,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.dateLabel,
                        style: MasilPetType.metaMono.copyWith(
                          letterSpacing: 1.98,
                          color: MasilPetPalette.stamp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Drops the verification stamp over the whole app for one beat.
void showStampOverlay(
  BuildContext context, {
  required String dateLabel,
  String title = '방문 인증',
  Duration hold = const Duration(milliseconds: 1400),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }
  MasilPetHaptics.stamp();
  final entry = OverlayEntry(
    builder: (context) => StampOverlay(dateLabel: dateLabel, title: title),
  );
  overlay.insert(entry);
  Timer(hold, () {
    // remove() only needs the entry to still belong to an overlay, which holds
    // even if the stamp never got a frame to build in.
    entry.remove();
    entry.dispose();
  });
}

/// A passport day cell — inked circle when stamped, dashed when empty.
class PassportDay extends StatelessWidget {
  const PassportDay({
    super.key,
    required this.day,
    required this.stamped,
    this.angleDegrees = 0,
  });

  final int day;
  final bool stamped;
  final double angleDegrees;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      '$day',
      style: MasilPetType.microMono.copyWith(
        fontSize: 10,
        letterSpacing: 0,
        color: stamped ? MasilPetPalette.stamp : MasilPetPalette.outlineFaint,
      ),
    );

    if (!stamped) {
      return AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: const _DashedCirclePainter(
            color: MasilPetPalette.outlineSoft,
          ),
          child: Center(child: label),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1,
      child: Transform.rotate(
        angle: angleDegrees * math.pi / 180,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: MasilPetPalette.stamp, width: 1.5),
          ),
          child: label,
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addOval(
        Rect.fromCircle(
          center: size.center(Offset.zero),
          radius: math.min(size.width, size.height) / 2 - 0.5,
        ),
      );
    canvas.drawPath(
      _dashPath(path, 3, 3),
      Paint()
        ..color = color
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}

// ───────────────────────────────────────────────────────────────  sprites ──

/// A pixel-art sprite drawn without smoothing (`image-rendering: pixelated`).
class PixelSprite extends StatelessWidget {
  const PixelSprite({
    super.key,
    required this.asset,
    required this.size,
    this.semanticLabel,
    this.fallback,
  });

  final String asset;
  final double size;
  final String? semanticLabel;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stack) {
        return fallback ?? SizedBox(width: size, height: size);
      },
    );
  }
}

/// The blurred ellipse a sprite casts on the ground.
class GroundShadow extends StatelessWidget {
  const GroundShadow({
    super.key,
    this.width = 120,
    this.height = 15,
    this.color = const Color(0x335A482C),
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.all(
              Radius.elliptical(width / 2, height / 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// True when the platform's "reduce motion" setting is on.
///
/// Looping decoration holds still when it is; one-shot feedback (the stamp
/// landing, a card rising in) still plays, because those animations carry
/// meaning rather than atmosphere.
bool _motionMuted(BuildContext context) {
  return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

/// `@keyframes bob` — a sprite floating in place.
class BobbingSprite extends StatefulWidget {
  const BobbingSprite({
    super.key,
    required this.child,
    this.period = MasilPetMotion.bob,
    this.distance = 10,
  });

  final Widget child;
  final Duration period;
  final double distance;

  @override
  State<BobbingSprite> createState() => _BobbingSpriteState();
}

class _BobbingSpriteState extends State<BobbingSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    // The ticker mode is only safe to read from didChangeDependencies, which
    // runs next and starts the loop.
    _controller = AnimationController(duration: widget.period, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _muted = _motionMuted(context);
    _syncMotion();
  }

  @override
  void didUpdateWidget(BobbingSprite old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period) {
      _controller.duration = widget.period;
      _controller.reset();
      _syncMotion();
    }
  }

  void _syncMotion() {
    if (_muted) {
      _controller.stop(canceled: false);
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Standing still means standing on the ground, not frozen mid-float.
    if (_muted) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = math.sin(_controller.value * 2 * math.pi);
        return Transform.translate(
          offset: Offset(0, -widget.distance * (phase + 1) / 2),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// `@keyframes ring` — the halo pulsing out of an active marker.
class PulseRing extends StatefulWidget {
  const PulseRing({
    super.key,
    required this.size,
    this.color = MasilPetPalette.stamp,
    this.strokeWidth = 2,
    this.period = MasilPetMotion.ring,
  });

  final double size;
  final Color color;
  final double strokeWidth;
  final Duration period;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.period, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _muted = _motionMuted(context);
    if (_muted) {
      _controller.stop(canceled: false);
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Held at the start of the pulse: still a halo marking the spot, just no
    // longer breathing.
    if (_muted) {
      return IgnorePointer(
        child: Opacity(opacity: 0.5, child: _ring()),
      );
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_controller.value);
          return Opacity(
            opacity: (0.5 * (1 - t)).clamp(0.0, 1.0),
            child: Transform.scale(scale: 1 + t * 1.8, child: child),
          );
        },
        child: _ring(),
      ),
    );
  }

  Widget _ring() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.color,
          width: widget.strokeWidth,
        ),
      ),
    );
  }
}

/// `@keyframes riseIn` — content settling onto the page.
class RiseIn extends StatefulWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.duration = MasilPetMotion.rise,
    this.offset = 16,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration duration;
  final double offset;
  final Duration delay;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// `@keyframes popIn` — a panel springing open.
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 180),
  });

  final Widget child;
  final Duration duration;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // 0 → .6, .7 → 1.06, 1 → 1
        final scale = t < 0.7
            ? ui.lerpDouble(0.6, 1.06, t / 0.7)!
            : ui.lerpDouble(1.06, 1.0, (t - 0.7) / 0.3)!;
        return Opacity(
          opacity: (t / 0.7).clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// `@keyframes shake` — an egg that is ready to hatch.
class ShakeLoop extends StatefulWidget {
  const ShakeLoop({
    super.key,
    required this.child,
    this.active = true,
    this.period = MasilPetMotion.shake,
  });

  final Widget child;
  final bool active;
  final Duration period;

  @override
  State<ShakeLoop> createState() => _ShakeLoopState();
}

class _ShakeLoopState extends State<ShakeLoop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _muted = false;

  bool get _shaking => widget.active && !_muted;

  @override
  void initState() {
    super.initState();
    // Built eagerly: a lazily created controller would first come to life
    // inside dispose(), where looking up the ticker mode is unsafe.
    _controller = AnimationController(
      duration: widget.period,
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _muted = _motionMuted(context);
    _syncMotion();
  }

  @override
  void didUpdateWidget(ShakeLoop old) {
    super.didUpdateWidget(old);
    _syncMotion();
  }

  void _syncMotion() {
    if (_shaking && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_shaking && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shaking) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // 0/1 → 0deg, .2 → -7deg, .4 → 6deg, .6 → -4deg, .8 → 3deg
        const stops = [0.0, -7.0, 6.0, -4.0, 3.0, 0.0];
        final scaled = t * (stops.length - 1);
        final index = scaled.floor().clamp(0, stops.length - 2);
        final local = scaled - index;
        final degrees = ui.lerpDouble(stops[index], stops[index + 1], local)!;
        return Transform.rotate(
          angle: degrees * math.pi / 180,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ────────────────────────────────────────────────────────────────  glyphs ──

/// The five navigation marks, in table-of-contents order.
enum PaperGlyphKind {
  /// 지도 — a stamp pin.
  map,

  /// 하우스 — a gabled house.
  house,

  /// 마실펫 — a paw print.
  pet,

  /// 도감 — an open book.
  dex,

  /// 기록 — a stamped circle.
  record,
}

/// A pen-drawn navigation mark.
///
/// The shell carries no Material icons on purpose, so navigation gets these
/// instead: single ink strokes, bowed slightly off true the way a pen line
/// never runs perfectly straight.
class PaperGlyph extends StatelessWidget {
  const PaperGlyph({
    super.key,
    required this.kind,
    this.size = 18,
    this.color = MasilPetPalette.ink,
  });

  final PaperGlyphKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _PaperGlyphPainter(kind: kind, color: color),
      ),
    );
  }
}

class _PaperGlyphPainter extends CustomPainter {
  const _PaperGlyphPainter({required this.kind, required this.color});

  final PaperGlyphKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) {
      return;
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      // Thin enough to stay a line at 16px, thick enough to read at 28px.
      ..strokeWidth = (s * 0.085).clamp(1.2, 2.2)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    /// Glyphs are authored on a unit square so one set of coordinates serves
    /// every size.
    Offset p(double x, double y) => Offset(x * s, y * s);

    /// Joins points with a slight outward bow instead of straight segments.
    Path pen(List<Offset> points, {double bow = 0.02}) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        final from = points[i - 1];
        final to = points[i];
        final delta = to - from;
        final length = delta.distance;
        final mid = (from + to) / 2;
        final offset = length == 0
            ? Offset.zero
            : Offset(-delta.dy, delta.dx) / length * (bow * s);
        path.quadraticBezierTo(
          mid.dx + offset.dx,
          mid.dy + offset.dy,
          to.dx,
          to.dy,
        );
      }
      return path;
    }

    void oval(Offset center, double width, double height) {
      canvas.drawOval(
        Rect.fromCenter(center: center, width: width * s, height: height * s),
        fill,
      );
    }

    switch (kind) {
      case PaperGlyphKind.map:
        // Head and point overlap, the way a pin reads at a glance.
        canvas.drawCircle(p(0.5, 0.4), 0.3 * s, stroke);
        canvas.drawPath(
            pen([p(0.26, 0.62), p(0.5, 0.95), p(0.74, 0.62)]), stroke);
        canvas.drawCircle(p(0.5, 0.4), 0.095 * s, fill);
      case PaperGlyphKind.house:
        canvas.drawPath(
            pen([p(0.1, 0.47), p(0.5, 0.13), p(0.9, 0.47)]), stroke);
        canvas.drawPath(
          pen([p(0.21, 0.42), p(0.21, 0.89), p(0.79, 0.89), p(0.79, 0.42)]),
          stroke,
        );
        canvas.drawPath(
          pen([p(0.42, 0.89), p(0.42, 0.65), p(0.58, 0.65), p(0.58, 0.89)]),
          stroke,
        );
      case PaperGlyphKind.pet:
        // Solid pads — outlined toes turn to mush below 20px.
        oval(p(0.5, 0.73), 0.52, 0.42);
        oval(p(0.17, 0.43), 0.19, 0.25);
        oval(p(0.39, 0.27), 0.2, 0.27);
        oval(p(0.61, 0.27), 0.2, 0.27);
        oval(p(0.83, 0.43), 0.19, 0.25);
      case PaperGlyphKind.dex:
        canvas.drawPath(pen([p(0.5, 0.27), p(0.5, 0.86)], bow: 0), stroke);
        canvas.drawPath(
          pen([
            p(0.5, 0.27),
            p(0.28, 0.16),
            p(0.09, 0.21),
            p(0.09, 0.74),
            p(0.3, 0.71),
            p(0.5, 0.86),
          ]),
          stroke,
        );
        canvas.drawPath(
          pen([
            p(0.5, 0.27),
            p(0.72, 0.16),
            p(0.91, 0.21),
            p(0.91, 0.74),
            p(0.7, 0.71),
            p(0.5, 0.86),
          ], bow: -0.02),
          stroke,
        );
      case PaperGlyphKind.record:
        canvas.drawCircle(p(0.5, 0.5), 0.38 * s, stroke);
        canvas.drawPath(
          pen([p(0.3, 0.52), p(0.44, 0.67), p(0.71, 0.34)]),
          stroke,
        );
    }
  }

  @override
  bool shouldRepaint(_PaperGlyphPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}

// ─────────────────────────────────────────────────────────────────  grain ──

/// The paper grain laid over the whole app (`mix-blend-mode: multiply`).
///
/// The texture is generated once and tiled, so this costs one 140×140 image
/// for the lifetime of the process.
class GrainOverlay extends StatefulWidget {
  const GrainOverlay({super.key, this.strength = 0.05});

  /// How much fibre shows through, 0–1. Kept low on purpose: the grain has to
  /// stay under the type, never over it.
  final double strength;

  static const _tileSize = 140;
  static Future<ui.Image>? _texture;

  static Future<ui.Image> _grainTexture() {
    return _texture ??= _buildGrainTexture();
  }

  static Future<ui.Image> _buildGrainTexture() {
    const size = _tileSize;
    final random = math.Random(20260729);
    final pixels = Uint8List(size * size * 4);
    for (var i = 0; i < size * size; i++) {
      // Warm ink speckle laid straight over the paper. The tile carries the
      // randomness; `strength` scales the whole thing at paint time.
      final offset = i * 4;
      pixels[offset] = 107;
      pixels[offset + 1] = 86;
      pixels[offset + 2] = 54;
      pixels[offset + 3] = random.nextInt(256);
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      size,
      size,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  @override
  State<GrainOverlay> createState() => _GrainOverlayState();
}

class _GrainOverlayState extends State<GrainOverlay> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    GrainOverlay._grainTexture().then((image) {
      if (mounted) {
        setState(() => _image = image);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        painter: _GrainPainter(image, strength: widget.strength),
        size: Size.infinite,
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter(this.image, {required this.strength});

  final ui.Image image;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    // Straight source-over at a low alpha. Wrapping this in Opacity and
    // multiplying would blend against a transparent layer instead of the page
    // and turn the whole app dark.
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      repeat: ImageRepeat.repeat,
      fit: BoxFit.none,
      alignment: Alignment.topLeft,
      opacity: strength.clamp(0.0, 1.0),
      filterQuality: FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.image != image || old.strength != strength;
}

// ─────────────────────────────────────────────────────────────────  misc ──

/// Onboarding progress dots: a 22×5 bar for the current step.
///
/// When [onSelected] is given the dots become taps back to a page the reader
/// has already seen; pages ahead stay inert so the dots never skip the story.
class StepDots extends StatelessWidget {
  const StepDots({
    super.key,
    required this.count,
    required this.index,
    this.onSelected,
  });

  final int count;
  final int index;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          _StepDot(
            active: i == index,
            // A dot is only a control while it points backwards.
            onTap:
                onSelected == null || i >= index ? null : () => onSelected!(i),
            label: '${i + 1}단계로 돌아가기',
          ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.active,
    required this.onTap,
    required this.label,
  });

  /// A 5px dot is not a tap target; this padding around it is. Every dot
  /// carries it, tappable or not, so the row keeps one height.
  static const _touchInset = EdgeInsets.symmetric(vertical: 10);

  final bool active;
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dot = Padding(
      padding: EdgeInsets.fromLTRB(
        active ? 3.5 : 8.5,
        _touchInset.vertical / 2,
        active ? 3.5 : 8.5,
        _touchInset.vertical / 2,
      ),
      child: AnimatedContainer(
        duration: MasilPetMotion.fast,
        width: active ? 22 : 5,
        height: 5,
        decoration: BoxDecoration(
          color: active ? MasilPetPalette.ink : MasilPetPalette.outlineFaint,
          borderRadius: const BorderRadius.all(Radius.circular(3)),
        ),
      ),
    );

    if (onTap == null) {
      return dot;
    }

    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: dot,
        ),
      ),
    );
  }
}

/// The brand lockup: a rotated 마 seal beside the wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.showTagline = true,
    this.sealSize = 34,
    this.wordmarkSize = 17,
  });

  final bool showTagline;
  final double sealSize;
  final double wordmarkSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.rotate(
          angle: -8 * math.pi / 180,
          child: Container(
            width: sealSize,
            height: sealSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: MasilPetPalette.stamp, width: 1.5),
            ),
            child: Text(
              '마',
              style: MasilPetType.rowTitle.copyWith(
                fontSize: sealSize * 0.44,
                color: MasilPetPalette.stamp,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '마실펫',
          style: MasilPetType.rowTitle.copyWith(
            fontSize: wordmarkSize,
            letterSpacing: 0.34,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(width: 10),
          // On very narrow phones the tagline gives way rather than overflow.
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'WALK · MEET · GROW',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: MasilPetType.microMono.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A row in the "오늘의 돌봄" checklist.
class RoutineRow extends StatelessWidget {
  const RoutineRow({
    super.key,
    required this.label,
    required this.done,
    required this.tag,
    this.showRule = true,
  });

  final String label;
  final bool done;
  final String tag;
  final bool showRule;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Container(
                width: 21,
                height: 21,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        done ? MasilPetPalette.forest : MasilPetPalette.outline,
                    width: 1.5,
                  ),
                  borderRadius: MasilPetRadii.tightBorder,
                ),
                child: done
                    ? Text(
                        '✓',
                        style: MasilPetType.bodySmall.copyWith(
                          fontSize: 13,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: MasilPetPalette.forest,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: MasilPetType.bodySmall.copyWith(
                    fontSize: 14.5,
                    height: 1.3,
                    color:
                        done ? MasilPetPalette.mutedWarm : MasilPetPalette.ink,
                  ),
                ),
              ),
              Text(
                tag,
                style: MasilPetType.microMono.copyWith(
                  fontSize: 10,
                  letterSpacing: 0,
                  color: MasilPetPalette.faintWarm,
                ),
              ),
            ],
          ),
        ),
        if (showRule) const DashedRule(color: MasilPetPalette.hover),
      ],
    );
  }
}
