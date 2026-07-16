import 'package:flutter/material.dart';

import '../theme.dart';

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
    final tokens = context.masilPetTheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: label,
      value: '$value / $max',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: textTheme.labelLarge?.copyWith(
                      color: tokens.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MasilPetSpacing.sm,
                    vertical: MasilPetSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: MasilPetRadii.pillBorder,
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: MasilPetSpacing.xs),
                      Text(
                        '$value / $max',
                        style: textTheme.labelMedium?.copyWith(
                          color: tokens.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MasilPetSpacing.sm),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: MasilPetRadii.pillBorder,
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: ClipRRect(
                borderRadius: MasilPetRadii.pillBorder,
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: ratio,
                  backgroundColor: tokens.paper.withValues(alpha: 0.76),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
