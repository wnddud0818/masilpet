import 'package:flutter/material.dart';

class MetricGridItem {
  const MetricGridItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({
    required this.items,
    this.spacing = 8,
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
                _MetricTile(item: item),
              ],
            ],
          );
        }

        final columns = _columnCount(constraints.maxWidth, items.length);
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _MetricTile(item: item),
              ),
          ],
        );
      },
    );
  }

  int _columnCount(double width, int itemCount) {
    final preferredColumns = switch (width) {
      < 220 => 1,
      < 360 => 2,
      _ => 3,
    };
    return itemCount < preferredColumns ? itemCount : preferredColumns;
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.item});

  final MetricGridItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 82),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, size: 18, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              item.value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: Theme.of(context).textTheme.labelSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
