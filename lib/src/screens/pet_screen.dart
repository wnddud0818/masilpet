import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../pet_assets.dart';
import '../seed_data.dart';
import '../services.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/paper_kit.dart';
import '../widgets/paper_shell.dart';
import '../widgets/pet_detail_sheet.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/section_header.dart';

/// 마실펫: the stage where the companion stands, what you did for them today,
/// and the roster of everyone living in the notebook.
class PetScreen extends ConsumerWidget {
  const PetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);
    final pet = state.activePet;
    final care = state.activePetCare;
    final talksLeft = _talksLeftToday(state);
    final personality = pet == null ? null : controller.personalityFor(pet);
    final favoriteFood = pet == null ? null : controller.favoriteFoodFor(pet);
    final dislikedFood = pet == null ? null : controller.dislikedFoodFor(pet);
    final preferredTouch =
        pet == null ? null : controller.preferredTouchFor(pet);
    final need = pet == null ? null : controller.currentNeedFor(pet);

    return CustomScrollView(
      // The shell owns this page's scroller so re-tapping 마실펫 returns to
      // the stage.
      primary: true,
      slivers: [
        SliverPadding(
          padding: kPaperBodyPadding,
          sliver: ResponsiveSliverList(
            children: [
              if (pet == null)
                EmptyStateCard(
                  note: '아직 친구가 없어요',
                  title: '함께 다니는 마실펫이 없어요',
                  body: '하우스에서 알을 부화하면 이 자리에 친구가 서요.',
                  actionLabel: '하우스로 가기',
                  onAction: () => controller.setTab(2),
                )
              else ...[
                _PetStage(
                  state: state,
                  pet: pet,
                  template: controller.templateFor(pet.templateId),
                  care: care,
                  talksLeft: talksLeft,
                  onTalk: state.isBusy ? null : controller.talkWithActivePet,
                  onTouch: state.isBusy ? null : controller.touchActivePet,
                ),
                const SizedBox(height: 18),
                _PetIdentityRow(
                  pet: pet,
                  template: controller.templateFor(pet.templateId),
                ),
                const SizedBox(height: 18),
                _PetLifeCard(
                  pet: pet,
                  care: care,
                  personality: personality!,
                  favoriteFood: favoriteFood!,
                  dislikedFood: dislikedFood!,
                  preferredTouch: preferredTouch!,
                  need: need!,
                  onNeedAction: () => _handleNeedAction(
                    context,
                    controller,
                    pet,
                    care,
                    need,
                  ),
                ),
                const SizedBox(height: 18),
                _WalkConnectionCard(
                  care: care,
                  isSupported: state.stepTrackingSupported,
                  isActive: state.stepTrackingActive,
                  waitingSteps: state.deviceStepsWaiting,
                  isBusy: state.isBusy,
                  onConnect: controller.startStepTracking,
                  onFlush: controller.flushDeviceSteps,
                  onOpenMap: () => controller.setTab(0),
                ),
                const SizedBox(height: 18),
                _CareActions(
                  care: care,
                  isBusy: state.isBusy,
                  onFeed: () => _showFoodPicker(context, controller, pet),
                  onPlay: controller.playActivePet,
                  onClean: controller.cleanActivePet,
                  onSleep: state.isBusy ? null : controller.sleepActivePet,
                  onWasteClean: controller.cleanActivePetWaste,
                ),
                const SizedBox(height: 18),
                _CarePointsNote(
                  state: state,
                  onClaim: controller.claimDailyCareReward,
                  onOpenHouse: () => controller.setTab(2),
                ),
                const SizedBox(height: 18),
                _PetVitalsCard(pet: pet, care: care),
                const SizedBox(height: 18),
                _GrowthGoalNote(
                  pet: pet,
                  onOpenMap: () => controller.setTab(0),
                ),
                if (care != null && care.memories.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _PetMemoryBook(memories: care.memories, petName: pet.name),
                ] else if (_walkMemory(state, pet.id) case final memory?) ...[
                  const SizedBox(height: 18),
                  _MemoryNote(memory: memory, petName: pet.name),
                ],
              ],
              const SizedBox(height: MasilPetSpacing.xl),
              _RosterSection(state: state),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _showFoodPicker(
  BuildContext context,
  MasilPetController controller,
  Pet pet,
) async {
  final favorite = controller.favoriteFoodFor(pet);
  final disliked = controller.dislikedFoodFor(pet);
  final selected = await showModalBottomSheet<PetFood>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            Text(
              '${pet.name}에게 무엇을 줄까요?',
              style: MasilPetType.sectionTitle,
            ),
            const SizedBox(height: 6),
            Text(
              '좋아하는 음식은 더 행복하게 하지만, 같은 음식만 계속 먹으면 배가 더부룩할 수 있어요.',
              style: MasilPetType.bodySmall,
            ),
            const SizedBox(height: 14),
            for (final food in PetFood.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(food.label),
                subtitle: Text(
                  food == favorite
                      ? '가장 좋아해요'
                      : food == disliked
                          ? '조금 망설여요'
                          : '오늘의 식사 후보',
                ),
                trailing: food == favorite
                    ? const MonoChip('좋아함')
                    : food == disliked
                        ? const MonoChip('낯설어요')
                        : null,
                onTap: () => Navigator.of(context).pop(food),
              ),
          ],
        ),
      );
    },
  );
  if (selected != null) {
    await controller.feedPet(pet.id, food: selected);
  }
}

void _handleNeedAction(
  BuildContext context,
  MasilPetController controller,
  Pet pet,
  PetCareState? care,
  PetNeed need,
) {
  switch (need) {
    case PetNeed.hungry:
      _showFoodPicker(context, controller, pet);
      return;
    case PetNeed.dirty:
      controller.cleanActivePet();
      return;
    case PetNeed.tired:
    case PetNeed.sleeping:
      controller.sleepActivePet();
      return;
    case PetNeed.bored:
      controller.playActivePet();
      return;
    case PetNeed.potty:
      controller.cleanActivePetWaste();
      return;
    case PetNeed.sick:
      if ((care?.wasteCount ?? 0) > 0) {
        controller.cleanActivePetWaste();
      } else {
        controller.sleepActivePet();
      }
      return;
    case PetNeed.wantsWalk:
      controller.setTab(0);
      return;
    case PetNeed.content:
      controller.touchActivePet(PetTouch.head);
      return;
  }
}

/// The stage: sky over grass, one pet, one line of speech.
class _PetStage extends StatelessWidget {
  const _PetStage({
    required this.state,
    required this.pet,
    required this.template,
    required this.care,
    required this.talksLeft,
    required this.onTalk,
    required this.onTouch,
  });

  final MasilPetState state;
  final Pet pet;
  final PetTemplate template;
  final PetCareState? care;
  final int talksLeft;
  final VoidCallback? onTalk;
  final ValueChanged<PetTouch>? onTouch;

  @override
  Widget build(BuildContext context) {
    final emotion = _stageEmotion(state.fieldActivity, care);
    final excited = emotion == 'excited';
    final message = _friendlyPetMessage(state, pet);
    final onTouch = this.onTouch;
    // Touching a friend should answer in the hand, not only on screen.
    void touch(PetTouch kind) {
      MasilPetHaptics.touch();
      onTouch!(kind);
    }

    return PaperCard.frame(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE7EDE2),
              Color(0xFFE7EDE2),
              Color(0xFFDED0B4),
              Color(0xFFD9C9A9),
            ],
            stops: [0, 0.62, 0.62, 1],
          ),
        ),
        child: Stack(
          children: [
            // The low sun, at 82% across and 26% down the sky band.
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const skyBand = 0.62;
                  return Stack(
                    children: [
                      Positioned(
                        left: constraints.maxWidth * 0.82 - _stageSunRadius,
                        top: constraints.maxHeight * skyBand * 0.26 -
                            _stageSunRadius,
                        child: const _StageSun(),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
              // The stack hands non-positioned children loose constraints, so
              // without this the column shrink-wraps and drifts to the left
              // edge on wide windows.
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Semantics(
                      button: onTalk != null,
                      label: '${pet.name} 쓰다듬기',
                      child: GestureDetector(
                        onTap:
                            onTouch == null ? null : () => touch(PetTouch.head),
                        onDoubleTap: onTouch == null
                            ? null
                            : () => touch(PetTouch.cheek),
                        onLongPress:
                            onTouch == null ? null : () => touch(PetTouch.hug),
                        onHorizontalDragEnd: onTouch == null
                            ? null
                            : (details) => touch(
                                  details.primaryVelocity != null &&
                                          details.primaryVelocity! < 0
                                      ? PetTouch.paw
                                      : PetTouch.tail,
                                ),
                        child: SizedBox(
                          height: 186,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              const Positioned(
                                bottom: 8,
                                child: GroundShadow(width: 120, height: 15),
                              ),
                              BobbingSprite(
                                period: excited
                                    ? MasilPetMotion.bobExcited
                                    : const Duration(milliseconds: 3200),
                                child: PixelSprite(
                                  asset: PetAssets.emotion(
                                    template.assetKey,
                                    emotion,
                                  ),
                                  size: 180,
                                  semanticLabel: pet.name,
                                  fallback: Center(
                                    child: Text(
                                      template.initials,
                                      style: MasilPetType.display.copyWith(
                                        color: Color(template.colorValue),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      label: '${pet.name}의 말, $message',
                      child: ExcludeSemantics(
                        child: SpeechBubble(
                          text: message,
                          maxWidth: 400,
                          shadows: MasilPetShadows.bubbleOnScene,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // One pill, always labelled with what is left today. Tapping
                    // it out says so out loud instead of going grey.
                    _PetPillButton(
                      label: '쓰다듬기 · 오늘 $talksLeft번 남음',
                      onTap: onTalk == null
                          ? null
                          : () {
                              if (talksLeft > 0) {
                                onTalk!();
                                return;
                              }
                              ScaffoldMessenger.of(context)
                                ..clearSnackBars()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('오늘 대화는 다 했어. 내일 또 얘기하자!'),
                                  ),
                                );
                            },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `radial-gradient(... 0 46px, transparent 47px)`
const _stageSunRadius = 46.0;

class _StageSun extends StatelessWidget {
  const _StageSun();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: _stageSunRadius * 2,
        height: _stageSunRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MasilPetPalette.sun.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _PetPillButton extends StatelessWidget {
  const _PetPillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: onTap,
        borderRadius: MasilPetRadii.pillBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(
              color: enabled ? MasilPetPalette.ink : MasilPetPalette.outline,
            ),
            borderRadius: MasilPetRadii.pillBorder,
          ),
          child: Text(
            label,
            style: MasilPetType.bodySmall.copyWith(
              fontSize: 12.5,
              height: 1.2,
              color: enabled ? MasilPetPalette.ink : MasilPetPalette.disabled,
            ),
          ),
        ),
      ),
    );
  }
}

class _PetIdentityRow extends StatelessWidget {
  const _PetIdentityRow({required this.pet, required this.template});

  final Pet pet;
  final PetTemplate template;

  @override
  Widget build(BuildContext context) {
    final days = petDaysTogether(pet);

    return PaperCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MasilPetType.rowTitle.copyWith(fontSize: 19),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${shortRegionLabelForId(template.regionId)}',
                      style: MasilPetType.caption.copyWith(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Lv.${pet.level} · ${pet.stage.label} 단계 · '
                  '${pet.bondLevel.label} · $days일째 동행',
                  style: MasilPetType.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          RarityStamp(template.rarityLabel),
        ],
      ),
    );
  }
}

class _PetLifeCard extends StatelessWidget {
  const _PetLifeCard({
    required this.pet,
    required this.care,
    required this.personality,
    required this.favoriteFood,
    required this.dislikedFood,
    required this.preferredTouch,
    required this.need,
    required this.onNeedAction,
  });

  final Pet pet;
  final PetCareState? care;
  final PetPersonality personality;
  final PetFood favoriteFood;
  final PetFood dislikedFood;
  final PetTouch preferredTouch;
  final PetNeed need;
  final VoidCallback onNeedAction;

  @override
  Widget build(BuildContext context) {
    final care = this.care;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionEyebrow('지금의 마음'),
        PaperCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          need.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MasilPetType.rowTitle.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          care?.conditionLabel ?? '상태를 살피고 있어요',
                          style: MasilPetType.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  PaperButton.ghost(
                    label: need.actionLabel,
                    onPressed: onNeedAction,
                    expand: false,
                    fontSize: 13,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  MonoChip('${personality.label} 성격'),
                  MonoChip('좋아함 · ${favoriteFood.shortLabel}'),
                  MonoChip('낯섦 · ${dislikedFood.shortLabel}'),
                  MonoChip('교감 · ${preferredTouch.label}'),
                  if ((care?.wasteCount ?? 0) > 0)
                    MonoChip('치울 것 ${care!.wasteCount}개'),
                  if (care?.isSleeping ?? false) const MonoChip('꿈꾸는 중'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                personality.description,
                style: MasilPetType.prose.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '펫을 한 번 누르면 머리, 두 번 누르면 볼, 길게 누르면 꼭 안아줄 수 있어요.',
                style: MasilPetType.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WalkConnectionCard extends StatelessWidget {
  const _WalkConnectionCard({
    required this.care,
    required this.isSupported,
    required this.isActive,
    required this.waitingSteps,
    required this.isBusy,
    required this.onConnect,
    required this.onFlush,
    required this.onOpenMap,
  });

  final PetCareState? care;
  final bool isSupported;
  final bool isActive;
  final int waitingSteps;
  final bool isBusy;
  final VoidCallback onConnect;
  final VoidCallback onFlush;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final tracked = care?.walkStepsToday ?? 0;
    return DashedBox(
      fill: MasilPetPalette.subtle,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HandNote('오늘의 산책'),
                const SizedBox(height: 5),
                Text(
                  '$tracked걸음 함께 걸었어요'
                  '${waitingSteps > 0 ? ' · $waitingSteps걸음 반영 대기' : ''}',
                  style: MasilPetType.rowTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  isSupported
                      ? isActive
                          ? '센서가 걸음을 모으고 있어요. 많이 걸으면 배고프고 졸릴 수 있어요.'
                          : '동작 및 피트니스 권한을 허용하면 실제 걸음을 기록해요.'
                      : '이 기기에서는 체크인으로 산책 추억을 남길 수 있어요.',
                  style: MasilPetType.bodySmall.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PaperButton.ghost(
            label: !isSupported
                ? '지도 열기'
                : !isActive
                    ? '걸음 연결'
                    : waitingSteps > 0
                        ? '지금 반영'
                        : '연결됨',
            onPressed: isBusy
                ? null
                : !isSupported
                    ? onOpenMap
                    : !isActive
                        ? onConnect
                        : waitingSteps > 0
                            ? onFlush
                            : null,
            expand: false,
            fontSize: 13,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          ),
        ],
      ),
    );
  }
}

/// 오늘 해준 것 — three flat paper keys.
class _CareActions extends StatelessWidget {
  const _CareActions({
    required this.care,
    required this.isBusy,
    required this.onFeed,
    required this.onPlay,
    required this.onClean,
    required this.onSleep,
    required this.onWasteClean,
  });

  final PetCareState? care;
  final bool isBusy;
  final VoidCallback onFeed;
  final VoidCallback onPlay;
  final VoidCallback onClean;
  final VoidCallback? onSleep;
  final VoidCallback onWasteClean;

  @override
  Widget build(BuildContext context) {
    final feedLeft =
        (dailyFeedCareLimit - (care?.feedCountToday ?? 0)).clamp(0, 9);
    final actions = <_CareActionData>[
      _CareActionData(
        label: '밥 주기',
        detail: feedLeft > 0 ? '$feedLeft회 남음' : '오늘 충분해요',
        onTap: isBusy || feedLeft == 0 ? null : onFeed,
      ),
      _CareActionData(
        label: '놀아주기',
        detail: '오늘 ${care?.playCountToday ?? 0}회',
        onTap: isBusy ? null : onPlay,
      ),
      _CareActionData(
        label: '씻기기',
        detail: '오늘 ${care?.cleanCountToday ?? 0}회',
        onTap: isBusy ? null : onClean,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionEyebrow(
          '오늘 해준 것',
          trailing: MonoButton(
            label: care?.isSleeping == true ? '살며시 깨우기' : '포근하게 재우기',
            onPressed: onSleep,
          ),
        ),
        Row(
          children: [
            for (final (index, action) in actions.indexed) ...[
              Expanded(child: _CareActionButton(data: action)),
              if (index != actions.length - 1) const SizedBox(width: 9),
            ],
          ],
        ),
        if ((care?.wasteCount ?? 0) > 0) ...[
          const SizedBox(height: 9),
          PaperButton.ghost(
            label: '주변 치워주기 · ${care!.wasteCount}개',
            onPressed: isBusy ? null : onWasteClean,
            fontSize: 14,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          ),
        ],
      ],
    );
  }
}

class _CareActionData {
  const _CareActionData({
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final String label;
  final String detail;
  final VoidCallback? onTap;
}

class _CareActionButton extends StatelessWidget {
  const _CareActionButton({required this.data});

  final _CareActionData data;

  @override
  Widget build(BuildContext context) {
    final enabled = data.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '${data.label}, ${data.detail}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: data.onTap,
          borderRadius: MasilPetRadii.cardBorder,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            decoration: BoxDecoration(
              color: MasilPetPalette.paper,
              border: Border.all(color: MasilPetPalette.outline),
              borderRadius: MasilPetRadii.cardBorder,
              boxShadow: MasilPetShadows.card,
            ),
            child: Column(
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MasilPetType.rowTitle.copyWith(
                    fontSize: 15,
                    color: enabled
                        ? MasilPetPalette.ink
                        : MasilPetPalette.disabled,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MasilPetType.microMono.copyWith(letterSpacing: 0.76),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The care-point ledger and today's routine bonus.
class _CarePointsNote extends StatelessWidget {
  const _CarePointsNote({
    required this.state,
    required this.onClaim,
    required this.onOpenHouse,
  });

  final MasilPetState state;
  final VoidCallback onClaim;
  final VoidCallback onOpenHouse;

  @override
  Widget build(BuildContext context) {
    final routine = state.dailyCareRoutine;
    final canClaim = state.canClaimDailyCareReward;
    final claimed = state.hasClaimedDailyCareRewardToday;

    return DashedBox(
      fill: MasilPetPalette.subtle,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: HandNote('돌봄 포인트')),
              MonoChip('${state.carePoints} P'),
            ],
          ),
          const SizedBox(height: MasilPetSpacing.sm),
          Text(
            claimed
                ? '오늘의 돌봄 보상을 받았어요. 내일 또 만나요.'
                : canClaim
                    ? '오늘 돌봄을 ${routine.completedCount}가지 했어요. '
                        '보상 $dailyCareRewardPoints P를 받을 수 있어요.'
                    : '돌봄을 ${routine.remainingCount}가지 더 하면 '
                        '$dailyCareRewardPoints P를 받아요.',
            style: MasilPetType.prose.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 14),
          if (canClaim)
            PaperButton.stamp(
              label: '돌봄 보상 받기',
              onPressed: state.isBusy ? null : onClaim,
              expand: false,
              fontSize: 15,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            )
          else
            PaperButton.ghost(
              label: '오늘의 돌봄 확인',
              onPressed: onOpenHouse,
              expand: false,
              fontSize: 14,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            ),
        ],
      ),
    );
  }
}

/// Satiety, cleanliness, vitality — plus how far the next stage is.
class _PetVitalsCard extends StatelessWidget {
  const _PetVitalsCard({required this.pet, required this.care});

  final Pet pet;
  final PetCareState? care;

  @override
  Widget build(BuildContext context) {
    final care = this.care;

    return PaperCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (care == null)
            Text(
              '돌봄 기록을 불러오는 중이에요.',
              style: MasilPetType.bodySmall,
            )
          else ...[
            PaperStatBar(
              label: '배부름',
              valueLabel: '${care.satiety}',
              ratio: care.satiety / 100,
              color: MasilPetPalette.statSatiety,
            ),
            const SizedBox(height: 14),
            PaperStatBar(
              label: '청결',
              valueLabel: '${care.cleanliness}',
              ratio: care.cleanliness / 100,
              color: MasilPetPalette.statClean,
            ),
            const SizedBox(height: 14),
            PaperStatBar(
              label: '활력',
              valueLabel: '${care.vitality}',
              ratio: care.vitality / 100,
              color: MasilPetPalette.statVitality,
            ),
            const SizedBox(height: 14),
            PaperStatBar(
              label: '행복',
              valueLabel: '${care.happiness}',
              ratio: care.happiness / 100,
              color: MasilPetPalette.stamp,
            ),
          ],
          const SizedBox(height: MasilPetSpacing.lg),
          const DashedRule(),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  pet.stage == PetStage.evolved ? '최종 진화 완료' : '진화까지',
                  style: MasilPetType.bodySmall.copyWith(
                    fontSize: 13.5,
                    height: 1.2,
                    color: MasilPetPalette.inkSoft,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Flexible, not rigid: at large text sizes the counter has to be
              // allowed to wrap rather than push off the card.
              Flexible(
                child: Text(
                  'EXP ${pet.stats.exp} / $petEvolutionExpGoal',
                  textAlign: TextAlign.right,
                  style: MasilPetType.rowTitle.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          if (care != null) ...[
            const SizedBox(height: 8),
            Text(
              '성장 성향 · ${care.growthTendency.label}',
              style: MasilPetType.caption.copyWith(
                color: MasilPetPalette.forest,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the next stage asks for, written as a checklist in the margin.
class _GrowthGoalNote extends StatelessWidget {
  const _GrowthGoalNote({required this.pet, required this.onOpenMap});

  final Pet pet;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final requirements = _growthRequirementsFor(pet);
    final title = switch (pet.stage) {
      PetStage.baby => '성장 조건',
      PetStage.grown => '진화 조건',
      PetStage.evolved => '완료',
    };
    final description = switch (pet.stage) {
      PetStage.baby =>
        'Lv.${GrowthEngine.grownLevelRequirement}까지 도장을 모으면 성장 단계가 열려요.',
      PetStage.grown => '진화에는 레벨, 지식, 지역 친밀도가 모두 필요해요.',
      PetStage.evolved => '전국을 걸으며 쌓은 기억을 모두 간직한 상태예요.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionEyebrow(title),
        PaperCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(description,
                  style: MasilPetType.prose.copyWith(fontSize: 15)),
              if (requirements.isNotEmpty) ...[
                const SizedBox(height: MasilPetSpacing.lg),
                for (final (index, requirement) in requirements.indexed) ...[
                  PaperStatBar(
                    label: requirement.label,
                    valueLabel: requirement.valueLabel,
                    ratio: requirement.progress,
                    color: requirement.isComplete
                        ? MasilPetPalette.forest
                        : MasilPetPalette.statSatiety,
                  ),
                  if (index != requirements.length - 1)
                    const SizedBox(height: 13),
                ],
                const SizedBox(height: MasilPetSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PaperButton.ghost(
                    label: '지도에서 성장 보상 얻기',
                    onPressed: onOpenMap,
                    expand: false,
                    fontSize: 14,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The last place you walked, remembered out loud.
class _PetMemoryBook extends StatelessWidget {
  const _PetMemoryBook({required this.memories, required this.petName});

  final List<PetMemory> memories;
  final String petName;

  @override
  Widget build(BuildContext context) {
    final visible = memories.take(5).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionEyebrow('추억 수첩', trailing: MonoChip('${memories.length}개')),
        DashedBox(
          fill: MasilPetPalette.subtle,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, memory) in visible.indexed) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${memory.createdAt.month.toString().padLeft(2, '0')}.'
                      '${memory.createdAt.day.toString().padLeft(2, '0')}',
                      style: MasilPetType.microMono,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memory.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MasilPetType.rowTitle.copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            memory.detail,
                            style:
                                MasilPetType.bodySmall.copyWith(fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (index != visible.length - 1) ...[
                  const SizedBox(height: 12),
                  const DashedRule(),
                  const SizedBox(height: 12),
                ],
              ],
              if (memories.length > visible.length) ...[
                const SizedBox(height: 12),
                Text(
                  '${petCallName(petName)}가 ${memories.length - visible.length}개의 기억을 더 간직하고 있어요.',
                  style: MasilPetType.caption,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MemoryNote extends StatelessWidget {
  const _MemoryNote({required this.memory, required this.petName});

  final _WalkMemory memory;
  final String petName;

  @override
  Widget build(BuildContext context) {
    return DashedBox(
      fill: MasilPetPalette.subtle,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HandNote('같이 다녀온 곳'),
          const SizedBox(height: MasilPetSpacing.sm),
          Text(
            '${memory.whenLabel} · ${memory.placeLabel}',
            style: MasilPetType.rowTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            '${petCallName(petName)}는 그날의 냄새를 아직 기억하고 있어요.',
            style: MasilPetType.bodySmall.copyWith(fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

/// 내 마실펫 — everyone in the notebook, with the current companion marked.
class _RosterSection extends ConsumerWidget {
  const _RosterSection({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(masilPetControllerProvider.notifier);

    if (state.pets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionEyebrow('내 마실펫 ${state.pets.length}마리'),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            const minCell = 250.0;
            final columns =
                ((constraints.maxWidth + spacing) / (minCell + spacing))
                    .floor()
                    .clamp(1, 4);
            final itemWidth =
                ((constraints.maxWidth - spacing * (columns - 1)) / columns)
                    .clamp(0.0, double.infinity);

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final pet in state.pets)
                  SizedBox(
                    width: itemWidth,
                    child: _RosterCard(
                      pet: pet,
                      template: controller.templateFor(pet.templateId),
                      care: state.careForPet(pet.id),
                      isActive: pet.id == state.activePetId,
                      onSetMain: () => controller.selectPet(pet.id),
                      onDetail: () => showPetDetailSheet(
                        context: context,
                        pet: pet,
                        template: controller.templateFor(pet.templateId),
                        care: state.careForPet(pet.id),
                        isActive: pet.id == state.activePetId,
                        onSetMain: () => controller.selectPet(pet.id),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RosterCard extends StatelessWidget {
  const _RosterCard({
    required this.pet,
    required this.template,
    required this.care,
    required this.isActive,
    required this.onSetMain,
    required this.onDetail,
  });

  final Pet pet;
  final PetTemplate template;
  final PetCareState? care;
  final bool isActive;
  final VoidCallback onSetMain;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PixelSprite(
                asset: PetAssets.growth(template.assetKey, pet.stage.name),
                size: 58,
                semanticLabel: pet.name,
                fallback: SizedBox(
                  width: 58,
                  height: 58,
                  child: Center(
                    child: Text(
                      template.initials,
                      style: MasilPetType.rowTitle.copyWith(
                        fontSize: 20,
                        color: Color(template.colorValue),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pet.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MasilPetType.rowTitle.copyWith(fontSize: 17),
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          const _MainTag(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Lv.${pet.level} · ${pet.stage.label} · '
                      '${pet.bondLevel.label} · '
                      '${shortRegionLabelForId(template.regionId)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MasilPetType.caption.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '함께한 날 ${care?.bondedDays ?? 0}일 · '
                      '추억 ${care?.memories.length ?? 0}개',
                      style: MasilPetType.caption.copyWith(fontSize: 11.5),
                    ),
                    const SizedBox(height: 8),
                    PaperTrack(
                      ratio: care?.overallRatio ?? 0,
                      color: MasilPetPalette.forest,
                      height: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PaperButton.ghost(
                  label: '상세보기',
                  onPressed: onDetail,
                  fontSize: 12.5,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: isActive
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          '지금 함께 다녀요',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MasilPetType.caption.copyWith(fontSize: 12.5),
                        ),
                      )
                    : PaperButton(
                        label: '함께 걷기',
                        onPressed: onSetMain,
                        fontSize: 12.5,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MainTag extends StatelessWidget {
  const _MainTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: MasilPetPalette.stampPale),
        borderRadius: MasilPetRadii.tightBorder,
      ),
      child: Text(
        '동행',
        style: MasilPetType.microMono.copyWith(
          fontSize: 8.5,
          letterSpacing: 0.85,
          color: MasilPetPalette.stamp,
        ),
      ),
    );
  }
}

int _talksLeftToday(MasilPetState state) {
  final countToday = isSameLocalDay(state.dialogueDay, DateTime.now())
      ? state.dialogueCountToday
      : 0;
  return (5 - countToday).clamp(0, 5).toInt();
}

/// Sprite emotion follows what the pet is doing, then falls back to how well
/// it is being looked after.
String _stageEmotion(PetFieldActivity activity, PetCareState? care) {
  if (care?.isSleeping == true) {
    return 'sleepy';
  }
  if (care?.ailment != null && care!.ailment != PetAilment.none) {
    return 'sad';
  }
  switch (activity) {
    case PetFieldActivity.jumping:
    case PetFieldActivity.greeting:
      return 'excited';
    case PetFieldActivity.eating:
      return 'happy';
    case PetFieldActivity.sleeping:
      return 'sleepy';
    case PetFieldActivity.idle:
    case PetFieldActivity.walking:
      break;
  }
  final ratio = care?.overallRatio ?? 1;
  if (ratio >= 0.7) {
    return 'happy';
  }
  if (ratio >= 0.4) {
    return 'neutral';
  }
  return 'sad';
}

String _friendlyPetMessage(MasilPetState state, Pet pet) {
  final raw = state.statusMessage.trim();
  final template = state.templates.firstWhere(
    (item) => item.id == pet.templateId,
    orElse: () => state.templates.first,
  );
  const dialogue = StaticDialogueService();
  if (raw.contains(pet.name) && raw.length <= 100) {
    return raw;
  }
  if (raw.isNotEmpty &&
      dialogue.isDialogueText(
        templateId: template.id,
        text: raw,
      )) {
    return raw;
  }
  final care = state.activePetCare;
  if (care != null) {
    final need = const CareEngine().requestFor(care, DateTime.now());
    final requestLine = switch (need) {
      PetNeed.hungry => '밥그릇이 자꾸 눈에 들어와…',
      PetNeed.dirty => '몸을 털고 나면 개운할 것 같아.',
      PetNeed.tired => '조금만 포근하게 쉬어도 될까?',
      PetNeed.bored => '같이 놀면 금방 신날 것 같아!',
      PetNeed.potty => '내 주변을 한번 살펴봐 줄래?',
      PetNeed.sick => '오늘은 내 곁에 조금 더 있어 줘.',
      PetNeed.sleeping => '음… 오늘 산책길 꿈을 꾸는 중이야.',
      PetNeed.wantsWalk => '현관 밖에는 어떤 냄새가 날까?',
      PetNeed.content => null,
    };
    if (requestLine != null) {
      return requestLine;
    }
  }
  final seed = pet.id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return dialogue
      .lineForAmbient(
        template: template,
        care: state.careForPet(pet.id),
        now: DateTime.now(),
        variantSeed: seed,
      )
      .text;
}

class _WalkMemory {
  const _WalkMemory({required this.whenLabel, required this.placeLabel});

  final String whenLabel;
  final String placeLabel;
}

_WalkMemory? _walkMemory(MasilPetState state, String petId) {
  final recent = state.recentCheckIns
      .where((checkIn) => checkIn.companionPetId == petId)
      .toList(growable: false);
  if (recent.isEmpty) {
    return null;
  }
  final checkIn = recent.first;
  String place = checkIn.category.label;
  for (final poi in state.pois) {
    if (poi.id == checkIn.poiId) {
      place = poi.title;
      break;
    }
  }
  return _WalkMemory(
    whenLabel: _relativeDayLabel(checkIn.createdAt),
    placeLabel: place,
  );
}

String _relativeDayLabel(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(value.year, value.month, value.day);
  final difference = today.difference(day).inDays;
  final time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  return switch (difference) {
    <= 0 => '오늘 · $time',
    1 => '어제 · $time',
    _ => '${_shortDateLabel(value)} · $time',
  };
}

String _shortDateLabel(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month.$day';
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
          label: '지식',
          current: pet.stats.knowledge,
          target: GrowthEngine.evolvedKnowledgeRequirement,
        ),
        _GrowthRequirement.stat(
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
    required this.label,
    required this.current,
    required this.target,
    required this.valueLabel,
  });

  factory _GrowthRequirement.level({
    required int currentLevel,
    required int targetLevel,
  }) {
    return _GrowthRequirement(
      label: '레벨',
      current: currentLevel,
      target: targetLevel,
      valueLabel: 'Lv.$currentLevel / $targetLevel',
    );
  }

  factory _GrowthRequirement.stat({
    required String label,
    required int current,
    required int target,
  }) {
    return _GrowthRequirement(
      label: label,
      current: current,
      target: target,
      valueLabel: '$current / $target',
    );
  }

  final String label;
  final int current;
  final int target;
  final String valueLabel;

  bool get isComplete => current >= target;

  double get progress {
    if (target <= 0) {
      return 1;
    }
    return (current / target).clamp(0.0, 1.0).toDouble();
  }
}
