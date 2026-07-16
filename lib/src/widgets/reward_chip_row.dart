import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

class RewardChipRow extends StatelessWidget {
  const RewardChipRow({
    super.key,
    required this.reward,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  final CheckInReward reward;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        _RewardChip(
          icon: Icons.auto_graph,
          label: 'EXP +${reward.stats.exp}',
          color: MasilPetPalette.skyDeep,
          fill: MasilPetPalette.sky,
        ),
        if (reward.stats.mood > 0)
          _RewardChip(
            icon: Icons.sentiment_satisfied_alt_outlined,
            label: '기분 +${reward.stats.mood}',
            color: MasilPetPalette.coral,
            fill: MasilPetPalette.coralPale,
          ),
        if (reward.stats.knowledge > 0)
          _RewardChip(
            icon: Icons.menu_book_outlined,
            label: '지식 +${reward.stats.knowledge}',
            color: MasilPetPalette.lavenderDeep,
            fill: MasilPetPalette.lavender,
          ),
        if (reward.stats.affinity > 0)
          _RewardChip(
            icon: Icons.favorite_outline,
            label: '친밀도 +${reward.stats.affinity}',
            color: MasilPetPalette.leaf,
            fill: MasilPetPalette.mint,
          ),
        _RewardChip(
          icon: Icons.egg_alt_outlined,
          label: '알 +${reward.eggProgress}',
          color: MasilPetPalette.warning,
          fill: MasilPetPalette.sun,
        ),
      ],
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.fill,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final tokens = context.masilPetTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          fill.withValues(alpha: 0.18),
          tokens.paper,
        ),
        borderRadius: MasilPetRadii.pillBorder,
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.05),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill.withValues(alpha: 0.42),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: MasilPetSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
