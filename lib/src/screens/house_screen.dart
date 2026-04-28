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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '알',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  OutlinedButton.icon(
                    onPressed: state.isBusy
                        ? null
                        : () => controller.addStepProgress(500),
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('500걸음 반영'),
                  ),
                ],
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
                      Text('${egg.progress} / ${egg.requiredSteps} 걸음'),
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
