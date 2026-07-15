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
              _HousePlayField(state: state),
              const SizedBox(height: 12),
              _HouseOverviewCard(state: state),
              const SizedBox(height: 12),
              _HouseCarePlanCard(
                state: state,
                onOpenMap: () => controller.setTab(0),
                onOpenPet: () => controller.setTab(1),
              ),
              const SizedBox(height: 16),
              _HouseCollectionLayout(
                state: state,
                onSelectPet: controller.selectPet,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HousePlayField extends StatelessWidget {
  const _HousePlayField({required this.state});

  static const _wideBreakpoint = 840.0;

  final MasilPetState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth >= _wideBreakpoint ? 360.0 : 300.0;

        return PetPlayField(
          templates: state.templates,
          pets: state.pets,
          eggs: state.eggs,
          activePetId: state.activePetId,
          activity: state.fieldActivity,
          activityNonce: state.fieldActivityNonce,
          height: height,
          scene: PetPlayFieldScene.neighborhoodYard,
          spriteScale: 1.16,
          showVisitors: false,
        );
      },
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

class _EggsSection extends ConsumerWidget {
  const _EggsSection({required this.eggs});

  final List<Egg> eggs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(masilPetControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: '알',
          detail: '${eggs.length}개',
          icon: Icons.egg_alt_outlined,
        ),
        if (eggs.isEmpty)
          EmptyStateCard(
            icon: Icons.egg_alt_outlined,
            title: '부화할 알이 없습니다',
            body: '체크인 보상으로 새 알을 발견하면 이곳에 표시됩니다.',
            actionIcon: Icons.map_outlined,
            actionLabel: '지도에서 체크인하기',
            onAction: () => controller.setTab(0),
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
    final nextEgg = state.nextEgg;
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    '도감 수집률',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  '${(state.dexCompletionRatio * 100).round()}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
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

class _HouseCarePlanCard extends ConsumerWidget {
  const _HouseCarePlanCard({
    required this.state,
    required this.onOpenMap,
    required this.onOpenPet,
  });

  final MasilPetState state;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenPet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(masilPetControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final activePet = state.activePet;
    final activeTemplate =
        activePet == null ? null : controller.templateFor(activePet.templateId);
    final nextEgg = state.nextEgg;
    final eggTemplate =
        nextEgg == null ? null : controller.templateFor(nextEgg.templateId);
    final remainingSteps = nextEgg == null ? null : _remainingEggSteps(nextEgg);
    final recommended = state.nextRecommendedPoi;
    final recommendedDistance = _recommendedDistance(state, recommended);
    final talksLeft = _houseTalksLeftToday(state);
    final mapFocusCategory =
        eggTemplate?.primaryCategory ?? recommended?.category;
    final openFocusedMap = mapFocusCategory == null
        ? onOpenMap
        : () => controller.setTab(0, mapCategoryFocus: mapFocusCategory);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_available_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '오늘의 하우스 플랜',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _HousePlanBadge(
                  label: state.todayCheckInCount == 0
                      ? '외출 대기'
                      : '${state.todayCheckInCount}회 체크인',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _housePlanSummary(
                activePet: activePet,
                nextEgg: nextEgg,
                eggTemplate: eggTemplate,
                talksLeft: talksLeft,
                state: state,
              ),
            ),
            const SizedBox(height: 12),
            _HousePlanItem(
              icon: Icons.pets_outlined,
              title: '대표 펫',
              body: activePet == null || activeTemplate == null
                  ? '부화한 마실펫이 생기면 오늘 돌봄 대상이 표시됩니다.'
                  : '${activePet.name} · Lv.${activePet.level} · ${activeTemplate.rarityLabel}',
              trailing: activePet == null
                  ? '대기'
                  : talksLeft > 0
                      ? '$talksLeft회 대화'
                      : '돌봄 완료',
              accentColor: scheme.primary,
            ),
            const SizedBox(height: 8),
            _HousePlanItem(
              icon: Icons.egg_alt_outlined,
              title: '집중 부화 알',
              body: nextEgg == null || eggTemplate == null
                  ? '체크인 보상으로 새 알을 발견하면 부화 목표가 열립니다.'
                  : '${eggTemplate.name}의 알 · ${_eggPlanStatus(nextEgg, remainingSteps!)}',
              trailing: nextEgg == null
                  ? '없음'
                  : '${(nextEgg.progressRatio * 100).round()}%',
              accentColor: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 8),
            _HousePlanItem(
              icon: Icons.signpost_outlined,
              title: '다음 외출',
              body: recommended == null
                  ? '지도에서 현재 위치를 확인하면 다음 체크인 후보가 표시됩니다.'
                  : '${recommended.title} · ${recommended.category.label}',
              trailing: _distanceLabel(recommendedDistance),
              accentColor: const Color(0xFF0F766E),
            ),
            const SizedBox(height: 12),
            _HousePlanActions(
              nextEgg: nextEgg,
              isBusy: state.isBusy,
              hasActivePet: activePet != null,
              talksLeft: talksLeft,
              onOpenMap: openFocusedMap,
              onOpenPet: onOpenPet,
              onHatch: nextEgg == null
                  ? null
                  : () => controller.hatchEgg(nextEgg.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _HousePlanBadge extends StatelessWidget {
  const _HousePlanBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
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

class _HousePlanItem extends StatelessWidget {
  const _HousePlanItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.trailing,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String body;
  final String trailing;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              trailing,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _HousePlanActions extends StatelessWidget {
  const _HousePlanActions({
    required this.nextEgg,
    required this.isBusy,
    required this.hasActivePet,
    required this.talksLeft,
    required this.onOpenMap,
    required this.onOpenPet,
    required this.onHatch,
  });

  final Egg? nextEgg;
  final bool isBusy;
  final bool hasActivePet;
  final int talksLeft;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenPet;
  final VoidCallback? onHatch;

  @override
  Widget build(BuildContext context) {
    final canHatch = nextEgg?.status == EggStatus.hatchable;
    final Widget primary = canHatch
        ? FilledButton.icon(
            onPressed: isBusy ? null : onHatch,
            icon: const Icon(Icons.egg_alt_outlined),
            label: const Text('지금 부화하기'),
          )
        : FilledButton.icon(
            onPressed: isBusy ? null : onOpenMap,
            icon: const Icon(Icons.map_outlined),
            label: const Text('지도에서 걸음 모으기'),
          );
    final Widget? secondary = canHatch
        ? OutlinedButton.icon(
            onPressed: isBusy ? null : onOpenMap,
            icon: const Icon(Icons.travel_explore),
            label: const Text('다음 알 찾기'),
          )
        : hasActivePet
            ? OutlinedButton.icon(
                onPressed: isBusy ? null : onOpenPet,
                icon: Icon(
                  talksLeft > 0
                      ? Icons.forum_outlined
                      : Icons.check_circle_outline,
                ),
                label: Text(talksLeft > 0 ? '마실펫 돌보기' : '마실펫 보기'),
              )
            : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget fullWidth(Widget child) {
          return SizedBox(width: double.infinity, child: child);
        }

        if (secondary == null) {
          return fullWidth(primary);
        }
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              fullWidth(primary),
              const SizedBox(height: 8),
              fullWidth(secondary),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: primary),
            const SizedBox(width: 8),
            Expanded(child: secondary),
          ],
        );
      },
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
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isActive
          ? scheme.primaryContainer.withValues(alpha: 0.22)
          : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isActive ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            PetAvatar(template: template, size: 52, stage: pet.stage.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Lv.${pet.level} · ${pet.stage.label} 단계'),
                      RarityBadge(rarity: template.rarity, compact: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isActive)
              _ActivePetBadge(color: scheme.primary)
            else
              OutlinedButton.icon(
                onPressed: onSelect,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('대표 설정'),
              ),
          ],
        ),
      ),
    );
  }
}

int _houseTalksLeftToday(MasilPetState state) {
  final countToday = isSameLocalDay(state.dialogueDay, DateTime.now())
      ? state.dialogueCountToday
      : 0;
  return (5 - countToday).clamp(0, 5).toInt();
}

int _remainingEggSteps(Egg egg) {
  return (egg.requiredSteps - egg.progress).clamp(0, egg.requiredSteps).toInt();
}

int? _recommendedDistance(MasilPetState state, Poi? poi) {
  if (poi == null || !state.hasFreshVerifiedLocation) {
    return null;
  }
  return state.currentLocation.distanceTo(poi.coordinates).round();
}

String _distanceLabel(int? distanceMeters) {
  return distanceMeters == null ? '위치 필요' : '${distanceMeters}m';
}

String _eggPlanStatus(Egg egg, int remainingSteps) {
  return switch (egg.status) {
    EggStatus.hatchable => '부화 준비 완료',
    EggStatus.incubating => '$remainingSteps 걸음 남음',
    EggStatus.hatched => '부화 완료',
  };
}

String _housePlanSummary({
  required Pet? activePet,
  required Egg? nextEgg,
  required PetTemplate? eggTemplate,
  required int talksLeft,
  required MasilPetState state,
}) {
  if (nextEgg?.status == EggStatus.hatchable && eggTemplate != null) {
    return '${eggTemplate.name}의 알이 준비됐습니다. 하우스에서 바로 부화해 수집률을 올릴 수 있습니다.';
  }
  if (activePet == null) {
    return '첫 알을 부화하면 대표 마실펫 돌봄 루틴이 시작됩니다.';
  }
  if (state.todayCheckInCount == 0) {
    return '지도에서 첫 체크인을 완료하면 ${activePet.name}의 성장치와 알 진행도가 함께 올라갑니다.';
  }
  if (talksLeft > 0) {
    return '${activePet.name}에게 오늘 방문한 장소 이야기를 들려줄 차례입니다.';
  }
  return '오늘 돌봄이 안정적으로 진행 중입니다. 다음 POI에서 알 진행도를 더 모아보세요.';
}

class _ActivePetBadge extends StatelessWidget {
  const _ActivePetBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            '대표',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
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
    final routePoi = _eggRoutePoi(state, template.primaryCategory);
    final routeReward =
        const GrowthEngine().rewardFor(template.primaryCategory);

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
            if (!isReadyToHatch) ...[
              const SizedBox(height: 8),
              _EggRouteHint(
                category: template.primaryCategory,
                reward: routeReward,
                poi: routePoi,
                onOpenMap: state.isBusy
                    ? null
                    : () => controller.setTab(
                          0,
                          mapCategoryFocus: template.primaryCategory,
                        ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EggRouteHint extends StatelessWidget {
  const _EggRouteHint({
    required this.category,
    required this.reward,
    required this.poi,
    required this.onOpenMap,
  });

  final PoiCategory category;
  final CheckInReward reward;
  final Poi? poi;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = poi == null
        ? '${category.label} 장소 보상 알 +${reward.eggProgress}'
        : '${poi!.title} · ${category.label} 보상 알 +${reward.eggProgress}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.route_outlined,
              color: Color(0xFFB45309),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '체크인 보상으로 이 알의 부화 진행도를 더 채울 수 있습니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onOpenMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('지도에서 체크인하기'),
                  ),
                ),
              ],
            ),
          ),
        ],
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

Poi? _eggRoutePoi(MasilPetState state, PoiCategory category) {
  final candidates = state.pois
      .where((poi) => poi.category == category && !state.hasCheckedInToday(poi))
      .toList();
  if (candidates.isEmpty) {
    return null;
  }
  candidates.sort(
    (left, right) => state.currentLocation
        .distanceTo(left.coordinates)
        .compareTo(state.currentLocation.distanceTo(right.coordinates)),
  );
  return candidates.first;
}
