import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
  });

  final String text;
  final TextStyle? style;
  final double? maxWidth;
  final TextAlign textAlign;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget bubble = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: MasilPetBorders.inkBox,
        borderRadius: MasilPetRadii.bubbleBorder,
        boxShadow: MasilPetShadows.bubble,
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
class FilterPillRow<T> extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final value in values) ...[
            FilterPill(
              label: labelOf(value),
              selected: value == selected,
              onTap: () => onSelected(value),
            ),
            if (value != values.last) const SizedBox(width: 7),
          ],
        ],
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}

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

    return IgnorePointer(
      child: ColoredBox(
        color: MasilPetPalette.ink.withValues(alpha: 0.42),
        child: Center(
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, child) {
              final t = progress.value;
              final scale = ui.lerpDouble(1.9, 1.0, t)!;
              final angle = ui.lerpDouble(-26, -9, t)! * math.pi / 180;
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.period,
      vsync: this,
    )..repeat();
  }

  @override
  void didUpdateWidget(BobbingSprite old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period) {
      _controller.duration = widget.period;
      _controller
        ..reset()
        ..repeat();
    }
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.period,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color,
              width: widget.strokeWidth,
            ),
          ),
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

  @override
  void initState() {
    super.initState();
    // Built eagerly: a lazily created controller would first come to life
    // inside dispose(), where looking up the ticker mode is unsafe.
    _controller = AnimationController(
      duration: widget.period,
      vsync: this,
    );
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(ShakeLoop old) {
    super.didUpdateWidget(old);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
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
    if (!widget.active) {
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
class StepDots extends StatelessWidget {
  const StepDots({
    super.key,
    required this.count,
    required this.index,
  });

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: i == index ? 3.5 : 8.5),
            child: AnimatedContainer(
              duration: MasilPetMotion.fast,
              width: i == index ? 22 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: i == index
                    ? MasilPetPalette.ink
                    : MasilPetPalette.outlineFaint,
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
            ),
          ),
      ],
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
