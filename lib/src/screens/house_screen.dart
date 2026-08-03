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
import '../widgets/pet_detail_sheet.dart';
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
    final nextEgg = state.activeEgg;
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
              const _HouseYard(),
              const SizedBox(height: MasilPetSpacing.xl),
              if (justHatched != null) ...[
                _HatchedCard(
                  pet: justHatched,
                  template: controller.templateFor(justHatched.templateId),
                  isActive: justHatched.id == state.activePetId,
                  isBusy: state.isBusy,
                  onWalkTogether: () => controller.selectPet(justHatched.id),
                ),
                const SizedBox(height: MasilPetSpacing.xl),
              ],
              if (nextEgg == null)
                const EmptyStateCard(
                  note: '알이 없어요',
                  title: '부화할 알이 없어요',
                  body: '지도에서 도장을 찍으면 새 알이 수첩에 들어와요.',
                )
              else
                _EggHeroCard(
                  egg: nextEgg,
                  template: controller.templateFor(nextEgg.templateId),
                  isBusy: state.isBusy,
                  onHatch: () =>
                      _hatchAndChooseCompanion(context, controller, nextEgg),
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
                    onHatch: () =>
                        _hatchAndChooseCompanion(context, controller, egg),
                    onSelect: () => controller.selectEgg(egg.id),
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

/// The yard, plus the popover that opens when you tap a friend standing in it.
class _HouseYard extends ConsumerStatefulWidget {
  const _HouseYard();

  static const _wideBreakpoint = 700.0;

  @override
  ConsumerState<_HouseYard> createState() => _HouseYardState();
}

class _HouseYardState extends ConsumerState<_HouseYard> {
  String? _menuPetId;

  @override
  Widget build(BuildContext context) {
    final (
      templates,
      pets,
      eggs,
      activePetId,
      fieldActivity,
      fieldActivityNonce,
      isBusy,
    ) = ref.watch(
      masilPetControllerProvider.select(
        (state) => (
          state.templates,
          state.pets,
          state.eggs,
          state.activePetId,
          state.fieldActivity,
          state.fieldActivityNonce,
          state.isBusy,
        ),
      ),
    );
    final controller = ref.read(masilPetControllerProvider.notifier);
    final care = controller.careForPet(activePetId);

    Pet? menuPet;
    for (final pet in pets) {
      if (pet.id == _menuPetId) {
        menuPet = pet;
        break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            constraints.maxWidth >= _HouseYard._wideBreakpoint ? 400.0 : 320.0;

        return PaperCard.frame(
          child: Stack(
            children: [
              PetPlayField(
                templates: templates,
                pets: pets,
                eggs: eggs,
                activePetId: activePetId,
                activity: fieldActivity,
                activityNonce: fieldActivityNonce,
                height: height,
                scene: PetPlayFieldScene.neighborhoodYard,
                spriteScale: 1.16,
                showVisitors: false,
                // Tapping the same friend again closes the menu.
                onPetTap: (petId) => setState(
                  () => _menuPetId = _menuPetId == petId ? null : petId,
                ),
                onKickBall:
                    isBusy ? null : () => _kickBall(controller, activePetId),
                onFillBowl:
                    isBusy ? null : () => _fillBowl(controller, activePetId),
                bowlFilled: (care?.feedCountToday ?? 0) > 0,
              ),
              if (menuPet != null) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _closeMenu,
                    child: ColoredBox(
                      color: MasilPetPalette.ink.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: _YardPetMenu(
                    pet: menuPet,
                    care: controller.careForPet(menuPet.id),
                    isBusy: isBusy,
                    onClose: _closeMenu,
                    onDetail: () =>
                        _openDetail(controller, menuPet!, activePetId),
                    onFeed: () => _care(() => controller.feedPet(menuPet!.id)),
                    onPlay: () => _care(() => controller.playPet(menuPet!.id)),
                    onClean: () =>
                        _care(() => controller.cleanPet(menuPet!.id)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _closeMenu() => setState(() => _menuPetId = null);

  /// Care runs on the tapped pet, then the yard goes back to being a yard.
  void _care(VoidCallback action) {
    action();
    _closeMenu();
  }

  void _openDetail(
    MasilPetController controller,
    Pet pet,
    String activePetId,
  ) {
    _closeMenu();
    showPetDetailSheet(
      context: context,
      pet: pet,
      template: controller.templateFor(pet.templateId),
      care: controller.careForPet(pet.id),
      isActive: pet.id == activePetId,
      onSetMain: () => controller.selectPet(pet.id),
    );
  }

  void _kickBall(MasilPetController controller, String activePetId) {
    _closeMenu();
    controller.playPet(activePetId);
  }

  void _fillBowl(MasilPetController controller, String activePetId) {
    _closeMenu();
    controller.feedPet(activePetId);
  }
}

/// 마당 팝오버: the tapped pet's name, and what you can do for them.
/// 마당 메뉴 — the design's popover: the tapped friend's name with a close
/// link, a dashed rule, then one row of care actions.
class _YardPetMenu extends StatelessWidget {
  const _YardPetMenu({
    required this.pet,
    required this.care,
    required this.isBusy,
    required this.onClose,
    required this.onDetail,
    required this.onFeed,
    required this.onPlay,
    required this.onClean,
  });

  final Pet pet;
  final PetCareState? care;
  final bool isBusy;
  final VoidCallback onClose;
  final VoidCallback onDetail;
  final VoidCallback onFeed;
  final VoidCallback onPlay;
  final VoidCallback onClean;

  @override
  Widget build(BuildContext context) {
    final feedLeft =
        (dailyFeedCareLimit - (care?.feedCountToday ?? 0)).clamp(0, 9);
    final actions = <Widget>[
      _YardMenuAction(label: '상세보기', onTap: onDetail),
      _YardMenuAction(
        // Only feeding has a daily cap in the care engine, so only it counts.
        label: feedLeft > 0 ? '밥 주기 $feedLeft' : '밥 주기 완료',
        semanticLabel: feedLeft > 0 ? '밥 주기, $feedLeft회 남음' : '오늘 밥은 충분해요',
        onTap: isBusy || feedLeft == 0 ? null : onFeed,
      ),
      _YardMenuAction(label: '놀아주기', onTap: isBusy ? null : onPlay),
      _YardMenuAction(label: '씻기기', onTap: isBusy ? null : onClean),
    ];

    return PopIn(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        decoration: BoxDecoration(
          color: MasilPetPalette.paper,
          border: MasilPetBorders.inkBox,
          borderRadius: MasilPetRadii.bubbleBorder,
          boxShadow: MasilPetShadows.popover,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    pet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MasilPetType.rowTitle.copyWith(fontSize: 15),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      '닫기',
                      style: MasilPetType.caption.copyWith(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            const DashedRule(),
            const SizedBox(height: 9),
            // Equal columns in a single row: the panel stays short, which is
            // the whole point of putting it at the foot of the yard.
            Row(
              children: [
                for (final (index, action) in actions.indexed) ...[
                  Expanded(child: action),
                  if (index != actions.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _YardMenuAction extends StatelessWidget {
  const _YardMenuAction({
    required this.label,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: MasilPetRadii.tightBorder,
          child: Container(
            alignment: Alignment.center,
            // Tight sides so the four labels keep their size on small phones.
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
            decoration: BoxDecoration(
              color: MasilPetPalette.canvas,
              border: Border.all(color: MasilPetPalette.outline),
              borderRadius: MasilPetRadii.tightBorder,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: MasilPetType.bodySmall.copyWith(
                  fontSize: 12.5,
                  height: 1.2,
                  color:
                      enabled ? MasilPetPalette.ink : MasilPetPalette.disabled,
                ),
              ),
            ),
          ),
        ),
      ),
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
          const Eyebrow('지금 품고 있는 알', color: MasilPetPalette.forest),
          const SizedBox(height: 4),
          Text(
            '${regionNameForId(egg.originRegionId)}에서 만났어요',
            style: MasilPetType.caption,
          ),
          const SizedBox(height: 14),
          _EggMeter(
            ratio: egg.progressRatio,
            ready: ready,
            initials: template.initials,
            revealStage: egg.revealStage,
          ),
          const SizedBox(height: MasilPetSpacing.lg),
          Text(
            '${egg.progress} / ${egg.requiredSteps} 걸음',
            style: MasilPetType.heroTitle.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            egg.revealStage.label,
            textAlign: TextAlign.center,
            style:
                MasilPetType.bodySmall.copyWith(fontSize: 13.5, height: 1.65),
          ),
          if (!ready) ...[
            const SizedBox(height: 3),
            Text(
              '$remaining 걸음만 더! 함께 걸으면 다음 모습을 볼 수 있어요.',
              textAlign: TextAlign.center,
              style: MasilPetType.caption,
            ),
          ],
          if (egg.revealStage == EggRevealStage.silhouette) ...[
            const SizedBox(height: 8),
            HandNote('${template.primaryCategory.label}의 기운이 느껴져요'),
          ],
          if (egg.revealStage == EggRevealStage.personalityHint) ...[
            const SizedBox(height: 8),
            Text(
              template.basePersonality,
              textAlign: TextAlign.center,
              style: MasilPetType.caption.copyWith(
                color: MasilPetPalette.forest,
                height: 1.5,
              ),
            ),
          ],
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
    required this.revealStage,
  });

  final double ratio;
  final bool ready;
  final String initials;
  final EggRevealStage revealStage;

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
                switch (revealStage) {
                  EggRevealStage.quiet => '?',
                  EggRevealStage.stirring => '·',
                  EggRevealStage.silhouette => '◌',
                  EggRevealStage.personalityHint =>
                    initials.isEmpty ? '?' : initials.substring(0, 1),
                  EggRevealStage.ready => initials,
                },
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
    required this.onSelect,
  });

  final Egg egg;
  final PetTemplate template;
  final bool isBusy;
  final VoidCallback onHatch;
  final VoidCallback onSelect;

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
                  _eggDisplayName(egg, template),
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
            InkTag(
              label: '이 알 품기',
              onPressed: isBusy ? null : onSelect,
            ),
        ],
      ),
    );
  }
}

String _eggDisplayName(Egg egg, PetTemplate template) {
  return switch (egg.revealStage) {
    EggRevealStage.quiet => '조용한 알',
    EggRevealStage.stirring => '움직이기 시작한 알',
    EggRevealStage.silhouette => '실루엣이 보이는 알',
    EggRevealStage.personalityHint => '${template.primaryCategory.label} 기운의 알',
    EggRevealStage.ready => '${template.name}의 알',
  };
}

/// The celebration card shown right after a shell cracks open.
class _HatchedCard extends StatelessWidget {
  const _HatchedCard({
    required this.pet,
    required this.template,
    required this.isActive,
    required this.isBusy,
    required this.onWalkTogether,
  });

  final Pet pet;
  final PetTemplate template;
  final bool isActive;
  final bool isBusy;
  final VoidCallback onWalkTogether;

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
            Text(
              pet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MasilPetType.heroTitle,
            ),
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
            const SizedBox(height: MasilPetSpacing.lg),
            if (isActive)
              const InkTag(label: '지금 함께 걷는 친구')
            else ...[
              Text(
                '기존 친구는 그대로 곁에 있어요. 새 친구와 바로 걸을지는 지금 정할 수 있어요.',
                textAlign: TextAlign.center,
                style: MasilPetType.caption.copyWith(height: 1.5),
              ),
              const SizedBox(height: MasilPetSpacing.md),
              PaperButton.stamp(
                label: '${petCallName(pet.name)}와 함께 걷기',
                onPressed: isBusy ? null : onWalkTogether,
                maxWidth: 300,
                fontSize: 15,
              ),
            ],
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
    final nextEgg = state.activeEgg;
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

Future<void> _hatchAndChooseCompanion(
  BuildContext context,
  MasilPetController controller,
  Egg egg,
) async {
  final outcome = await controller.hatchEgg(egg.id);
  if (outcome == null || !context.mounted) {
    return;
  }
  final pet = controller.petForId(outcome.petId);
  if (pet == null) {
    return;
  }
  final template = controller.templateFor(pet.templateId);
  final walkTogether = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Eyebrow(
              outcome.reunion ? '소중한 인연이 돌아왔어요' : '새 친구가 태어났어요',
              color: MasilPetPalette.forest,
            ),
            const SizedBox(height: MasilPetSpacing.md),
            PixelSprite(
              asset: PetAssets.emotion(template.assetKey, 'excited'),
              size: 132,
              semanticLabel: pet.name,
            ),
            const SizedBox(height: MasilPetSpacing.sm),
            Text(
              pet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MasilPetType.heroTitle,
            ),
            const SizedBox(height: 8),
            Text(
              outcome.reunion
                  ? '다시 만난 기억이 유대로 이어졌어요. 누구와 걸을지는 직접 정할 수 있어요.'
                  : '알에서 쌓은 걸음과 장소의 기억을 간직하고 태어났어요.',
              textAlign: TextAlign.center,
              style: MasilPetType.prose,
            ),
            const SizedBox(height: MasilPetSpacing.lg),
            PaperButton.stamp(
              label: '${petCallName(pet.name)}와 함께 걷기',
              onPressed: () => Navigator.of(sheetContext).pop(true),
              fontSize: 16,
            ),
            const SizedBox(height: MasilPetSpacing.sm),
            PaperButton.ghost(
              label: '마당에서 쉬게 하기',
              onPressed: () => Navigator.of(sheetContext).pop(false),
              fontSize: 15,
            ),
          ],
        ),
      ),
    ),
  );
  if (walkTogether == true) {
    await controller.selectPet(pet.id);
  }
}
