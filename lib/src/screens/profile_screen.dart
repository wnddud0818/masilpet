import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_build_info.dart';
import '../models.dart';
import '../services.dart';
import '../services/privacy_navigation.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/metric_grid.dart';
import '../widgets/paper_kit.dart';
import '../widgets/paper_shell.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/status_banner.dart';

/// 기록: the walking passport — stamped days, totals, the recent trail, and
/// the housekeeping that belongs at the back of a notebook.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);
    final onlineActionEnabled = state.firebaseReady && !state.isBusy;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: kPaperBodyPadding,
          sliver: ResponsiveSliverList(
            children: [
              _PassportCard(state: state),
              const SizedBox(height: MasilPetSpacing.xl),
              _TotalsRow(state: state),
              const SizedBox(height: MasilPetSpacing.xl),
              _RecentWalks(state: state),
              const SizedBox(height: MasilPetSpacing.xl),
              _TodayReport(state: state),
              const SizedBox(height: MasilPetSpacing.xl),
              const StatusBanner(),
              const SizedBox(height: MasilPetSpacing.xl),
              _GoalList(
                state: state,
                onOpenMap: state.isBusy ? null : () => controller.setTab(0),
                onOpenPet: state.isBusy ? null : () => controller.setTab(1),
                onOpenHouse: state.isBusy ? null : () => controller.setTab(2),
              ),
              const SizedBox(height: MasilPetSpacing.xl),
              _LedgerSection(state: state),
              const SizedBox(height: MasilPetSpacing.xl),
              _MaintenanceSection(
                state: state,
                onUseDeviceLocation:
                    state.isBusy ? null : controller.useDeviceLocation,
                onUseStarterLocation:
                    state.isBusy ? null : controller.useStarterKoreaLocation,
                onBootstrapRemote: onlineActionEnabled
                    ? controller.ensureRemoteUserBootstrap
                    : null,
                onRefreshRemote: onlineActionEnabled
                    ? () => controller.refreshRemoteProgress()
                    : null,
              ),
              const SizedBox(height: MasilPetSpacing.xl),
              const _PrivacySection(),
              const SizedBox(height: MasilPetSpacing.xl),
              const _SourcesSection(),
              const SizedBox(height: MasilPetSpacing.xl),
              _ResetSection(
                state: state,
                onReset: () => _confirmResetProgress(
                  context: context,
                  controller: controller,
                  includeRemote: state.firebaseReady,
                ),
              ),
              const SizedBox(height: MasilPetSpacing.xl),
              _AppInfoSection(state: state, buildInfo: appBuildInfo),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmResetProgress({
    required BuildContext context,
    required MasilPetController controller,
    required bool includeRemote,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('진행도 초기화',
              style: MasilPetType.heroTitle.copyWith(fontSize: 22)),
          content: Text(
            includeRemote
                ? '기기 내 진행과 온라인 진행도를 모두 지워요.\n한 번 지우면 다시 되살릴 수 없어요.'
                : '기기 내 진행을 모두 지워요.\n한 번 지우면 다시 되살릴 수 없어요.',
            style: MasilPetType.bodySmall.copyWith(height: 1.7),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('취소', style: MasilPetType.bodySmall),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                '초기화',
                style: MasilPetType.rowTitle.copyWith(
                  fontSize: 15,
                  color: MasilPetPalette.stamp,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await controller.resetProgress();
    }
  }
}

/// The passport spread: this month's days, stamped where you walked.
class _PassportCard extends StatelessWidget {
  const _PassportCard({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final stampedDays = _stampedDaysThisMonth(state, now);
    final streak = state.currentVisitStreakDays;

    return PaperCard.stamped(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(
                      'WALKING PASSPORT · '
                      '${now.year}.${_twoDigits(now.month)}',
                    ),
                    const SizedBox(height: 5),
                    Text(
                      streak == 0 ? '오늘 첫 도장' : '$streak일 연속 산책',
                      style: MasilPetType.heroTitle.copyWith(
                        fontSize: 26,
                        letterSpacing: -0.52,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: HandNote(
                  streak >= 3 ? '잘하고 있어!' : '한 걸음부터',
                  fontSize: 22,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: MasilPetSpacing.lg),
          _PassportGrid(
            daysInMonth: daysInMonth,
            stampedDays: stampedDays,
          ),
        ],
      ),
    );
  }
}

class _PassportGrid extends StatelessWidget {
  const _PassportGrid({required this.daysInMonth, required this.stampedDays});

  final int daysInMonth;
  final Set<int> stampedDays;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 7;
        const spacing = 6.0;
        final cell = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var day = 1; day <= daysInMonth; day++)
              SizedBox(
                width: cell,
                child: PassportDay(
                  day: day,
                  stamped: stampedDays.contains(day),
                  // A hand-pressed stamp never lands perfectly square.
                  angleDegrees: (day % 3 - 1) * 4,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context) {
    final visitedPlaces =
        state.checkIns.map((checkIn) => checkIn.poiId).toSet().length;
    final companion = state.activePet;
    final companionDays =
        companion == null ? 0 : _daysSince(companion.hatchedAt);

    return MetricGrid(
      items: [
        MetricGridItem(label: '다녀온 산책지', value: '$visitedPlaces곳'),
        MetricGridItem(label: '누적 체크인', value: '${state.checkIns.length}회'),
        MetricGridItem(
          label: companion == null
              ? '함께한 날'
              : '${companion.name}${particleFor(companion.name, '과', '와')} 함께',
          value: '$companionDays일',
        ),
      ],
    );
  }
}

/// The trail of recent visits, hung off a dashed spine.
class _RecentWalks extends StatelessWidget {
  const _RecentWalks({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context) {
    final visits = state.recentCheckIns.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionEyebrow('최근 산책'),
        if (visits.isEmpty)
          Text(
            '아직 도장이 없어요. 지도에서 첫 산책지를 찍어보세요.',
            style: MasilPetType.bodySmall,
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DashedSpine(),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, checkIn) in visits.indexed) ...[
                          _WalkEntry(
                            checkIn: checkIn,
                            placeLabel: _placeLabel(state, checkIn),
                          ),
                          if (index != visits.length - 1)
                            const SizedBox(height: 18),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WalkEntry extends StatelessWidget {
  const _WalkEntry({required this.checkIn, required this.placeLabel});

  final CheckIn checkIn;
  final String placeLabel;

  @override
  Widget build(BuildContext context) {
    final reward = checkIn.rewardApplied
        ? checkIn.reward ?? const GrowthEngine().rewardFor(checkIn.category)
        : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -25,
          top: 6,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MasilPetPalette.stamp,
              border: Border.all(color: MasilPetPalette.canvas, width: 2),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _relativeDayLabel(checkIn.createdAt),
              style: MasilPetType.microMono.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                color: MasilPetPalette.faintWarm,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              placeLabel,
              style: MasilPetType.rowTitle.copyWith(fontSize: 16.5),
            ),
            const SizedBox(height: 3),
            Text(
              reward == null
                  ? '${checkIn.category.label} · ${checkIn.distanceMeters.round()}m'
                  : reward.summaryLabel,
              style: MasilPetType.caption,
            ),
          ],
        ),
      ],
    );
  }
}

/// 오늘의 리포트 — one paragraph you can copy and send to someone.
class _TodayReport extends StatelessWidget {
  const _TodayReport({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final score = _reportScore(state);
    final companion = state.activePet;
    final nextEgg = state.nextEgg;

    return DashedBox(
      fill: MasilPetPalette.subtle,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HandNote('오늘의 리포트'),
          const SizedBox(height: MasilPetSpacing.sm),
          Text(
            state.todayCheckInCount == 0
                ? '${now.month}월 ${now.day}일, 아직 도장을 찍지 않았어요.\n'
                    '가까운 산책지 한 곳만 다녀와도 오늘의 기록이 시작돼요.'
                : '${now.month}월 ${now.day}일, ${state.region.name}에서 '
                    '${state.todayCheckInCount}곳에 도장을 찍었어요.\n'
                    '${companion == null ? '마실펫' : petCallName(companion.name)}는 기분이 좋아졌고, '
                    '${nextEgg == null ? '알은 모두 부화했어요' : '알은 ${nextEgg.progress} / ${nextEgg.requiredSteps} 걸음까지 왔어요'}.',
            style: MasilPetType.prose.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              MonoChip('등급 ${_reportGrade(score)}'),
              MonoChip('$score점'),
              MonoChip('루프 ${_loopProgress(state)}/4'),
              MonoChip('카테고리 ${state.todayVisitedCategoryCount}/7'),
            ],
          ),
          const SizedBox(height: 14),
          PaperButton.ghost(
            label: '리포트 복사하기',
            onPressed: () => _copyReport(context, state),
            expand: false,
            fontSize: 14,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          ),
        ],
      ),
    );
  }
}

/// Today's goals as a checklist with progress tracks.
class _GoalList extends StatelessWidget {
  const _GoalList({
    required this.state,
    required this.onOpenMap,
    required this.onOpenPet,
    required this.onOpenHouse,
  });

  final MasilPetState state;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenPet;
  final VoidCallback? onOpenHouse;

  @override
  Widget build(BuildContext context) {
    final goals = _journeyGoals(
      state: state,
      onOpenMap: onOpenMap,
      onOpenPet: onOpenPet,
      onOpenHouse: onOpenHouse,
    );
    final next = goals.where((goal) => !goal.unlocked).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionEyebrow(
          '수첩 목표 ${goals.where((goal) => goal.unlocked).length} / ${goals.length}',
        ),
        PaperCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                next == null
                    ? '오늘의 목표를 모두 채웠어요. 도감에서 다음 지역을 골라보세요.'
                    : '다음 목표는 ${next.title}. ${next.body}',
                style: MasilPetType.prose.copyWith(fontSize: 15),
              ),
              const SizedBox(height: MasilPetSpacing.lg),
              for (final (index, goal) in goals.indexed) ...[
                PaperStatBar(
                  label: goal.title,
                  valueLabel: goal.progressLabel,
                  ratio: goal.progress,
                  color: goal.unlocked
                      ? MasilPetPalette.forest
                      : MasilPetPalette.statSatiety,
                ),
                if (index != goals.length - 1) const SizedBox(height: 13),
              ],
              if (next?.onAction != null) ...[
                const SizedBox(height: MasilPetSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PaperButton.ghost(
                    label: next!.actionLabel,
                    onPressed: next.onAction,
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

/// The facts page: one label, one value, dashed rules between.
class _LedgerSection extends StatelessWidget {
  const _LedgerSection({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('첫 산책 지역', state.region.name),
      ('위치 상태', state.hasFreshVerifiedLocation ? '확인 완료' : '확인 필요'),
      ('오늘 체크인', '${state.todayCheckInCount}회'),
      ('남은 체크인', '${state.remainingDailyCheckIns}회'),
      ('연속 산책', '${state.currentVisitStreakDays}일'),
      ('최장 연속', '${state.longestVisitStreakDays}일'),
      ('보유 마실펫', '${state.pets.length}종'),
      ('보유 알', '${state.eggs.length}개'),
      ('도감 수집률', '${(state.dexCompletionRatio * 100).round()}%'),
      ('돌봄 포인트', '${state.carePoints} P'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionEyebrow('수첩 요약'),
        PaperCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              for (final (index, row) in rows.indexed) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.$1,
                          style: MasilPetType.bodySmall.copyWith(
                            fontSize: 13.5,
                            height: 1.2,
                            color: MasilPetPalette.inkSoft,
                          ),
                        ),
                      ),
                      Text(row.$2, style: MasilPetType.metaMono),
                    ],
                  ),
                ),
                if (index != rows.length - 1)
                  const DashedRule(color: MasilPetPalette.hover),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MaintenanceSection extends StatelessWidget {
  const _MaintenanceSection({
    required this.state,
    required this.onUseDeviceLocation,
    required this.onUseStarterLocation,
    required this.onBootstrapRemote,
    required this.onRefreshRemote,
  });

  final MasilPetState state;
  final VoidCallback? onUseDeviceLocation;
  final VoidCallback? onUseStarterLocation;
  final VoidCallback? onBootstrapRemote;
  final VoidCallback? onRefreshRemote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionEyebrow('위치와 동기화'),
        PaperCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                state.firebaseReady
                    ? '계정과 연결되어 있어요. 산책·부화·돌봄 기록을 안전하게 맞춰요.\n'
                        '위치를 켜기 어려운 날에는 기본 위치로 체험할 수 있어요.'
                    : '지금은 이 기기에 기록을 저장하고 있어요. 연결되면 자동으로 이어져요.\n'
                        '위치를 켜기 어려운 날에는 기본 위치로 체험할 수 있어요.',
                style: MasilPetType.prose.copyWith(fontSize: 15),
              ),
              const SizedBox(height: MasilPetSpacing.lg),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PaperButton.ghost(
                    label: '현재 위치 사용',
                    onPressed: onUseDeviceLocation,
                    expand: false,
                    fontSize: 14,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                  ),
                  PaperButton.ghost(
                    label: '전국 기본 지도 보기',
                    onPressed: onUseStarterLocation,
                    expand: false,
                    fontSize: 14,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                  ),
                  PaperButton.ghost(
                    label: '계정 연결 확인',
                    onPressed: onBootstrapRemote,
                    expand: false,
                    fontSize: 14,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                  ),
                  PaperButton.ghost(
                    label: '진행도 다시 불러오기',
                    onPressed: onRefreshRemote,
                    expand: false,
                    fontSize: 14,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
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

class _PrivacySection extends StatelessWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionEyebrow('위치·개인정보 보호'),
        PaperCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '현재 위치는 주변 산책지 조회와 '
                '${checkInRadiusMeters ~/ 1}m 체크인 판정에만 써요. '
                '체크인은 최근 15분 안에 확인한 위치에서만 가능하고, '
                '체크인·부화·성장 기록은 Functions를 거쳐 저장해요.',
                style: MasilPetType.prose.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 12),
              const DashedRule(),
              const SizedBox(height: 12),
              Text(
                '개인정보 처리방침: /privacy.html',
                style: MasilPetType.metaMono.copyWith(
                  color: MasilPetPalette.stamp,
                ),
              ),
              const SizedBox(height: MasilPetSpacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: PaperButton.ghost(
                  label: '개인정보 처리방침 열기',
                  onPressed: () => _openPrivacyPolicy(context),
                  expand: false,
                  fontSize: 14,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await openPrivacyPolicyPage();
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('개인정보 처리방침을 열 수 없어요.')),
      );
    }
  }
}

class _SourcesSection extends StatelessWidget {
  const _SourcesSection();

  @override
  Widget build(BuildContext context) {
    final sources = <(String, String)>[
      ('TourAPI 지역 장소', '전국 산책지와 분류를 운영자 동기화로 반영해요.'),
      ('OpenStreetMap 지도', '지도 타일과 저작권 고지는 지도 화면에 표시돼요.'),
      (
        '지도 타일 설정',
        '${mapTileBuildConfig.providerLabel} · '
            '요청 식별자 ${mapTileBuildConfig.userAgentLabel}',
      ),
      ('Firebase Functions 검증', '체크인 거리, 중복 방지, 보상 지급을 서버에서 처리해요.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionEyebrow('데이터·지도 출처'),
        PaperCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              for (final (index, source) in sources.indexed) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(source.$1, style: MasilPetType.rowTitle),
                      const SizedBox(height: 3),
                      Text(source.$2, style: MasilPetType.caption),
                    ],
                  ),
                ),
                if (index != sources.length - 1)
                  const DashedRule(color: MasilPetPalette.hover),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ResetSection extends StatelessWidget {
  const _ResetSection({required this.state, required this.onReset});

  final MasilPetState state;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return DashedBox(
      color: MasilPetPalette.stampPale,
      fill: MasilPetPalette.subtle,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('되돌릴 수 없어요'),
          const SizedBox(height: MasilPetSpacing.sm),
          Text('진행도 관리', style: MasilPetType.sectionTitle),
          const SizedBox(height: 6),
          Text(
            state.firebaseReady
                ? '초기화하면 기기 내 진행과 온라인 진행도를 함께 지워요.'
                : '지금은 기기 내 진행만 초기화할 수 있어요.',
            style: MasilPetType.bodySmall,
          ),
          const SizedBox(height: 14),
          _DangerButton(
            label: '진행도 초기화',
            onPressed: state.isBusy ? null : onReset,
          ),
        ],
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: onPressed,
        borderRadius: MasilPetRadii.smallBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(
              color: enabled ? MasilPetPalette.stamp : MasilPetPalette.outline,
            ),
            borderRadius: MasilPetRadii.smallBorder,
          ),
          child: Text(
            label,
            style: MasilPetType.button.copyWith(
              fontSize: 14,
              color: enabled ? MasilPetPalette.stamp : MasilPetPalette.disabled,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppInfoSection extends StatelessWidget {
  const _AppInfoSection({required this.state, required this.buildInfo});

  final MasilPetState state;
  final AppBuildInfo buildInfo;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('실행 모드', state.firebaseConnectionLabel),
      ('앱 버전', buildInfo.versionLabel),
      ('빌드 채널', buildInfo.channelLabel),
      ('빌드 시각', buildInfo.buildTimeLabel),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionEyebrow('앱 정보와 연결'),
        PaperCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              for (final (index, row) in rows.indexed) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.$1,
                          style: MasilPetType.bodySmall.copyWith(
                            fontSize: 13.5,
                            height: 1.2,
                            color: MasilPetPalette.inkSoft,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          row.$2,
                          textAlign: TextAlign.right,
                          style: MasilPetType.metaMono,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index != rows.length - 1)
                  const DashedRule(color: MasilPetPalette.hover),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────── plumbing ──

class _JourneyGoal {
  const _JourneyGoal({
    required this.title,
    required this.body,
    required this.progressLabel,
    required this.progress,
    required this.unlocked,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String progressLabel;
  final double progress;
  final bool unlocked;
  final String actionLabel;
  final VoidCallback? onAction;
}

List<_JourneyGoal> _journeyGoals({
  required MasilPetState state,
  required VoidCallback? onOpenMap,
  required VoidCallback? onOpenPet,
  required VoidCallback? onOpenHouse,
}) {
  final dialogueToday = _dialogueCountToday(state);
  final nextEgg = state.nextEgg;
  final eggProgress = nextEgg?.progressRatio ?? 0;
  final hatchReady = state.hatchableEggCount > 0 || state.pets.length > 1;
  const streakGoalDays = 3;
  final streakDays = state.currentVisitStreakDays;

  return [
    _JourneyGoal(
      title: '동행 시작',
      body: state.pets.isEmpty
          ? '첫 마실펫을 만나면 동행이 시작돼요.'
          : '${state.activePet?.name ?? '마실펫'}과 함께 출발했어요.',
      progressLabel: state.pets.isEmpty ? '0 / 1' : '1 / 1',
      progress: state.pets.isEmpty ? 0 : 1,
      unlocked: state.pets.isNotEmpty,
      actionLabel: '하우스 보기',
      onAction: onOpenHouse,
    ),
    _JourneyGoal(
      title: '위치 인증',
      body: state.hasFreshVerifiedLocation
          ? '체크인 거리 계산이 준비됐어요.'
          : '현재 위치나 기본 체험 위치를 확인해 주세요.',
      progressLabel: state.hasFreshVerifiedLocation ? '1 / 1' : '0 / 1',
      progress: state.hasFreshVerifiedLocation ? 1 : 0,
      unlocked: state.hasFreshVerifiedLocation,
      actionLabel: '위치 확인하러 가기',
      onAction: onOpenMap,
    ),
    _JourneyGoal(
      title: '첫 발자국',
      body: state.todayCheckInCount > 0
          ? '오늘 첫 도장이 기록됐어요.'
          : '${checkInRadiusMeters ~/ 1}m 안의 산책지에 도장을 찍으면 열려요.',
      progressLabel: '${state.todayCheckInCount.clamp(0, 1)} / 1',
      progress: state.todayCheckInCount > 0 ? 1 : 0,
      unlocked: state.todayCheckInCount > 0,
      actionLabel: '지도에서 도장 찍기',
      onAction: onOpenMap,
    ),
    _JourneyGoal(
      title: '장소 이야기꾼',
      body: dialogueToday > 0
          ? '다녀온 곳 이야기를 마실펫에게 들려줬어요.'
          : '도장을 찍은 뒤 마실펫과 이야기를 나눠보세요.',
      progressLabel: '${dialogueToday.clamp(0, 1)} / 1',
      progress: dialogueToday > 0 ? 1 : 0,
      unlocked: dialogueToday > 0,
      actionLabel: '마실펫과 대화하기',
      onAction: onOpenPet,
    ),
    _JourneyGoal(
      title: '연속 산책',
      body: streakDays >= streakGoalDays
          ? '$streakDays일째 리듬을 이어가고 있어요.'
          : streakDays == 0
              ? '오늘 첫 도장을 찍으면 연속 산책이 시작돼요.'
              : '$streakDays일째예요. ${streakGoalDays - streakDays}일만 더!',
      progressLabel: streakDays >= streakGoalDays
          ? '$streakDays일'
          : '${streakDays.clamp(0, streakGoalDays)} / $streakGoalDays일',
      progress: (streakDays / streakGoalDays).clamp(0.0, 1.0).toDouble(),
      unlocked: streakDays >= streakGoalDays,
      actionLabel: '지도에서 이어가기',
      onAction: onOpenMap,
    ),
    _JourneyGoal(
      title: '부화 준비',
      body: hatchReady
          ? '새 친구를 맞이할 준비가 됐어요.'
          : nextEgg == null
              ? '도장 보상으로 알을 만나보세요.'
              : '${(nextEgg.progressRatio * 100).round()}%까지 걸음이 쌓였어요.',
      progressLabel: hatchReady ? '완료' : '${(eggProgress * 100).round()}%',
      progress: hatchReady ? 1 : eggProgress,
      unlocked: hatchReady,
      actionLabel: nextEgg == null ? '지도에서 알 찾기' : '하우스에서 알 보기',
      onAction: nextEgg == null ? onOpenMap : onOpenHouse,
    ),
  ];
}

Set<int> _stampedDaysThisMonth(MasilPetState state, DateTime now) {
  final days = <int>{};
  for (final checkIn in state.checkIns) {
    final at = checkIn.createdAt;
    if (at.year == now.year && at.month == now.month) {
      days.add(at.day);
    }
  }
  return days;
}

String _placeLabel(MasilPetState state, CheckIn checkIn) {
  for (final poi in state.pois) {
    if (poi.id == checkIn.poiId) {
      return poi.title;
    }
  }
  return '${checkIn.category.label} 산책지';
}

Future<void> _copyReport(BuildContext context, MasilPetState state) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Clipboard.setData(ClipboardData(text: _reportText(state)));
    messenger.showSnackBar(
      const SnackBar(content: Text('오늘의 리포트를 복사했어요.')),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('리포트를 복사하지 못했어요.')),
    );
  }
}

String _reportText(MasilPetState state) {
  final latest = state.todayCheckIns.firstOrNull;
  if (latest == null) {
    return 'MasilPet 오늘의 리포트\n아직 오늘의 도장이 없어요. 지도에서 첫 산책지를 기록해 보세요.';
  }

  final reward = latest.rewardApplied
      ? latest.reward ?? const GrowthEngine().rewardFor(latest.category)
      : null;
  final activePet = state.activePet;
  final nextPoi = state.nextRecommendedPoi;
  final categories =
      state.todayVisitedCategories.map((category) => category.label).join(', ');
  final score = _reportScore(state);

  return [
    'MasilPet 오늘의 리포트',
    '성과 등급: ${_reportGrade(score)} · $score점',
    '성장 루프: ${_loopProgress(state)}/4',
    '방문 ${state.todayCheckInCount}곳 · 카테고리 ${state.todayVisitedCategoryCount}/7',
    '연속 산책: ${state.currentVisitStreakDays}일 · 최장 ${state.longestVisitStreakDays}일',
    '최근 장소: ${_placeLabel(state, latest)} '
        '(${latest.category.label}, ${latest.distanceMeters.round()}m)',
    if (categories.isNotEmpty) '기록한 분류: $categories',
    if (reward != null) '받은 보상: ${reward.summaryLabel}',
    if (activePet != null) '함께한 마실펫: ${activePet.name} Lv.${activePet.level}',
    if (nextPoi != null)
      '다음 추천: ${nextPoi.title} (${nextPoi.category.label}, '
          '${state.currentLocation.distanceTo(nextPoi.coordinates).round()}m)',
  ].join('\n');
}

int _reportScore(MasilPetState state) {
  var score = 0;
  if (state.todayCheckInCount > 0) {
    score += 28;
  }
  score += (state.todayVisitedCategoryCount * 8).clamp(0, 24).toInt();
  if (_dialogueCountToday(state) > 0) {
    score += 16;
  }
  if (state.activePet != null) {
    score += 12;
  }
  final nextEgg = state.nextEgg;
  if (nextEgg != null) {
    score += (nextEgg.progressRatio * 14).round().clamp(0, 14).toInt();
    if (nextEgg.status == EggStatus.hatchable) {
      score += 6;
    }
  }
  score += (state.currentVisitStreakDays.clamp(0, 3) * 4).toInt();
  return score.clamp(0, 100).toInt();
}

String _reportGrade(int score) {
  if (score >= 90) {
    return 'S';
  }
  if (score >= 72) {
    return 'A';
  }
  if (score >= 52) {
    return 'B';
  }
  return 'C';
}

int _loopProgress(MasilPetState state) {
  var progress = 0;
  if (state.todayCheckInCount > 0) {
    progress++;
  }
  if (state.activePet != null) {
    progress++;
  }
  if (state.eggs.isNotEmpty || state.pets.length > 1) {
    progress++;
  }
  if (_dialogueCountToday(state) > 0) {
    progress++;
  }
  return progress;
}

int _dialogueCountToday(MasilPetState state) {
  return isSameLocalDay(state.dialogueDay, DateTime.now())
      ? state.dialogueCountToday
      : 0;
}

int _daysSince(DateTime value) {
  final days = DateTime.now().difference(value).inDays;
  return days < 0 ? 0 : days;
}

String _relativeDayLabel(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(value.year, value.month, value.day);
  final difference = today.difference(day).inDays;
  final time = '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
  return switch (difference) {
    <= 0 => '오늘 · $time',
    1 => '어제 · $time',
    _ => '${_twoDigits(value.month)}.${_twoDigits(value.day)} · $time',
  };
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
