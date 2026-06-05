import 'package:flutter/material.dart';

import '../models.dart';

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
        ),
        if (reward.stats.mood > 0)
          _RewardChip(
            icon: Icons.sentiment_satisfied_alt_outlined,
            label: '기분 +${reward.stats.mood}',
          ),
        if (reward.stats.knowledge > 0)
          _RewardChip(
            icon: Icons.menu_book_outlined,
            label: '지식 +${reward.stats.knowledge}',
          ),
        if (reward.stats.affinity > 0)
          _RewardChip(
            icon: Icons.favorite_outline,
            label: '친밀도 +${reward.stats.affinity}',
          ),
        _RewardChip(
          icon: Icons.egg_alt_outlined,
          label: '알 +${reward.eggProgress}',
        ),
      ],
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
