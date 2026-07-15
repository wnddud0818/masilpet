import 'package:flutter/material.dart';

import '../theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.detail,
    this.icon,
    super.key,
  });

  final String title;
  final String? detail;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.masilPetTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MasilPetSpacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.mint.withValues(alpha: 0.72),
                borderRadius: MasilPetRadii.smallBorder,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Icon(icon, size: 18, color: scheme.primary),
            ),
            const SizedBox(width: MasilPetSpacing.sm),
          ] else ...[
            Container(
              width: 4,
              height: 20,
              decoration: const BoxDecoration(
                color: MasilPetPalette.leaf,
                borderRadius: MasilPetRadii.pillBorder,
              ),
            ),
            const SizedBox(width: MasilPetSpacing.sm),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(width: MasilPetSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: MasilPetSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: MasilPetRadii.pillBorder,
                border: Border.all(color: tokens.outline),
              ),
              child: Text(
                detail!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: tokens.mutedInk,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.masilPetTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(MasilPetSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tokens.mint,
                    MasilPetPalette.sunPale,
                  ],
                ),
                borderRadius: MasilPetRadii.controlBorder,
                border: Border.all(color: tokens.outline, width: 1.1),
                boxShadow: MasilPetShadows.soft,
              ),
              child: Icon(icon, color: scheme.primary),
            ),
            const SizedBox(width: MasilPetSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: tokens.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: MasilPetSpacing.xxs),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.mutedInk,
                        ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: MasilPetSpacing.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: onAction,
                        icon: Icon(actionIcon ?? Icons.arrow_forward),
                        label: Text(actionLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
