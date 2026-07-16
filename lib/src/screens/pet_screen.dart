import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../services.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pet_play_field.dart';
import '../widgets/rarity_badge.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/reward_chip_row.dart';
import '../widgets/stat_bar.dart';

class PetScreen extends ConsumerWidget {
  const PetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);
    final pet = state.activePet;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('마실펫'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: _CarePointPill(points: state.carePoints),
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: ResponsiveSliverList(
            children: [
              _PetCareLayout(
                state: state,
                pet: pet,
                isBusy: state.isBusy,
                onTalk: controller.talkWithActivePet,
                onFeed: controller.feedActivePet,
                onPlay: controller.playActivePet,
                onClean: controller.cleanActivePet,
                onSleep: controller.sleepActivePet,
                onClaimRoutine: controller.claimDailyCareReward,
                onOpenMap: () => controller.setTab(0),
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
    required this.onPlay,
    required this.onClean,
    required this.onSleep,
    required this.onClaimRoutine,
    required this.onOpenMap,
  });

  static const _wideBreakpoint = 840.0;

  final MasilPetState state;
  final Pet? pet;
  final bool isBusy;
  final VoidCallback onTalk;
  final VoidCallback onFeed;
  final VoidCallback onPlay;
  final VoidCallback onClean;
  final VoidCallback onSleep;
  final VoidCallback onClaimRoutine;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final talksLeft = _talksLeftToday(state);
    final care = state.activePetCare;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= _wideBreakpoint;
        final playField = _PocketPetConsole(
          state: state,
          pet: pet,
          care: care,
          isWide: useTwoColumns,
          onSleep: isBusy || pet == null ? null : onSleep,
        );
        final actions = _CareActionRow(
          isBusy: isBusy,
          talksLeft: talksLeft,
          feedCountToday: care?.feedCountToday ?? 0,
          onTalk: onTalk,
          onFeed: onFeed,
          onPlay: onPlay,
          onClean: onClean,
        );
        final companionCard = pet == null
            ? null
            : _CompanionDialogueCard(
                state: state,
                pet: pet!,
                talksLeft: talksLeft,
                isBusy: isBusy,
                onOpenMap: onOpenMap,
              );
        final details = pet == null
            ? const _NoActivePetCard()
            : _ActivePetPanel(petId: pet!.id);
        final routine = _DailyCareCard(
          state: state,
          onClaim: onClaimRoutine,
          onOpenMap: onOpenMap,
        );

        if (!useTwoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              playField,
              if (pet != null) ...[
                const SizedBox(height: 12),
                _PetMessageBubble(state: state, pet: pet!),
              ],
              const SizedBox(height: 14),
              if (pet != null) ...[
                _CareReadinessCard(pet: pet!),
                const SizedBox(height: 12),
                actions,
                const SizedBox(height: 12),
                routine,
                const SizedBox(height: 12),
                companionCard!,
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
                    _PetMessageBubble(state: state, pet: pet!),
                    const SizedBox(height: 12),
                    actions,
                    const SizedBox(height: 12),
                    companionCard!,
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
                    routine,
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

class _CarePointPill extends StatelessWidget {
  const _CarePointPill({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: MasilPetPalette.sunPale,
        borderRadius: MasilPetRadii.pillBorder,
        border: Border.all(color: MasilPetPalette.sun),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.favorite_rounded,
            size: 16,
            color: MasilPetPalette.coral,
          ),
          const SizedBox(width: 5),
          Text(
            '$points P',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: MasilPetPalette.ink,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _PocketPetConsole extends StatelessWidget {
  const _PocketPetConsole({
    required this.state,
    required this.pet,
    required this.care,
    required this.isWide,
    required this.onSleep,
  });

  final MasilPetState state;
  final Pet? pet;
  final PetCareState? care;
  final bool isWide;
  final VoidCallback? onSleep;

  @override
  Widget build(BuildContext context) {
    final ratio = care?.overallRatio ?? 0.72;
    final accent = ratio >= 0.72
        ? MasilPetPalette.mint
        : ratio >= 0.42
            ? MasilPetPalette.sun
            : MasilPetPalette.coral;
    final status = ratio >= 0.72
        ? '기분 최고'
        : ratio >= 0.42
            ? '돌봄 필요'
            : '보고 싶었어요';

    return Semantics(
      container: true,
      label: pet == null
          ? '함께할 마실펫을 기다리는 빈 방'
          : '${pet!.name}, 레벨 ${pet!.level}, $status',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.92),
              accent.withValues(alpha: 0.62),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: MasilPetRadii.heroBorder,
          border: Border.all(color: MasilPetPalette.ink, width: 2),
          boxShadow: [
            const BoxShadow(
              color: Color(0x3327332D),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.9),
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: MasilPetPalette.coral,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pet == null ? 'MY MASILPET' : pet!.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: MasilPetPalette.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (pet != null) ...[
                  _ConsoleInfoPill(label: 'Lv.${pet!.level}'),
                  const SizedBox(width: 6),
                  _ConsoleInfoPill(label: pet!.stage.label),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: MasilPetPalette.ink,
                borderRadius: BorderRadius.circular(22),
              ),
              child: PetPlayField(
                templates: state.templates,
                pets: state.pets,
                eggs: state.eggs,
                activePetId: state.activePetId,
                activity: state.fieldActivity,
                activityNonce: state.fieldActivityNonce,
                height: isWide ? 390 : 280,
                spriteScale: isWide ? 1.6 : 1.45,
                showVisitors: false,
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                for (var index = 0; index < 5; index++)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: const BoxDecoration(
                      color: Color(0x8827332D),
                      shape: BoxShape.circle,
                    ),
                  ),
                const Spacer(),
                Text(
                  status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: MasilPetPalette.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(width: 9),
                IconButton(
                  tooltip: '포근하게 재우기',
                  onPressed: onSleep,
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(38),
                    backgroundColor: MasilPetPalette.paper,
                    foregroundColor: MasilPetPalette.lavenderDeep,
                    side: const BorderSide(color: MasilPetPalette.ink),
                  ),
                  icon: const Icon(Icons.bedtime_rounded, size: 19),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsoleInfoPill extends StatelessWidget {
  const _ConsoleInfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: MasilPetPalette.paper.withValues(alpha: 0.88),
        borderRadius: MasilPetRadii.pillBorder,
        border: Border.all(color: const Color(0x5527332D)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: MasilPetPalette.ink,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _PetMessageBubble extends StatelessWidget {
  const _PetMessageBubble({required this.state, required this.pet});

  final MasilPetState state;
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final message = _friendlyPetMessage(state, pet);
    return Semantics(
      liveRegion: true,
      label: '${pet.name}의 말, $message',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: MasilPetPalette.paper,
          borderRadius: MasilPetRadii.cardBorder,
          border: Border.all(color: MasilPetPalette.outline, width: 1.2),
          boxShadow: MasilPetShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: MasilPetPalette.sky,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: MasilPetPalette.ink,
                size: 18,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                '“$message”',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MasilPetPalette.ink,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

class _DailyCareCard extends StatelessWidget {
  const _DailyCareCard({
    required this.state,
    required this.onClaim,
    required this.onOpenMap,
  });

  final MasilPetState state;
  final VoidCallback onClaim;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final routine = state.dailyCareRoutine;
    final progress =
        (routine.completedCount / routine.targetCount).clamp(0.0, 1.0);
    final tasks = [
      _DailyTaskData('밥', Icons.restaurant_rounded, routine.fed),
      _DailyTaskData('놀이', Icons.sports_esports_rounded, routine.played),
      _DailyTaskData('씻기', Icons.bathtub_rounded, routine.cleaned),
      _DailyTaskData('대화', Icons.chat_bubble_rounded, routine.talked),
      _DailyTaskData('산책', Icons.directions_walk_rounded, routine.checkedIn),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 50,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        color: MasilPetPalette.leaf,
                        backgroundColor: MasilPetPalette.creamDeep,
                      ),
                    ),
                    Text(
                      '${routine.completedCount.clamp(0, routine.targetCount)}/${routine.targetCount}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘의 돌봄 루틴',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '다섯 가지 중 네 가지만 해도 마음 포인트를 받아요.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _CarePointPill(points: state.carePoints),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final task in tasks) _DailyTaskChip(data: task),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: state.hasClaimedDailyCareRewardToday
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('오늘의 포인트 받기 완료'),
                    )
                  : state.canClaimDailyCareReward
                      ? FilledButton.icon(
                          onPressed: onClaim,
                          icon: const Icon(Icons.redeem_rounded),
                          label: const Text('마음 포인트 30 받기'),
                        )
                      : OutlinedButton.icon(
                          onPressed: routine.checkedIn ? null : onOpenMap,
                          icon: const Icon(Icons.map_outlined),
                          label: Text(
                            routine.checkedIn
                                ? '${routine.remainingCount}개 더 돌보기'
                                : '산책으로 루틴 채우기',
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyTaskData {
  const _DailyTaskData(this.label, this.icon, this.completed);

  final String label;
  final IconData icon;
  final bool completed;
}

class _DailyTaskChip extends StatelessWidget {
  const _DailyTaskChip({required this.data});

  final _DailyTaskData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: data.completed
            ? MasilPetPalette.mintPale
            : MasilPetPalette.creamDeep.withValues(alpha: 0.72),
        borderRadius: MasilPetRadii.pillBorder,
        border: Border.all(
          color:
              data.completed ? MasilPetPalette.mint : MasilPetPalette.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            data.completed ? Icons.check_circle_rounded : data.icon,
            size: 16,
            color: data.completed
                ? MasilPetPalette.leaf
                : MasilPetPalette.mutedInk,
          ),
          const SizedBox(width: 5),
          Text(
            data.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: data.completed
                      ? MasilPetPalette.leafDark
                      : MasilPetPalette.mutedInk,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _CareActionRow extends StatelessWidget {
  const _CareActionRow({
    required this.isBusy,
    required this.talksLeft,
    required this.feedCountToday,
    required this.onTalk,
    required this.onFeed,
    required this.onPlay,
    required this.onClean,
  });

  final bool isBusy;
  final int talksLeft;
  final int feedCountToday;
  final VoidCallback onTalk;
  final VoidCallback onFeed;
  final VoidCallback onPlay;
  final VoidCallback onClean;

  @override
  Widget build(BuildContext context) {
    final canTalk = talksLeft > 0;
    final canFeed = feedCountToday < dailyFeedCareLimit;
    final feedsLeft = (dailyFeedCareLimit - feedCountToday).clamp(
      0,
      dailyFeedCareLimit,
    );
    final actions = [
      _CareActionData(
        icon: canTalk ? Icons.chat_bubble_outline : Icons.check_rounded,
        label: canTalk ? '대화' : '대화 완료',
        detail: canTalk ? '$talksLeft회 남음' : '내일 또 만나요',
        color: MasilPetPalette.sky,
        onTap: isBusy || !canTalk ? null : onTalk,
      ),
      _CareActionData(
        icon: canFeed ? Icons.restaurant_rounded : Icons.check_rounded,
        label: canFeed ? '밥 주기' : '밥 챙기기 완료',
        detail: canFeed ? '$feedsLeft회 남음' : '내일 또 챙겨요',
        color: MasilPetPalette.sun,
        onTap: isBusy || !canFeed ? null : onFeed,
      ),
      _CareActionData(
        icon: Icons.sports_esports_rounded,
        label: '놀아주기',
        detail: '활력 UP',
        color: MasilPetPalette.coral,
        onTap: isBusy ? null : onPlay,
      ),
      _CareActionData(
        icon: Icons.bathtub_rounded,
        label: '씻겨주기',
        detail: '청결도 UP',
        color: MasilPetPalette.mint,
        onTap: isBusy ? null : onClean,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 430 ? 2 : 4;
        const spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in actions)
              SizedBox(
                width: itemWidth,
                child: _CareActionButton(data: action),
              ),
          ],
        );
      },
    );
  }
}

class _CareActionData {
  const _CareActionData({
    required this.icon,
    required this.label,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color color;
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
      child: Material(
        color: enabled
            ? data.color.withValues(alpha: 0.44)
            : Theme.of(context).disabledColor.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: MasilPetRadii.panelBorder,
          side: BorderSide(
            color: enabled
                ? data.color.withValues(alpha: 0.9)
                : Theme.of(context).disabledColor.withValues(alpha: 0.2),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: data.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
            child: Column(
              children: [
                Icon(
                  data.icon,
                  color: enabled
                      ? MasilPetPalette.ink
                      : Theme.of(context).disabledColor,
                ),
                const SizedBox(height: 7),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: MasilPetPalette.mutedInk,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanionDialogueCard extends StatelessWidget {
  const _CompanionDialogueCard({
    required this.state,
    required this.pet,
    required this.talksLeft,
    required this.isBusy,
    required this.onOpenMap,
  });

  final MasilPetState state;
  final Pet pet;
  final int talksLeft;
  final bool isBusy;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final template = state.templates.firstWhere(
      (item) => item.id == pet.templateId,
      orElse: () => state.templates.first,
    );
    final latestCheckIn = _latestCheckInForDialogue(state);
    final latestPoi = latestCheckIn == null
        ? null
        : _poiForDialogueCheckIn(state, latestCheckIn);
    final memoryCategory = state.lastVisitedCategory ?? latestCheckIn?.category;
    final line = const StaticDialogueService().lineFor(
      template: template,
      lastCategory: memoryCategory,
    );
    final reward = latestCheckIn?.rewardApplied == true
        ? latestCheckIn?.reward ??
            const GrowthEngine().rewardFor(latestCheckIn!.category)
        : null;
    final scheme = Theme.of(context).colorScheme;
    final canTalk = talksLeft > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: scheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '동행 대화',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _DialogueMemoryBadge(
                  label: memoryCategory == null
                      ? '탐험 대기'
                      : '${memoryCategory.label} 기억',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '“${line.text}”',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            _DialogueMemoryLine(
              icon: latestCheckIn == null
                  ? Icons.explore_outlined
                  : Icons.place_outlined,
              text: latestCheckIn == null
                  ? '첫 체크인을 기록하면 장소 기억에 맞춘 대화가 열립니다.'
                  : '${latestPoi?.title ?? '저장된 방문 장소'} · ${latestCheckIn.category.label} · ${latestCheckIn.distanceMeters.round()}m',
            ),
            const SizedBox(height: 8),
            _DialogueMemoryLine(
              icon: Icons.forum_outlined,
              text: canTalk
                  ? '오늘 대화 ${5 - talksLeft}/5회 · $talksLeft회 남음'
                  : '오늘 대화 5/5회 · 새 장소를 다녀오면 내일 다시 이어집니다.',
            ),
            if (reward != null) ...[
              const SizedBox(height: 12),
              RewardChipRow(
                reward: reward,
                spacing: 6,
                runSpacing: 6,
              ),
            ],
            const SizedBox(height: 12),
            if (canTalk)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: MasilPetPalette.sky.withValues(alpha: 0.22),
                  borderRadius: MasilPetRadii.controlBorder,
                ),
                child: const Text(
                  '위의 대화 버튼을 누르면 이 기억에서 새로운 이야기가 이어져요.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onOpenMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('지도에서 새 이야기 찾기'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

CheckIn? _latestCheckInForDialogue(MasilPetState state) {
  final recent = state.recentCheckIns;
  return recent.isEmpty ? null : recent.first;
}

Poi? _poiForDialogueCheckIn(MasilPetState state, CheckIn checkIn) {
  for (final poi in state.pois) {
    if (poi.id == checkIn.poiId) {
      return poi;
    }
  }
  return null;
}

class _DialogueMemoryBadge extends StatelessWidget {
  const _DialogueMemoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.56),
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

class _DialogueMemoryLine extends StatelessWidget {
  const _DialogueMemoryLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: scheme.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
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
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(masilPetControllerProvider);
        final care =
            state.careForPet(pet.id) ?? PetCareState.initial(DateTime.now());
        final overall = (care.overallRatio * 100).round();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: MasilPetPalette.coralPale,
                        borderRadius: MasilPetRadii.controlBorder,
                      ),
                      child: const Icon(
                        Icons.monitor_heart_rounded,
                        color: MasilPetPalette.coral,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '오늘의 컨디션',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ),
                    Text(
                      '$overall%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: MasilPetPalette.leafDark,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _CareNeedMeter(
                        icon: Icons.restaurant_rounded,
                        label: '포만',
                        value: care.satiety,
                        color: MasilPetPalette.sun,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _CareNeedMeter(
                        icon: Icons.bubble_chart_rounded,
                        label: '청결',
                        value: care.cleanliness,
                        color: MasilPetPalette.skyDeep,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _CareNeedMeter(
                        icon: Icons.bolt_rounded,
                        label: '활력',
                        value: care.vitality,
                        color: MasilPetPalette.coral,
                      ),
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

class _CareNeedMeter extends StatelessWidget {
  const _CareNeedMeter({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value퍼센트',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text(
                '$value',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: MasilPetPalette.mutedInk,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: MasilPetRadii.pillBorder,
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.14),
            ),
          ),
        ],
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Lv.${pet.level} · ${pet.stage.label} 단계'),
                          RarityBadge(rarity: template.rarity, compact: true),
                        ],
                      ),
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
      PetStage.baby =>
        'Lv.${GrowthEngine.grownLevelRequirement}까지 탐험 보상을 모으면 성장 단계가 열립니다.',
      PetStage.grown => '진화에는 레벨, 지식, 지역 친밀도가 모두 필요합니다.',
      PetStage.evolved => '전국 탐험의 깊은 기억을 모두 간직한 상태입니다.',
    };
    final requirements = _growthRequirementsFor(pet);
    final requirementTitle = switch (pet.stage) {
      PetStage.baby => '성장 조건',
      PetStage.grown => '진화 조건',
      PetStage.evolved => '완료 조건',
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
                if (requirements.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    requirementTitle,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  for (final requirement in requirements) ...[
                    _GrowthRequirementRow(requirement: requirement),
                    if (requirement != requirements.last)
                      const SizedBox(height: 8),
                  ],
                ],
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
          icon: Icons.menu_book_outlined,
          label: '지식',
          current: pet.stats.knowledge,
          target: GrowthEngine.evolvedKnowledgeRequirement,
        ),
        _GrowthRequirement.stat(
          icon: Icons.handshake_outlined,
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
    required this.icon,
    required this.label,
    required this.current,
    required this.target,
    required this.valueLabel,
    required this.remainingLabel,
  });

  factory _GrowthRequirement.level({
    required int currentLevel,
    required int targetLevel,
  }) {
    final remaining = (targetLevel - currentLevel).clamp(0, targetLevel);
    return _GrowthRequirement(
      icon: Icons.auto_graph,
      label: '레벨',
      current: currentLevel,
      target: targetLevel,
      valueLabel: 'Lv.$currentLevel/$targetLevel',
      remainingLabel: remaining == 0 ? '완료' : '$remaining레벨 필요',
    );
  }

  factory _GrowthRequirement.stat({
    required IconData icon,
    required String label,
    required int current,
    required int target,
  }) {
    final remaining = (target - current).clamp(0, target);
    return _GrowthRequirement(
      icon: icon,
      label: label,
      current: current,
      target: target,
      valueLabel: '$current/$target',
      remainingLabel: remaining == 0 ? '완료' : '$remaining 필요',
    );
  }

  final IconData icon;
  final String label;
  final int current;
  final int target;
  final String valueLabel;
  final String remainingLabel;

  bool get isComplete => current >= target;

  double get progress {
    if (target <= 0) {
      return 1;
    }
    return (current / target).clamp(0.0, 1.0).toDouble();
  }
}

class _GrowthRequirementRow extends StatelessWidget {
  const _GrowthRequirementRow({required this.requirement});

  final _GrowthRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor =
        requirement.isComplete ? const Color(0xFF0F766E) : scheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            requirement.isComplete
                ? Icons.check_circle_outline
                : requirement.icon,
            size: 18,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      requirement.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    requirement.valueLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: requirement.progress,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            requirement.remainingLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}
