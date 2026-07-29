import 'package:flutter/material.dart';

import 'paper_kit.dart';

/// A care stat rendered as a bordered track with a monospaced readout.
class StatBar extends StatelessWidget {
  const StatBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    super.key,
  });

  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0).toDouble();

    return Semantics(
      container: true,
      label: label,
      value: '$value / $max',
      child: ExcludeSemantics(
        child: PaperStatBar(
          label: label,
          // A 0–100 gauge reads as a plain number on the page; anything else
          // keeps its denominator.
          valueLabel: max == 100 ? '$value' : '$value / $max',
          ratio: ratio,
          color: color,
        ),
      ),
    );
  }
}
