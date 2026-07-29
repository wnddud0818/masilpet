import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../pet_assets.dart';
import '../seed_data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/metric_grid.dart';
import '../widgets/paper_kit.dart';
import '../widgets/paper_shell.dart';
import '../widgets/pet_play_field.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/section_header.dart';
import '../widgets/status_banner.dart';

/// 하우스: the yard where pets roam, the egg that grows with your steps, and
/// today's care checklist.
class HouseScreen extends ConsumerWidget {
  const HouseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);
    final nextEgg = state.nextEgg;
    final otherEggs = state.eggs.where((egg) => egg.id != nextEgg?.id).toList();
    final justHatched = _recentlyHatchedPet(state);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: kPaperBodyPadding,
          sliver: ResponsiveSliverList(
            children: [
              const StatusBanner(),
              const SizedBox(height: MasilPetSpacing.xl),
              const SectionEyebrow('마당 · 친구를 누르고, 공과 밥그릇도 건드려보세요'),
              _HouseYard(
                state: state,
                onPetTap: controller.selectPet,
                onKickBall: state.isBusy ? null : controller.playActivePet,
                onFillBowl: state.isBusy ? null : controller.feedActivePet,
              ),
              const SizedBox(height: MasilPetSpacing.xl),
              if (justHatched != null) ...[
                _HatchedCard(
                  pet: justHatched,
                  template: controller.templateFor(justHatched.templateId),
                ),
                const SizedBox(height: MasilPetSpacing.xl),
              ],
              if (nextEgg == null)
                const EmptyStateCard(
                  note: '알이 없어요',
                  title: '부화할 알이 없습니다',
                  body: '지도에서 도장을 찍으면 새 알이 수첩에 들어옵니다.',
                )
              else
                _EggHeroCard(
                  egg: nextEgg,
                  template: controller.templateFor(nextEgg.templateId),
                  isBusy: state.isBusy,
                  onHatch: () => controller.hatchEgg(nextEgg.id),
                  onCollectSteps: () => controller.setTab(
                    0,
                    mapCategoryFocus: controller
                        .templateFor(nextEgg.templateId)
                        .primaryCategory,
                  ),
                ),
              if (otherEggs.isNotEmpty) ...[
                const SizedBox(height: MasilPetSpacing.xl),
                SectionHeader(title: '품고 있는 알', detail: '${otherEggs.length}개'),
                for (final egg in otherEggs) ...[
                  _EggRow(
                    egg: egg,
                    template: controller.templateFor(egg.templateId),
                    isBusy: state.isBusy,
                    onHatch: () => controller.hatchEgg(egg.id),
                  ),
                  const SizedBox(height: MasilPetSpacing.sm),
                ],
              ],
              const SizedBox(height: MasilPetSpacing.xl),
              _CareRoutineCard(state: state),
              const SizedBox(height: MasilPetSpacing.xl),
              _HouseLedger(state: state),
              const SizedBox(height: MasilPetSpacing.xl),
              _NextOutingNote(
                state: state,
                onOpenMap: (category) => controller.setTab(
                  0,
                  mapCategoryFocus: category,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HouseYard extends StatelessWidget {
  const _HouseYard({
    required this.state,
    required this.onPetTap,
    required this.onKickBall,
    required this.onFillBowl,
  });

  static const _wideBreakpoint = 700.0;

  final MasilPetState state;
  final ValueChanged<String> onPetTap;
  final VoidCallback? onKickBall;
  final VoidCallback? onFillBowl;

  @override
  Widget build(BuildContext context) {
    final care = state.activePetCare;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth >= _wideBreakpoint ? 400.0 : 320.0;

        return PaperCard.frame(
          child: PetPlayField(
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
            onPetTap: onPetTap,
            onKickBall: onKickBall,
            onFillBowl: onFillBowl,
            bowlFilled: (care?.feedCountToday ?? 0) > 0,
          ),
        );
      },
    );
  }
}

/// The featured egg: a step meter drawn as a ring around the shell itself.
class _EggHeroCard extends StatelessWidget {
  const _EggHeroCard({
    required this.egg,
    required this.template,
    required this.isBusy,
    required this.onHatch,
    required this.onCollectSteps,
  });

  final Egg egg;
  final PetTemplate template;
  final bool isBusy;
  final VoidCallback onHatch;
  final VoidCallback onCollectSteps;

  @override
  Widget build(BuildContext context) {
    final ready = egg.status == EggStatus.hatchable;
    final remaining =
        (egg.requiredSteps - egg.progress).clamp(0, egg.requiredSteps);

    return PaperCard.stamped(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Eyebrow('${regionNameForId(egg.originRegionId)}에서 데려온 알'),
          const SizedBox(height: 14),
          _EggMeter(
            ratio: egg.progressRatio,
            ready: ready,
            initials: template.initials,
          ),
          const SizedBox(height: MasilPetSpacing.lg),
          Text(
            '${egg.progress} / ${egg.requiredSteps} 걸음',
            style: MasilPetType.heroTitle.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            ready
                ? '준비됐어요. 알이 계속 흔들리고 있어요!'
                : '도장 한 번에 걸음이 쌓여요. $remaining 걸음만 더!',
            textAlign: TextAlign.center,
            style:
                MasilPetType.bodySmall.copyWith(fontSize: 13.5, height: 1.65),
          ),
          const SizedBox(height: 18),
          if (ready)
            PaperButton.stamp(
              label: '부화시키기',
              onPressed: isBusy ? null : onHatch,
              maxWidth: 300,
              fontSize: 17,
            )
          else
            PaperButton.ghost(
              label: '지도에서 걸음 모으기',
              onPressed: isBusy ? null : onCollectSteps,
              maxWidth: 300,
              padding: const EdgeInsets.symmetric(
                horizontal: MasilPetSpacing.lg,
                vertical: 15,
              ),
            ),
        ],
      ),
    );
  }
}

/// `conic-gradient` ring + the egg shell, shaking once it is ready.
class _EggMeter extends StatelessWidget {
  const _EggMeter({
    required this.ratio,
    required this.ready,
    required this.initials,
  });

  final double ratio;
  final bool ready;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final sweep = ratio.clamp(0.0, 1.0);

    return SizedBox(
      width: 174,
      height: 174,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                startAngle: -math.pi / 2,
                endAngle: math.pi * 1.5,
                colors: const [
                  MasilPetPalette.forest,
                  MasilPetPalette.forest,
                  MasilPetPalette.track,
                  MasilPetPalette.track,
                ],
                stops: [0, sweep, sweep, 1],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Container(
            margin: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MasilPetPalette.paper,
              border: Border.all(color: MasilPetPalette.track),
            ),
          ),
          ShakeLoop(
            active: ready,
            child: Container(
              width: 112,
              height: 112,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF3E6C8), Color(0xFFE2CFA4)],
                ),
                border: Border.all(color: const Color(0xFFC2A97B), width: 1.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.elliptical(56, 56),
                  topRight: Radius.elliptical(56, 56),
                  bottomLeft: Radius.elliptical(52, 52),
                  bottomRight: Radius.elliptical(52, 52),
                ),
              ),
              child: HandNote(
                ready ? initials : '?',
                fontSize: 30,
                color: const Color(0xFFB09A6E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EggRow extends StatelessWidget {
  const _EggRow({
    required this.egg,
    required this.template,
    required this.isBusy,
    required this.onHatch,
  });

  final Egg egg;
  final PetTemplate template;
  final bool isBusy;
  final VoidCallback onHatch;

  @override
  Widget build(BuildContext context) {
    final ready = egg.status == EggStatus.hatchable;
    final remaining =
        (egg.requiredSteps - egg.progress).clamp(0, egg.requiredSteps);

    return PaperCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${template.name}의 알',
                  style: MasilPetType.rowTitle,
                ),
                const SizedBox(height: 3),
                Text(
                  ready ? '부화 준비 완료' : '$remaining 걸음 남음',
                  style: MasilPetType.caption,
                ),
                const SizedBox(height: 8),
                PaperTrack(
                  ratio: egg.progressRatio,
                  color: MasilPetPalette.forest,
                  height: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          if (ready)
            InkTag(
              label: '부화',
              onPressed: isBusy ? null : onHatch,
            )
          else
            Text(
              '$remaining걸음\n더 걸어요',
              textAlign: TextAlign.right,
              style: MasilPetType.caption.copyWith(
                fontSize: 11.5,
                height: 1.35,
                color: MasilPetPalette.faintWarm,
              ),
            ),
        ],
      ),
    );
  }
}

/// The celebration card shown right after a shell cracks open.
class _HatchedCard extends StatelessWidget {
  const _HatchedCard({required this.pet, required this.template});

  final Pet pet;
  final PetTemplate template;

  @override
  Widget build(BuildContext context) {
    return RiseIn(
      duration: MasilPetMotion.stamp,
      child: PaperCard.stamped(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            const Eyebrow('새 친구가 태어났어요', color: MasilPetPalette.forest),
            const SizedBox(height: 10),
            BobbingSprite(
              period: const Duration(milliseconds: 2400),
              child: PixelSprite(
                asset: PetAssets.emotion(template.assetKey, 'excited'),
                size: 158,
                semanticLabel: pet.name,
              ),
            ),
            const SizedBox(height: MasilPetSpacing.sm),
            Text(pet.name, style: MasilPetType.heroTitle),
            const SizedBox(height: 4),
            Text(
              '${regionNameForId(pet.originRegionId)} · ${template.rarityLabel}',
              style: MasilPetType.bodySmall.copyWith(fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                template.basePersonality,
                textAlign: TextAlign.center,
                style: MasilPetType.prose.copyWith(fontSize: 15.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareRoutineCard extends StatelessWidget {
  const _CareRoutineCard({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context) {
    final routine = state.dailyCareRoutine;
    final petName = state.activePet?.name ?? '마실펫';
    final rows = [
      ('밥 주기', routine.fed, '돌봄'),
      ('놀아주기', routine.played, '돌봄'),
      ('씻기기', routine.cleaned, '돌봄'),
      ('${petCallName(petName)}와 대화하기', routine.talked, '교감'),
      ('한 곳 체크인하기', routine.checkedIn, '산책'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionEyebrow('오늘의 돌봄'),
        PaperCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              for (final (label, done, tag) in rows)
                RoutineRow(label: label, done: done, tag: tag),
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        '완료',
                        style: MasilPetType.bodySmall.copyWith(
                          fontSize: 13.5,
                          height: 1.2,
                          color: MasilPetPalette.inkSoft,
                        ),
                      ),
                    ),
                    Text(
                      '${routine.completedCount} / ${rows.length}',
                      style: MasilPetType.rowTitle.copyWith(
                        fontSize: 16,
                        color: MasilPetPalette.stamp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// House totals plus the dex meter — the ledger page of the notebook.
class _HouseLedger extends StatelessWidget {
  const _HouseLedger({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context) {
    final nextEgg = state.nextEgg;
    final remainingSteps = nextEgg == null
        ? null
        : (nextEgg.requiredSteps - nextEgg.progress)
            .clamp(0, nextEgg.requiredSteps);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionEyebrow('하우스 현황'),
        MetricGrid(
          items: [
            MetricGridItem(
              label: '보유 펫',
              value: '${state.pets.length}/${state.templates.length}',
            ),
            MetricGridItem(
              label: '부화 가능',
              value: '${state.hatchableEggCount}개',
            ),
            MetricGridItem(
              label: '남은 걸음',
              value: remainingSteps == null ? '-' : '$remainingSteps',
            ),
          ],
        ),
        const SizedBox(height: MasilPetSpacing.md),
        PaperCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      '도감 수집률',
                      style: MasilPetType.bodySmall.copyWith(
                        fontSize: 13.5,
                        height: 1.2,
                        color: MasilPetPalette.inkSoft,
                      ),
                    ),
                  ),
                  Text(
                    '${(state.dexCompletionRatio * 100).round()}%',
                    style: MasilPetType.metaMono,
                  ),
                ],
              ),
              const SizedBox(height: MasilPetSpacing.xs),
              PaperTrack(
                ratio: state.dexCompletionRatio,
                color: MasilPetPalette.forest,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Where to walk next, written as a margin note rather than a call to action.
class _NextOutingNote extends StatelessWidget {
  const _NextOutingNote({required this.state, required this.onOpenMap});

  final MasilPetState state;
  final ValueChanged<PoiCategory?> onOpenMap;

  @override
  Widget build(BuildContext context) {
    final recommended = state.nextRecommendedPoi;
    final distance = recommended == null || !state.hasFreshVerifiedLocation
        ? null
        : state.currentLocation.distanceTo(recommended.coordinates).round();

    return DashedBox(
      fill: MasilPetPalette.subtle,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HandNote('다음 외출'),
          const SizedBox(height: MasilPetSpacing.sm),
          Text(
            recommended == null
                ? '지도에서 위치를 확인하면 다음 도장 후보를 골라드려요.'
                : '${recommended.title} · ${recommended.category.label}'
                    '${distance == null ? '' : ' · ${distance}m'}',
            style: MasilPetType.prose.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 14),
          PaperButton.ghost(
            label: '지도에서 도장 찍기',
            onPressed:
                state.isBusy ? null : () => onOpenMap(recommended?.category),
            expand: false,
            fontSize: 14,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          ),
        ],
      ),
    );
  }
}

/// A pet that hatched in the last few minutes, so the celebration card only
/// shows while the moment is fresh.
Pet? _recentlyHatchedPet(MasilPetState state) {
  Pet? newest;
  for (final pet in state.pets) {
    if (newest == null || pet.hatchedAt.isAfter(newest.hatchedAt)) {
      newest = pet;
    }
  }
  if (newest == null) {
    return null;
  }
  final age = DateTime.now().difference(newest.hatchedAt);
  return age.inMinutes < 3 && !age.isNegative ? newest : null;
}
