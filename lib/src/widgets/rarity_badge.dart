import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'paper_kit.dart';

/// Rarity inked at a slight angle, like a grade stamped on a collector card.
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
    return RarityStamp(
      rarityDisplayLabel(rarity),
      angleDegrees: compact ? 0 : -4,
      color: color,
      border: color.withValues(alpha: 0.42),
    );
  }
}

Color _rarityColor(String rarity) {
  switch (rarity.trim().toLowerCase()) {
    case 'rare':
      return MasilPetPalette.statClean;
    case 'epic':
      return MasilPetPalette.catCulture;
    case 'common':
      return MasilPetPalette.forest;
    default:
      return MasilPetPalette.mutedWarm;
  }
}
