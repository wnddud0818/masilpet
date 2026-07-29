import 'package:flutter/material.dart';

import '../models.dart';
import 'paper_kit.dart';

/// What a stamped visit earned, written as monospaced tags.
class RewardChipRow extends StatelessWidget {
  const RewardChipRow({
    super.key,
    required this.reward,
    this.spacing = 7,
    this.runSpacing = 7,
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
        MonoChip('EXP +${reward.stats.exp}'),
        if (reward.stats.mood > 0) MonoChip('기분 +${reward.stats.mood}'),
        if (reward.stats.knowledge > 0)
          MonoChip('지식 +${reward.stats.knowledge}'),
        if (reward.stats.affinity > 0)
          MonoChip('친밀도 +${reward.stats.affinity}'),
        MonoChip('알 +${reward.eggProgress}걸음'),
      ],
    );
  }
}
