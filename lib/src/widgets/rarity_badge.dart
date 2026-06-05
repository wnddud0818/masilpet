import 'package:flutter/material.dart';

import '../models.dart';

class RarityBadge extends StatelessWidget {
  const RarityBadge({
    required this.rarity,
    this.compact = false,
    super.key,
  });

  final String rarity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor(rarity);
    final label = rarityDisplayLabel(rarity);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _rarityIcon(rarity),
            size: compact ? 13 : 14,
            color: color,
          ),
          SizedBox(width: compact ? 4 : 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

Color _rarityColor(String rarity) {
  switch (rarity.trim().toLowerCase()) {
    case 'rare':
      return const Color(0xFF2563EB);
    case 'epic':
      return const Color(0xFF7C3AED);
    case 'common':
      return const Color(0xFF0F766E);
    default:
      return const Color(0xFF64748B);
  }
}

IconData _rarityIcon(String rarity) {
  switch (rarity.trim().toLowerCase()) {
    case 'rare':
      return Icons.diamond_outlined;
    case 'epic':
      return Icons.auto_awesome;
    default:
      return Icons.star_border_rounded;
  }
}
