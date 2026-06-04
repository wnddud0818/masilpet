import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../services.dart';
import '../state.dart';
import '../widgets/metric_grid.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pet_play_field.dart';
import '../widgets/responsive_sliver_list.dart';
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
  });

  static const _wideBreakpoint = 840.0;

  final MasilPetState state;
  final Pet? pet;
  final bool isBusy;
  final VoidCallback onTalk;
  final VoidCallback onFeed;

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
                      Text(
                          'Lv.${pet.level} · ${pet.stage.label} 단계 · ${template.rarity}'),
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
      PetStage.baby => 'Lv.3을 달성하면 성장 단계로 올라갑니다.',
      PetStage.grown => 'Lv.5, 지식 50, 친밀도 100을 채우면 진화합니다.',
      PetStage.evolved => '부산 탐험의 깊은 기억을 간직한 상태입니다.',
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
