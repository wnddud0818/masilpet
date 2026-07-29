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

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: kPaperBodyPadding,
          sliver: ResponsiveSliverList(
            children: [
              if (pet == null)
                EmptyStateCard(
                  note: '아직 친구가 없어요',
                  title: '함께 다니는 마실펫이 없습니다',
                  body: '하우스에서 알을 부화하면 이 자리에 친구가 섭니다.',
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
                ),
                const SizedBox(height: 18),
                _PetIdentityRow(
                  pet: pet,
                  template: controller.templateFor(pet.templateId),
                ),
                const SizedBox(height: 18),
                _CareActions(
                  care: care,
                  isBusy: state.isBusy,
                  onFeed: controller.feedActivePet,
                  onPlay: controller.playActivePet,
                  onClean: controller.cleanActivePet,
                  onSleep: state.isBusy ? null : controller.sleepActivePet,
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
                if (_walkMemory(state) case final memory?) ...[
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

/// The stage: sky over grass, one pet, one line of speech.
class _PetStage extends StatelessWidget {
  const _PetStage({
    required this.state,
    required this.pet,
    required this.template,
    required this.care,
    required this.talksLeft,
    required this.onTalk,
  });

  final MasilPetState state;
  final Pet pet;
  final PetTemplate template;
  final PetCareState? care;
  final int talksLeft;
  final VoidCallback? onTalk;

  @override
  Widget build(BuildContext context) {
    final emotion = _stageEmotion(state.fieldActivity, care);
    final excited = emotion == 'excited';
    final message = _friendlyPetMessage(state, pet);

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
                        onTap: onTalk,
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
                  'Lv.${pet.level} · ${pet.stage.label} 단계 · $days일째 동행',
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

/// 오늘 해준 것 — three flat paper keys.
class _CareActions extends StatelessWidget {
  const _CareActions({
    required this.care,
    required this.isBusy,
    required this.onFeed,
    required this.onPlay,
    required this.onClean,
    required this.onSleep,
  });

  final PetCareState? care;
  final bool isBusy;
  final VoidCallback onFeed;
  final VoidCallback onPlay;
  final VoidCallback onClean;
  final VoidCallback? onSleep;

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
          trailing: MonoButton(label: '포근하게 재우기', onPressed: onSleep),
        ),
        Row(
          children: [
            for (final (index, action) in actions.indexed) ...[
              Expanded(child: _CareActionButton(data: action)),
              if (index != actions.length - 1) const SizedBox(width: 9),
            ],
          ],
        ),
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
              Text(
                'EXP ${pet.stats.exp} / $petEvolutionExpGoal',
                style: MasilPetType.rowTitle.copyWith(fontSize: 15),
              ),
            ],
          ),
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
                (constraints.maxWidth - spacing * (columns - 1)) / columns;

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
                      '${shortRegionLabelForId(template.regionId)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MasilPetType.caption.copyWith(fontSize: 12),
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
                        label: '주 캐릭터로',
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
        'MAIN',
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
  if (raw.isNotEmpty &&
      dialogue.isDialogueText(
        templateId: template.id,
        text: raw,
      )) {
    return raw;
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

_WalkMemory? _walkMemory(MasilPetState state) {
  final recent = state.recentCheckIns;
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
