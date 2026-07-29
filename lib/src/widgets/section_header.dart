import 'package:flutter/material.dart';

import '../theme.dart';
import 'paper_kit.dart';

/// A serif section heading with an optional monospaced counter on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.detail,
    super.key,
  });

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return SectionTitleRow(
      title: title,
      trailing: detail == null
          ? null
          : Text(
              detail,
              style: MasilPetType.metaMono,
            ),
    );
  }
}

/// The "nothing here yet" note: a dashed callout in the page's own voice.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    required this.title,
    required this.body,
    this.note,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String body;
  final String? note;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;

    return DashedBox(
      fill: MasilPetPalette.subtle,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note != null) ...[
            HandNote(note!),
            const SizedBox(height: MasilPetSpacing.xs),
          ],
          Text(title, style: MasilPetType.sectionTitle),
          const SizedBox(height: MasilPetSpacing.xxs),
          Text(body, style: MasilPetType.bodySmall),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: MasilPetSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: PaperButton.ghost(
                label: actionLabel,
                onPressed: onAction,
                expand: false,
                fontSize: 14,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
