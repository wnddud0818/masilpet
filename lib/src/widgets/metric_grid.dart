import 'package:flutter/material.dart';

import 'paper_kit.dart';

class MetricGridItem {
  const MetricGridItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

/// A row of boxed totals: big serif number, small caption. Three across on a
/// phone, matching the design's `repeat(3,1fr)` grid.
class MetricGrid extends StatelessWidget {
  const MetricGrid({
    required this.items,
    this.spacing = 9,
    super.key,
  });

  final List<MetricGridItem> items;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) {
          return Column(
            children: [
              for (final (index, item) in items.indexed) ...[
                if (index > 0) SizedBox(height: spacing),
                PaperTotal(value: item.value, label: item.label),
              ],
            ],
          );
        }

        final columns = _columnCount(constraints.maxWidth, items.length);
        final itemWidth =
            ((constraints.maxWidth - spacing * (columns - 1)) / columns)
                .clamp(0.0, double.infinity);

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: PaperTotal(value: item.value, label: item.label),
              ),
          ],
        );
      },
    );
  }

  int _columnCount(double width, int itemCount) {
    final preferredColumns = switch (width) {
      < 220 => 1,
      < 300 => 2,
      _ => 3,
    };
    return itemCount < preferredColumns ? itemCount : preferredColumns;
  }
}
