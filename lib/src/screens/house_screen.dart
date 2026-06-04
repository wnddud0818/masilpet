import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state.dart';
import '../widgets/metric_grid.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pet_play_field.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/section_header.dart';
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
              _HouseCollectionLayout(
                state: state,
                onSelectPet: controller.selectPet,
              ),
              const SizedBox(height: 16),
              PetPlayField(
                templates: state.templates,
                pets: state.pets,
                eggs: state.eggs,
                activePetId: state.activePetId,
                activity: state.fieldActivity,
                activityNonce: state.fieldActivityNonce,
                height: 180,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HouseCollectionLayout extends StatelessWidget {
  const _HouseCollectionLayout({
    required this.state,
    required this.onSelectPet,
  });

  static const _wideBreakpoint = 840.0;

  final MasilPetState state;
  final ValueChanged<String> onSelectPet;

  @override
  Widget build(BuildContext context) {
    final pets = _OwnedPetsSection(
      pets: state.pets,
      activePetId: state.activePetId,
      onSelectPet: onSelectPet,
    );
    final eggs = _EggsSection(eggs: state.eggs);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= _wideBreakpoint;
        if (!useTwoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              pets,
              const SizedBox(height: 16),
              eggs,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: pets),
            const SizedBox(width: 16),
            Expanded(child: eggs),
          ],
        );
      },
    );
  }
}

class _OwnedPetsSection extends StatelessWidget {
  const _OwnedPetsSection({
    required this.pets,
    required this.activePetId,
    required this.onSelectPet,
  });

  final List<Pet> pets;
  final String? activePetId;
  final ValueChanged<String> onSelectPet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: '보유 마실펫',
          detail: '${pets.length}종',
          icon: Icons.pets_outlined,
        ),
        if (pets.isEmpty)
          const EmptyStateCard(
            icon: Icons.pets_outlined,
            title: '함께 지내는 마실펫이 없습니다',
            body: '알을 부화하면 이곳에 보유 마실펫이 표시됩니다.',
          )
        else
          for (final pet in pets)
            _PetHouseTile(
              pet: pet,
              isActive: pet.id == activePetId,
              onSelect: () => onSelectPet(pet.id),
            ),
      ],
    );
  }
}

class _EggsSection extends StatelessWidget {
  const _EggsSection({required this.eggs});

  final List<Egg> eggs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: '알',
          detail: '${eggs.length}개',
          icon: Icons.egg_alt_outlined,
        ),
        if (eggs.isEmpty)
          const EmptyStateCard(
            icon: Icons.egg_alt_outlined,
            title: '부화할 알이 없습니다',
            body: '체크인 보상으로 새 알을 발견하면 이곳에 표시됩니다.',
          )
        else
          for (final egg in eggs) _EggTile(egg: egg),
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
            MetricGrid(
              items: [
                MetricGridItem(
                  icon: Icons.pets_outlined,
                  label: '보유 펫',
                  value: '${state.pets.length}/${state.templates.length}',
                ),
                MetricGridItem(
                  icon: Icons.egg_alt_outlined,
                  label: '부화 가능',
                  value: '${state.hatchableEggCount}개',
                ),
                MetricGridItem(
                  icon: Icons.directions_walk,
                  label: '남은 걸음',
                  value: remainingSteps == null ? '-' : '$remainingSteps',
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
    final isReadyToHatch = egg.status == EggStatus.hatchable;
    final canHatch = isReadyToHatch && !state.isBusy;
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
                _EggActionButton(
                  isReadyToHatch: isReadyToHatch,
                  canHatch: canHatch,
                  onHatch: () => controller.hatchEgg(egg.id),
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

class _EggActionButton extends StatelessWidget {
  const _EggActionButton({
    required this.isReadyToHatch,
    required this.canHatch,
    required this.onHatch,
  });

  final bool isReadyToHatch;
  final bool canHatch;
  final VoidCallback onHatch;

  @override
  Widget build(BuildContext context) {
    if (!isReadyToHatch) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.directions_walk),
        label: const Text('걸음 필요'),
      );
    }

    return FilledButton.icon(
      onPressed: canHatch ? onHatch : null,
      icon: const Icon(Icons.egg_alt_outlined),
      label: const Text('부화'),
    );
  }
}
