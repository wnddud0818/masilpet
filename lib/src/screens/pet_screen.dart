import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../services.dart';
import '../state.dart';
import '../widgets/metric_grid.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pet_play_field.dart';
import '../widgets/rarity_badge.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/reward_chip_row.dart';
import '../widgets/stat_bar.dart';
import '../widgets/status_banner.dart';

class PetScreen extends ConsumerWidget {
  const PetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);
    final pet = state.activePet;

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('마실펫')),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: ResponsiveSliverList(
            children: [
              const StatusBanner(),
              const SizedBox(height: 12),
              _PetCareLayout(
                state: state,
                pet: pet,
                isBusy: state.isBusy,
                onTalk: controller.talkWithActivePet,
                onFeed: controller.feedActivePet,
                onOpenMap: () => controller.setTab(0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PetCareLayout extends StatelessWidget {
  const _PetCareLayout({
    required this.state,
    required this.pet,
    required this.isBusy,
    required this.onTalk,
    required this.onFeed,
    required this.onOpenMap,
  });

  static const _wideBreakpoint = 840.0;

  final MasilPetState state;
  final Pet? pet;
  final bool isBusy;
  final VoidCallback onTalk;
  final VoidCallback onFeed;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final talksLeft = _talksLeftToday(state);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= _wideBreakpoint;
        final playField = PetPlayField(
          templates: state.templates,
          pets: state.pets,
          eggs: state.eggs,
          activePetId: state.activePetId,
          activity: state.fieldActivity,
          activityNonce: state.fieldActivityNonce,
          height: useTwoColumns ? 420 : 260,
        );
        final actions = _CareActionRow(
          isBusy: isBusy,
          talksLeft: talksLeft,
          onTalk: onTalk,
          onFeed: onFeed,
        );
        final companionCard = pet == null
            ? null
            : _CompanionDialogueCard(
                state: state,
                pet: pet!,
                talksLeft: talksLeft,
                isBusy: isBusy,
                onTalk: onTalk,
                onOpenMap: onOpenMap,
              );
        final details = pet == null
            ? const _NoActivePetCard()
            : _ActivePetPanel(petId: pet!.id);

        if (!useTwoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              playField,
              const SizedBox(height: 12),
              if (pet != null) ...[
                _CareReadinessCard(pet: pet!),
                const SizedBox(height: 12),
                companionCard!,
                const SizedBox(height: 12),
                actions,
                const SizedBox(height: 12),
              ],
              details,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  playField,
                  if (pet != null) ...[
                    const SizedBox(height: 12),
                    companionCard!,
                    const SizedBox(height: 12),
                    actions,
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (pet != null) ...[
                    _CareReadinessCard(pet: pet!),
                    const SizedBox(height: 12),
                  ],
                  details,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CareActionRow extends StatelessWidget {
  const _CareActionRow({
    required this.isBusy,
    required this.talksLeft,
    required this.onTalk,
    required this.onFeed,
  });

  final bool isBusy;
  final int talksLeft;
  final VoidCallback onTalk;
  final VoidCallback onFeed;

  @override
  Widget build(BuildContext context) {
    final canTalk = talksLeft > 0;

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: isBusy || !canTalk ? null : onTalk,
            icon: Icon(
              canTalk ? Icons.forum_outlined : Icons.check_circle_outline,
            ),
            label: Text(canTalk ? '대화' : '대화 완료'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isBusy ? null : onFeed,
            icon: const Icon(Icons.restaurant_outlined),
            label: const Text('먹이주기'),
          ),
        ),
      ],
    );
  }
}

class _CompanionDialogueCard extends StatelessWidget {
  const _CompanionDialogueCard({
    required this.state,
    required this.pet,
    required this.talksLeft,
    required this.isBusy,
    required this.onTalk,
    required this.onOpenMap,
  });

  final MasilPetState state;
  final Pet pet;
  final int talksLeft;
  final bool isBusy;
  final VoidCallback onTalk;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final template = state.templates.firstWhere(
      (item) => item.id == pet.templateId,
      orElse: () => state.templates.first,
    );
    final latestCheckIn = _latestCheckInForDialogue(state);
    final latestPoi = latestCheckIn == null
        ? null
        : _poiForDialogueCheckIn(state, latestCheckIn);
    final memoryCategory = state.lastVisitedCategory ?? latestCheckIn?.category;
    final line = const StaticDialogueService().lineFor(
      template: template,
      lastCategory: memoryCategory,
    );
    final reward = latestCheckIn?.rewardApplied == true
        ? latestCheckIn?.reward ??
            const GrowthEngine().rewardFor(latestCheckIn!.category)
        : null;
    final scheme = Theme.of(context).colorScheme;
    final canTalk = talksLeft > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: scheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '동행 대화',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _DialogueMemoryBadge(
                  label: memoryCategory == null
                      ? '탐험 대기'
                      : '${memoryCategory.label} 기억',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '“${line.text}”',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            _DialogueMemoryLine(
              icon: latestCheckIn == null
                  ? Icons.explore_outlined
                  : Icons.place_outlined,
              text: latestCheckIn == null
                  ? '첫 체크인을 기록하면 장소 기억에 맞춘 대화가 열립니다.'
                  : '${latestPoi?.title ?? '저장된 방문 장소'} · ${latestCheckIn.category.label} · ${latestCheckIn.distanceMeters.round()}m',
            ),
            const SizedBox(height: 8),
            _DialogueMemoryLine(
              icon: Icons.forum_outlined,
              text: canTalk
                  ? '오늘 대화 ${5 - talksLeft}/5회 · $talksLeft회 남음'
                  : '오늘 대화 5/5회 · 새 장소를 다녀오면 내일 다시 이어집니다.',
            ),
            if (reward != null) ...[
              const SizedBox(height: 12),
              RewardChipRow(
                reward: reward,
                spacing: 6,
                runSpacing: 6,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: canTalk
                  ? FilledButton.icon(
                      onPressed: isBusy ? null : onTalk,
                      icon: const Icon(Icons.forum_outlined),
                      label: const Text('마실펫과 대화하기'),
                    )
                  : OutlinedButton.icon(
                      onPressed: isBusy ? null : onOpenMap,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('지도에서 새 이야기 찾기'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

CheckIn? _latestCheckInForDialogue(MasilPetState state) {
  final recent = state.recentCheckIns;
  return recent.isEmpty ? null : recent.first;
}

Poi? _poiForDialogueCheckIn(MasilPetState state, CheckIn checkIn) {
  for (final poi in state.pois) {
    if (poi.id == checkIn.poiId) {
      return poi;
    }
  }
  return null;
}

class _DialogueMemoryBadge extends StatelessWidget {
  const _DialogueMemoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _DialogueMemoryLine extends StatelessWidget {
  const _DialogueMemoryLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: scheme.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _NoActivePetCard extends ConsumerWidget {
  const _NoActivePetCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(masilPetControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.egg_alt_outlined,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '아직 함께할 마실펫이 없습니다',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text('하우스에서 알 상태를 확인하고 부화할 마실펫을 준비해 보세요.'),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => controller.setTab(2),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('하우스에서 알 보기'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareReadinessCard extends StatelessWidget {
  const _CareReadinessCard({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final expToNextLevel = 100 - (pet.stats.exp % 100);
    final safeExpToNextLevel = expToNextLevel == 100 ? 100 : expToNextLevel;

    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(masilPetControllerProvider);
        final talksLeft = _talksLeftToday(state);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 돌봄 루틴',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                MetricGrid(
                  items: [
                    MetricGridItem(
                      icon: Icons.forum_outlined,
                      label: '대화 가능',
                      value: '$talksLeft회',
                    ),
                    MetricGridItem(
                      icon: Icons.auto_graph,
                      label: '다음 레벨',
                      value: '$safeExpToNextLevel EXP',
                    ),
                    MetricGridItem(
                      icon: Icons.public,
                      label: '방문 보상',
                      value: state.lastVisitedCategory?.label ?? '대기',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

int _talksLeftToday(MasilPetState state) {
  final countToday = isSameLocalDay(state.dialogueDay, DateTime.now())
      ? state.dialogueCountToday
      : 0;
  return (5 - countToday).clamp(0, 5).toInt();
}

class _ActivePetPanel extends ConsumerWidget {
  const _ActivePetPanel({required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);
    final pet = state.pets.firstWhere((item) => item.id == petId);
    final template = controller.templateFor(pet.templateId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PetAvatar(template: template, size: 90, stage: pet.stage.name),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Lv.${pet.level} · ${pet.stage.label} 단계'),
                          RarityBadge(rarity: template.rarity, compact: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(template.basePersonality),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            StatBar(
              label: '경험치',
              value: pet.stats.exp,
              max: 500,
              color: const Color(0xFF2563EB),
            ),
            const SizedBox(height: 12),
            StatBar(
              label: '기분',
              value: pet.stats.mood,
              max: 120,
              color: const Color(0xFFF97316),
            ),
            const SizedBox(height: 12),
            StatBar(
              label: '지식',
              value: pet.stats.knowledge,
              max: 120,
              color: const Color(0xFF7C3AED),
            ),
            const SizedBox(height: 12),
            StatBar(
              label: '지역 친밀도',
              value: pet.stats.affinity,
              max: 150,
              color: const Color(0xFF0F766E),
            ),
            const SizedBox(height: 18),
            _StageGoal(pet: pet),
          ],
        ),
      ),
    );
  }
}

class _StageGoal extends ConsumerWidget {
  const _StageGoal({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(masilPetControllerProvider.notifier);
    final isComplete = pet.stage == PetStage.evolved;
    final nextLabel = switch (pet.stage) {
      PetStage.baby => '성장 단계',
      PetStage.grown => '진화 단계',
      PetStage.evolved => '최종 진화 완료',
    };
    final description = switch (pet.stage) {
      PetStage.baby =>
        'Lv.${GrowthEngine.grownLevelRequirement}까지 탐험 보상을 모으면 성장 단계가 열립니다.',
      PetStage.grown => '진화에는 레벨, 지식, 지역 친밀도가 모두 필요합니다.',
      PetStage.evolved => '전국 탐험의 깊은 기억을 모두 간직한 상태입니다.',
    };
    final requirements = _growthRequirementsFor(pet);
    final requirementTitle = switch (pet.stage) {
      PetStage.baby => '성장 조건',
      PetStage.grown => '진화 조건',
      PetStage.evolved => '완료 조건',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isComplete ? Icons.workspace_premium : Icons.flag_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nextLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(description),
                if (requirements.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    requirementTitle,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  for (final requirement in requirements) ...[
                    _GrowthRequirementRow(requirement: requirement),
                    if (requirement != requirements.last)
                      const SizedBox(height: 8),
                  ],
                ],
                if (!isComplete) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => controller.setTab(0),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('지도에서 성장 보상 얻기'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<_GrowthRequirement> _growthRequirementsFor(Pet pet) {
  return switch (pet.stage) {
    PetStage.baby => [
        _GrowthRequirement.level(
          currentLevel: pet.level,
          targetLevel: GrowthEngine.grownLevelRequirement,
        ),
      ],
    PetStage.grown => [
        _GrowthRequirement.level(
          currentLevel: pet.level,
          targetLevel: GrowthEngine.evolvedLevelRequirement,
        ),
        _GrowthRequirement.stat(
          icon: Icons.menu_book_outlined,
          label: '지식',
          current: pet.stats.knowledge,
          target: GrowthEngine.evolvedKnowledgeRequirement,
        ),
        _GrowthRequirement.stat(
          icon: Icons.handshake_outlined,
          label: '지역 친밀도',
          current: pet.stats.affinity,
          target: GrowthEngine.evolvedAffinityRequirement,
        ),
      ],
    PetStage.evolved => const [],
  };
}

class _GrowthRequirement {
  const _GrowthRequirement({
    required this.icon,
    required this.label,
    required this.current,
    required this.target,
    required this.valueLabel,
    required this.remainingLabel,
  });

  factory _GrowthRequirement.level({
    required int currentLevel,
    required int targetLevel,
  }) {
    final remaining = (targetLevel - currentLevel).clamp(0, targetLevel);
    return _GrowthRequirement(
      icon: Icons.auto_graph,
      label: '레벨',
      current: currentLevel,
      target: targetLevel,
      valueLabel: 'Lv.$currentLevel/$targetLevel',
      remainingLabel: remaining == 0 ? '완료' : '$remaining레벨 필요',
    );
  }

  factory _GrowthRequirement.stat({
    required IconData icon,
    required String label,
    required int current,
    required int target,
  }) {
    final remaining = (target - current).clamp(0, target);
    return _GrowthRequirement(
      icon: icon,
      label: label,
      current: current,
      target: target,
      valueLabel: '$current/$target',
      remainingLabel: remaining == 0 ? '완료' : '$remaining 필요',
    );
  }

  final IconData icon;
  final String label;
  final int current;
  final int target;
  final String valueLabel;
  final String remainingLabel;

  bool get isComplete => current >= target;

  double get progress {
    if (target <= 0) {
      return 1;
    }
    return (current / target).clamp(0.0, 1.0).toDouble();
  }
}

class _GrowthRequirementRow extends StatelessWidget {
  const _GrowthRequirementRow({required this.requirement});

  final _GrowthRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor =
        requirement.isComplete ? const Color(0xFF0F766E) : scheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            requirement.isComplete
                ? Icons.check_circle_outline
                : requirement.icon,
            size: 18,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      requirement.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    requirement.valueLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: requirement.progress,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            requirement.remainingLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}
