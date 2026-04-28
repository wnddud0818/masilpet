import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state.dart';
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
              PetPlayField(
                templates: state.templates,
                pets: state.pets,
                eggs: state.eggs,
                activePetId: state.activePetId,
                activity: state.fieldActivity,
                activityNonce: state.fieldActivityNonce,
              ),
              const SizedBox(height: 12),
              if (pet == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('아직 함께할 마실펫이 없습니다. 알을 부화해 보세요.'),
                  ),
                )
              else
                _ActivePetPanel(petId: pet.id),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          state.isBusy ? null : controller.talkWithActivePet,
                      icon: const Icon(Icons.forum_outlined),
                      label: const Text('대화'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.isBusy ? null : controller.feedActivePet,
                      icon: const Icon(Icons.restaurant_outlined),
                      label: const Text('먹이주기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
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
          ],
        ),
      ),
    );
  }
}
