import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pet_play_field.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/status_banner.dart';

class HouseScreen extends ConsumerWidget {
  const HouseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('하우스')),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: ResponsiveSliverList(
            children: [
              const StatusBanner(),
              const SizedBox(height: 12),
              _HouseOverviewCard(state: state),
              const SizedBox(height: 16),
              PetPlayField(
                templates: state.templates,
                pets: state.pets,
                eggs: state.eggs,
                activePetId: state.activePetId,
                activity: state.fieldActivity,
                activityNonce: state.fieldActivityNonce,
                height: 220,
              ),
              const SizedBox(height: 16),
              Text(
                '보유 마실펫',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              for (final pet in state.pets)
                _PetHouseTile(
                  pet: pet,
                  isActive: pet.id == state.activePetId,
                  onSelect: () => controller.selectPet(pet.id),
                ),
              const SizedBox(height: 16),
              Text(
                '알',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              if (state.eggs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('보유 중인 알이 없습니다. 부산 POI를 체크인해 새 알을 찾아보세요.'),
                  ),
                )
              else
                for (final egg in state.eggs) _EggTile(egg: egg),
            ],
          ),
        ),
      ],
    );
  }
}

class _HouseOverviewCard extends StatelessWidget {
  const _HouseOverviewCard({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context) {
    final nextEgg = state.eggs.isEmpty ? null : state.eggs.first;
    final remainingSteps = nextEgg == null
        ? null
        : (nextEgg.requiredSteps - nextEgg.progress)
            .clamp(0, nextEgg.requiredSteps);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '마실펫 하우스 현황',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HouseMetric(
                    icon: Icons.pets_outlined,
                    label: '보유 펫',
                    value: '${state.pets.length}/${state.templates.length}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HouseMetric(
                    icon: Icons.egg_alt_outlined,
                    label: '부화 가능',
                    value: '${state.hatchableEggCount}개',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HouseMetric(
                    icon: Icons.directions_walk,
                    label: '남은 걸음',
                    value: remainingSteps == null ? '-' : '$remainingSteps',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: state.dexCompletionRatio,
                backgroundColor: const Color(0xFFE2E8F0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HouseMetric extends StatelessWidget {
  const _HouseMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PetHouseTile extends ConsumerWidget {
  const _PetHouseTile({
    required this.pet,
    required this.isActive,
    required this.onSelect,
  });

  final Pet pet;
  final bool isActive;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(masilPetControllerProvider.notifier);
    final template = controller.templateFor(pet.templateId);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: PetAvatar(template: template, size: 52, stage: pet.stage.name),
        title: Text(pet.name),
        subtitle: Text('Lv.${pet.level} · ${pet.stage.label} 단계'),
        trailing: isActive
            ? const Icon(Icons.check_circle)
            : IconButton(
                tooltip: '대표 설정',
                onPressed: onSelect,
                icon: const Icon(Icons.flag_outlined),
              ),
      ),
    );
  }
}

class _EggTile extends ConsumerWidget {
  const _EggTile({required this.egg});

  final Egg egg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);
    final template = controller.templateFor(egg.templateId);
    final hatchable = egg.status == EggStatus.hatchable && !state.isBusy;
    final remainingSteps =
        (egg.requiredSteps - egg.progress).clamp(0, egg.requiredSteps);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PetAvatar(template: template, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${template.name}의 알',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        egg.status == EggStatus.hatchable
                            ? '부화 준비 완료'
                            : '$remainingSteps 걸음 남음',
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed:
                      hatchable ? () => controller.hatchEgg(egg.id) : null,
                  child: const Text('부화'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: egg.progressRatio),
          ],
        ),
      ),
    );
  }
}
