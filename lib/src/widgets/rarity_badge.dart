import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

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
    final tokens = context.masilPetTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.11),
          tokens.paper,
        ),
        borderRadius: MasilPetRadii.pillBorder,
        border: Border.all(
          color: color.withValues(alpha: 0.34),
          width: 1.05,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
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
      return MasilPetPalette.skyDeep;
    case 'epic':
      return MasilPetPalette.lavenderDeep;
    case 'common':
      return MasilPetPalette.leaf;
    default:
      return MasilPetPalette.mutedInk;
  }
}

IconData _rarityIcon(String rarity) {
  switch (rarity.trim().toLowerCase()) {
    case 'rare':
      return Icons.diamond_outlined;
    case 'epic':
      return Icons.auto_awesome;
    default:
      return Icons.star_rounded;
  }
}
