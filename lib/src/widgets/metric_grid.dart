import 'package:flutter/material.dart';

import '../theme.dart';

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
    final tokens = context.masilPetTheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: '${item.label}: ${item.value}',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 94),
          child: Container(
            padding: const EdgeInsets.all(MasilPetSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tokens.paper,
                  scheme.surfaceContainerHigh.withValues(alpha: 0.78),
                ],
              ),
              borderRadius: MasilPetRadii.panelBorder,
              border: Border.all(color: tokens.outline, width: 1.1),
              boxShadow: MasilPetShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.mint.withValues(alpha: 0.68),
                    borderRadius: MasilPetRadii.smallBorder,
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Icon(item.icon, size: 18, color: scheme.primary),
                ),
                const SizedBox(height: MasilPetSpacing.sm),
                Text(
                  item.value,
                  maxLines: 1,
                  style: textTheme.titleMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: MasilPetSpacing.xxs),
                Text(
                  item.label,
                  maxLines: 1,
                  style: textTheme.labelSmall?.copyWith(
                    color: tokens.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
