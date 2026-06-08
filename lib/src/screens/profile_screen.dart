import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../app_build_info.dart';
import '../models.dart';
import '../services.dart';
import '../services/privacy_navigation.dart';
import '../state.dart';
import '../widgets/reward_chip_row.dart';
import '../widgets/status_banner.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);
    final onlineActionEnabled = state.firebaseReady && !state.isBusy;
    const buildInfo = appBuildInfo;

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('내 정보')),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: _ProfileAdaptiveSliverList(
            primaryCount: 11,
            secondaryStartIndex: 12,
            children: [
              const StatusBanner(),
              const SizedBox(height: 12),
              _LaunchReadinessCard(state: state),
              const SizedBox(height: 12),
              _ExpeditionReportCard(
                state: state,
                onOpenMap: state.isBusy ? null : () => controller.setTab(0),
                onOpenPet: state.isBusy ? null : () => controller.setTab(1),
              ),
              const SizedBox(height: 12),
              _JourneyBadgeCard(
                state: state,
                onOpenMap: state.isBusy ? null : () => controller.setTab(0),
                onOpenPet: state.isBusy ? null : () => controller.setTab(1),
                onOpenHouse: state.isBusy ? null : () => controller.setTab(2),
                onOpenDex: state.isBusy ? null : () => controller.setTab(3),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        label: '실행 모드',
                        value: state.firebaseConnectionLabel,
                      ),
                      _InfoRow(
                        label: '앱 버전',
                        value: buildInfo.versionLabel,
                      ),
                      _InfoRow(
                        label: '빌드 채널',
                        value: buildInfo.channelLabel,
                      ),
                      _InfoRow(
                        label: '빌드 시각',
                        value: buildInfo.buildTimeLabel,
                      ),
                      _InfoRow(label: '첫 탐험 지역', value: state.region.name),
                      _InfoRow(
                        label: '위치 상태',
                        value:
                            state.hasFreshVerifiedLocation ? '확인 완료' : '확인 필요',
                      ),
                      _InfoRow(
                          label: '오늘 체크인',
                          value: '${state.todayCheckInCount}회'),
                      _InfoRow(label: '보유 마실펫', value: '${state.pets.length}종'),
                      _InfoRow(label: '보유 알', value: '${state.eggs.length}개'),
                      _InfoRow(
                        label: '도감 수집률',
                        value: '${(state.dexCompletionRatio * 100).round()}%',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _VisitJournalCard(
                state: state,
                onOpenMap: state.isBusy ? null : () => controller.setTab(0),
              ),
              const SizedBox(height: 12),
              _ProfileActionsCard(
                firebaseReady: state.firebaseReady,
                useDeviceLocation:
                    state.isBusy ? null : controller.useDeviceLocation,
                useStarterLocation:
                    state.isBusy ? null : controller.useStarterKoreaLocation,
                ensureRemoteUserBootstrap: onlineActionEnabled
                    ? controller.ensureRemoteUserBootstrap
                    : null,
                refreshRemoteProgress: onlineActionEnabled
                    ? () => controller.refreshRemoteProgress()
                    : null,
              ),
              const SizedBox(height: 16),
              const _PrivacyCard(),
              const SizedBox(height: 12),
              const _DataSourceCard(),
              const SizedBox(height: 12),
              _ProgressManagementCard(
                state: state,
                onReset: () => _confirmResetProgress(
                  context: context,
                  controller: controller,
                  includeRemote: state.firebaseReady,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '계정 연동',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                          'Firebase 익명 인증으로 즉시 시작하고, Firestore와 Functions로 체크인·부화·교감 진행도를 동기화합니다.'),
                    ],
                  ),
                ),
              ),
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
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: scheme.error,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('진행도 초기화')),
            ],
          ),
          content: Text(
            includeRemote
                ? '기기 내 진행과 온라인 진행도를 초기화합니다. 이 작업은 되돌릴 수 없습니다.'
                : '기기 내 진행을 초기화합니다. 이 작업은 되돌릴 수 없습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              child: const Text('초기화'),
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

class _JourneyBadgeCard extends StatelessWidget {
  const _JourneyBadgeCard({
    required this.state,
    required this.onOpenMap,
    required this.onOpenPet,
    required this.onOpenHouse,
    required this.onOpenDex,
  });

  final MasilPetState state;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenPet;
  final VoidCallback? onOpenHouse;
  final VoidCallback? onOpenDex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badges = _journeyBadges(
      state: state,
      onOpenMap: onOpenMap,
      onOpenPet: onOpenPet,
      onOpenHouse: onOpenHouse,
    );
    final unlocked = badges.where((badge) => badge.unlocked).length;
    final nextBadge = _nextLockedJourneyBadge(badges);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '탐험 배지',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '$unlocked/${badges.length}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _journeyBadgeSummary(state, nextBadge),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 560 ? 1 : 2;
                const spacing = 8.0;
                final itemWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final badge in badges)
                      SizedBox(
                        width: itemWidth,
                        child: _JourneyBadgeTile(badge: badge),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (nextBadge == null)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: onOpenDex,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('전국 도감 보기'),
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: nextBadge.onAction,
                  icon: Icon(nextBadge.actionIcon),
                  label: Text(nextBadge.actionLabel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JourneyBadge {
  const _JourneyBadge({
    required this.icon,
    required this.title,
    required this.body,
    required this.progressLabel,
    required this.progress,
    required this.unlocked,
    required this.color,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String progressLabel;
  final double progress;
  final bool unlocked;
  final Color color;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback? onAction;
}

class _JourneyBadgeTile extends StatelessWidget {
  const _JourneyBadgeTile({required this.badge});

  final _JourneyBadge badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mutedColor = scheme.onSurfaceVariant;
    final color = badge.unlocked ? badge.color : mutedColor;

    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badge.unlocked
            ? badge.color.withValues(alpha: 0.1)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: badge.unlocked
              ? badge.color.withValues(alpha: 0.34)
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: badge.unlocked ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(badge.icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badge.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                badge.unlocked
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 18,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: badge.progress.clamp(0.0, 1.0),
                    color: badge.color,
                    backgroundColor: scheme.surface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                badge.progressLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

List<_JourneyBadge> _journeyBadges({
  required MasilPetState state,
  required VoidCallback? onOpenMap,
  required VoidCallback? onOpenPet,
  required VoidCallback? onOpenHouse,
}) {
  final dialogueCountToday = _dialogueCountToday(state);
  final nextEgg = state.nextEgg;
  final eggProgress = nextEgg?.progressRatio ?? 0;
  final hasHatchReady = state.hatchableEggCount > 0 || state.pets.length > 1;

  return [
    _JourneyBadge(
      icon: Icons.pets_outlined,
      title: '동행 시작',
      body: state.pets.isEmpty
          ? '첫 마실펫을 만나면 탐험 동행이 열립니다.'
          : '${state.activePet?.name ?? '마실펫'}과 함께 출발했습니다.',
      progressLabel: state.pets.isEmpty ? '0/1' : '1/1',
      progress: state.pets.isEmpty ? 0 : 1,
      unlocked: state.pets.isNotEmpty,
      color: const Color(0xFF0F766E),
      actionIcon: Icons.home_outlined,
      actionLabel: '하우스 보기',
      onAction: onOpenHouse,
    ),
    _JourneyBadge(
      icon: Icons.my_location,
      title: '위치 인증',
      body: state.hasFreshVerifiedLocation
          ? '체크인 반경 계산이 준비됐습니다.'
          : '현재 위치나 기본 체험 위치를 확인하세요.',
      progressLabel: state.hasFreshVerifiedLocation ? '1/1' : '0/1',
      progress: state.hasFreshVerifiedLocation ? 1 : 0,
      unlocked: state.hasFreshVerifiedLocation,
      color: const Color(0xFF2563EB),
      actionIcon: Icons.map_outlined,
      actionLabel: '위치 확인하러 가기',
      onAction: onOpenMap,
    ),
    _JourneyBadge(
      icon: Icons.flag_outlined,
      title: '첫 발자국',
      body: state.todayCheckInCount > 0
          ? '오늘 첫 장소 방문이 기록됐습니다.'
          : '150m 안의 장소에 체크인하면 열립니다.',
      progressLabel: '${state.todayCheckInCount.clamp(0, 1)}/1',
      progress: state.todayCheckInCount > 0 ? 1 : 0,
      unlocked: state.todayCheckInCount > 0,
      color: const Color(0xFFB45309),
      actionIcon: Icons.place_outlined,
      actionLabel: '지도에서 체크인하기',
      onAction: onOpenMap,
    ),
    _JourneyBadge(
      icon: Icons.forum_outlined,
      title: '장소 이야기꾼',
      body: dialogueCountToday > 0
          ? '방문한 장소 이야기를 마실펫에게 들려줬습니다.'
          : '체크인 후 마실펫과 장소 맥락 대화를 나누세요.',
      progressLabel: '${dialogueCountToday.clamp(0, 1)}/1',
      progress: dialogueCountToday > 0 ? 1 : 0,
      unlocked: dialogueCountToday > 0,
      color: const Color(0xFF7C3AED),
      actionIcon: Icons.pets_outlined,
      actionLabel: '마실펫과 대화하기',
      onAction: onOpenPet,
    ),
    _JourneyBadge(
      icon: Icons.egg_alt_outlined,
      title: '부화 준비',
      body: hasHatchReady
          ? '새 마실펫을 맞이할 준비가 됐습니다.'
          : nextEgg == null
              ? '체크인 보상으로 알을 발견해 보세요.'
              : '${(nextEgg.progressRatio * 100).round()}%까지 부화 진행도가 쌓였습니다.',
      progressLabel: hasHatchReady
          ? '완료'
          : nextEgg == null
              ? '0%'
              : '${(nextEgg.progressRatio * 100).round()}%',
      progress: hasHatchReady ? 1 : eggProgress,
      unlocked: hasHatchReady,
      color: const Color(0xFFDB2777),
      actionIcon: Icons.home_outlined,
      actionLabel: nextEgg == null ? '지도에서 알 찾기' : '하우스에서 알 보기',
      onAction: nextEgg == null ? onOpenMap : onOpenHouse,
    ),
  ];
}

_JourneyBadge? _nextLockedJourneyBadge(List<_JourneyBadge> badges) {
  for (final badge in badges) {
    if (!badge.unlocked) {
      return badge;
    }
  }
  return null;
}

String _journeyBadgeSummary(MasilPetState state, _JourneyBadge? nextBadge) {
  if (nextBadge == null) {
    return '오늘 핵심 탐험 배지가 모두 열렸습니다. 도감에서 다음 지역 목표를 이어갈 수 있습니다.';
  }
  if (state.todayCheckInCount == 0 && !state.hasFreshVerifiedLocation) {
    return '짧은 체험 안에서도 위치 확인, 체크인, 교감, 부화 준비까지의 성취가 배지로 쌓입니다.';
  }
  return '다음 목표는 ${nextBadge.title}입니다. ${nextBadge.body}';
}

int _dialogueCountToday(MasilPetState state) {
  return isSameLocalDay(state.dialogueDay, DateTime.now())
      ? state.dialogueCountToday
      : 0;
}

class _ExpeditionReportCard extends StatelessWidget {
  const _ExpeditionReportCard({
    required this.state,
    required this.onOpenMap,
    required this.onOpenPet,
  });

  final MasilPetState state;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenPet;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latestCheckIn = _latestTodayCheckIn(state);
    final poi =
        latestCheckIn == null ? null : _poiForCheckIn(state, latestCheckIn);
    final reward = latestCheckIn?.rewardApplied == true
        ? latestCheckIn?.reward ??
            const GrowthEngine().rewardFor(latestCheckIn!.category)
        : null;
    final activePet = state.activePet;
    final nextPoi = state.nextRecommendedPoi;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '오늘의 탐험 리포트',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (latestCheckIn == null) ...[
              Text(
                '첫 장소를 기록하면 오늘의 방문 장소, 보상, 함께한 마실펫이 한 장의 리포트로 정리됩니다.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('첫 리포트 만들기'),
                ),
              ),
            ] else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ReportStatPill(
                    icon: Icons.flag_outlined,
                    label: '오늘 방문',
                    value: '${state.todayCheckInCount}곳',
                  ),
                  _ReportStatPill(
                    icon: Icons.category_outlined,
                    label: '카테고리',
                    value: '${state.todayVisitedCategoryCount}/7',
                  ),
                  _ReportStatPill(
                    icon: Icons.pets_outlined,
                    label: '함께한 펫',
                    value: activePet?.name ?? '준비 중',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ReportDetailRow(
                icon: Icons.place_outlined,
                title: poi?.title ?? '저장된 방문 장소',
                body:
                    '${latestCheckIn.category.label} · ${latestCheckIn.distanceMeters.round()}m',
              ),
              if (reward != null) ...[
                const SizedBox(height: 8),
                _ReportDetailRow(
                  icon: Icons.card_giftcard_outlined,
                  title: '받은 보상',
                  body: reward.summaryLabel,
                ),
              ],
              if (nextPoi != null) ...[
                const SizedBox(height: 8),
                _ReportDetailRow(
                  icon: Icons.near_me_outlined,
                  title: '다음 추천',
                  body:
                      '${nextPoi.title} · ${nextPoi.category.label} · ${state.currentLocation.distanceTo(nextPoi.coordinates).round()}m',
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      _copyExpeditionReport(context, state);
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('요약 복사'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenPet,
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text('마실펫에게 들려주기'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportStatPill extends StatelessWidget {
  const _ReportStatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: scheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
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

Future<void> _copyExpeditionReport(
  BuildContext context,
  MasilPetState state,
) async {
  await Clipboard.setData(
    ClipboardData(text: _expeditionReportText(state)),
  );
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('오늘의 탐험 리포트를 복사했습니다.')),
  );
}

String _expeditionReportText(MasilPetState state) {
  final latestCheckIn = _latestTodayCheckIn(state);
  if (latestCheckIn == null) {
    return 'MasilPet 오늘의 탐험 리포트\n아직 오늘의 체크인이 없습니다. 지도에서 첫 장소를 기록해 보세요.';
  }

  final poi = _poiForCheckIn(state, latestCheckIn);
  final reward = latestCheckIn.rewardApplied
      ? latestCheckIn.reward ??
          const GrowthEngine().rewardFor(latestCheckIn.category)
      : null;
  final activePet = state.activePet;
  final nextPoi = state.nextRecommendedPoi;
  final categories =
      state.todayVisitedCategories.map((category) => category.label).join(', ');

  return [
    'MasilPet 오늘의 탐험 리포트',
    '방문 ${state.todayCheckInCount}곳 · 카테고리 ${state.todayVisitedCategoryCount}/7',
    '최근 장소: ${poi?.title ?? '저장된 방문 장소'} (${latestCheckIn.category.label}, ${latestCheckIn.distanceMeters.round()}m)',
    if (categories.isNotEmpty) '기록한 카테고리: $categories',
    if (reward != null) '받은 보상: ${reward.summaryLabel}',
    if (activePet != null) '함께한 마실펫: ${activePet.name} Lv.${activePet.level}',
    if (nextPoi != null)
      '다음 추천: ${nextPoi.title} (${nextPoi.category.label}, ${state.currentLocation.distanceTo(nextPoi.coordinates).round()}m)',
  ].join('\n');
}

CheckIn? _latestTodayCheckIn(MasilPetState state) {
  final today = [...state.todayCheckIns];
  if (today.isEmpty) {
    return null;
  }
  today.sort((left, right) => right.createdAt.compareTo(left.createdAt));
  return today.first;
}

Poi? _poiForCheckIn(MasilPetState state, CheckIn checkIn) {
  for (final poi in state.pois) {
    if (poi.id == checkIn.poiId) {
      return poi;
    }
  }
  return null;
}

class _ReportDetailRow extends StatelessWidget {
  const _ReportDetailRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
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
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileAdaptiveSliverList extends StatelessWidget {
  const _ProfileAdaptiveSliverList({
    required this.children,
    required this.primaryCount,
    required this.secondaryStartIndex,
  });

  static const double _wideBreakpoint = 840.0;

  final List<Widget> children;
  final int primaryCount;
  final int secondaryStartIndex;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < _wideBreakpoint) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children.take(primaryCount).toList(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children.skip(secondaryStartIndex).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VisitJournalCard extends StatelessWidget {
  const _VisitJournalCard({
    required this.state,
    required this.onOpenMap,
  });

  final MasilPetState state;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final recent = state.recentCheckIns.take(3).toList();
    final poiById = {for (final poi in state.pois) poi.id: poi};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '방문 기록',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '${state.checkIns.length}회',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (recent.isEmpty) ...[
              Text(
                '아직 기록된 체크인이 없습니다. 지도에서 첫 장소를 방문하면 여기에 여정이 쌓입니다.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('지도에서 체크인하기'),
                ),
              ),
            ] else ...[
              for (final (index, checkIn) in recent.indexed) ...[
                _VisitJournalTile(
                  checkIn: checkIn,
                  poi: poiById[checkIn.poiId],
                ),
                if (index < recent.length - 1)
                  const Divider(height: 18, thickness: 1),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _VisitJournalTile extends StatelessWidget {
  const _VisitJournalTile({
    required this.checkIn,
    required this.poi,
  });

  final CheckIn checkIn;
  final Poi? poi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = poi?.title ?? '저장된 방문 장소';
    final reward = checkIn.rewardApplied
        ? checkIn.reward ?? const GrowthEngine().rewardFor(checkIn.category)
        : null;
    final description = [
      _formatVisitTime(checkIn.createdAt),
      '${checkIn.distanceMeters.round()}m',
      if (checkIn.rewardApplied) '보상 적용',
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color:
                _journalCategoryColor(checkIn.category).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _journalCategoryIcon(checkIn.category),
            color: _journalCategoryColor(checkIn.category),
            size: 19,
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
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _JournalCategoryPill(category: checkIn.category),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              if (reward != null) ...[
                const SizedBox(height: 8),
                RewardChipRow(reward: reward),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _JournalCategoryPill extends StatelessWidget {
  const _JournalCategoryPill({required this.category});

  final PoiCategory category;

  @override
  Widget build(BuildContext context) {
    final color = _journalCategoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

IconData _journalCategoryIcon(PoiCategory category) {
  return switch (category) {
    PoiCategory.nature => Icons.park_outlined,
    PoiCategory.food => Icons.restaurant_outlined,
    PoiCategory.festival => Icons.celebration_outlined,
    PoiCategory.culture => Icons.theater_comedy_outlined,
    PoiCategory.history => Icons.account_balance_outlined,
    PoiCategory.shopping => Icons.storefront_outlined,
    PoiCategory.other => Icons.place_outlined,
  };
}

Color _journalCategoryColor(PoiCategory category) {
  return switch (category) {
    PoiCategory.nature => const Color(0xFF0F766E),
    PoiCategory.food => const Color(0xFFF97316),
    PoiCategory.festival => const Color(0xFFDB2777),
    PoiCategory.culture => const Color(0xFF2563EB),
    PoiCategory.history => const Color(0xFF7C3AED),
    PoiCategory.shopping => const Color(0xFFB45309),
    PoiCategory.other => const Color(0xFF64748B),
  };
}

String _formatVisitTime(DateTime value) {
  final now = DateTime.now();
  final local = value.toLocal();
  final time = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  if (isSameLocalDay(local, now)) {
    return '오늘 $time';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (isSameLocalDay(local, yesterday)) {
    return '어제 $time';
  }
  return '${local.month}월 ${local.day}일 $time';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class _ProfileActionsCard extends StatelessWidget {
  const _ProfileActionsCard({
    required this.firebaseReady,
    required this.useDeviceLocation,
    required this.useStarterLocation,
    required this.ensureRemoteUserBootstrap,
    required this.refreshRemoteProgress,
  });

  final bool firebaseReady;
  final VoidCallback? useDeviceLocation;
  final VoidCallback? useStarterLocation;
  final VoidCallback? ensureRemoteUserBootstrap;
  final VoidCallback? refreshRemoteProgress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '빠른 작업',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: useDeviceLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('현재 위치 사용'),
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackButtons = constraints.maxWidth < 360;
                final starterButton = OutlinedButton.icon(
                  onPressed: useStarterLocation,
                  icon: const Icon(Icons.location_city_outlined),
                  label: Text(
                    firebaseReady ? '전국 기본 지도 보기' : '기본 위치로 체험',
                  ),
                );
                final refreshButton = OutlinedButton.icon(
                  onPressed: refreshRemoteProgress,
                  icon: const Icon(Icons.cloud_sync_outlined),
                  label: const Text('새로고침'),
                );

                if (stackButtons) {
                  return Column(
                    children: [
                      SizedBox(width: double.infinity, child: starterButton),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: refreshButton),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: starterButton),
                    const SizedBox(width: 8),
                    Expanded(child: refreshButton),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: ensureRemoteUserBootstrap,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('계정 상태 확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '위치·개인정보 보호',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '현재 위치는 주변 장소 조회와 150m 체크인 판정에 사용됩니다. 체크인은 최근 15분 안에 확인한 위치에서만 가능하며, 체크인·부화·성장 기록은 Functions를 거쳐 저장합니다.',
            ),
            const SizedBox(height: 8),
            Text(
              '개인정보 처리방침: /privacy.html',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openPrivacyPolicy(context),
                icon: const Icon(Icons.open_in_new),
                label: const Text('개인정보 처리방침 열기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await openPrivacyPolicyPage();
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('개인정보 처리방침을 열 수 없습니다.')),
      );
    }
  }
}

class _DataSourceCard extends StatelessWidget {
  const _DataSourceCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dataset_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '데이터·지도 출처',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _SourceRow(
              icon: Icons.travel_explore_outlined,
              title: 'TourAPI 지역 장소',
              detail: '전국 POI와 카테고리를 운영자 동기화로 반영합니다.',
            ),
            const SizedBox(height: 8),
            const _SourceRow(
              icon: Icons.map_outlined,
              title: 'OpenStreetMap 지도',
              detail: '지도 타일과 저작권 고지는 지도 화면에 표시됩니다.',
            ),
            const SizedBox(height: 8),
            _SourceRow(
              icon: Icons.layers_outlined,
              title: '지도 타일 설정',
              detail:
                  '${mapTileBuildConfig.providerLabel} · 요청 식별자 ${mapTileBuildConfig.userAgentLabel}',
            ),
            const SizedBox(height: 8),
            const _SourceRow(
              icon: Icons.verified_user_outlined,
              title: 'Firebase Functions 검증',
              detail: '150m 체크인, 중복 방지, 보상 지급을 서버에서 처리합니다.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: scheme.primary, size: 18),
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
                detail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressManagementCard extends StatelessWidget {
  const _ProgressManagementCard({
    required this.state,
    required this.onReset,
  });

  final MasilPetState state;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.manage_accounts_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '진행도 관리',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              state.firebaseReady
                  ? '초기화하면 기기 내 진행과 온라인 진행도를 함께 지웁니다.'
                  : '현재는 기기 내 진행만 초기화할 수 있습니다.',
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: state.isBusy ? null : onReset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(
                    color: scheme.error.withValues(alpha: 0.72),
                  ),
                ),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('진행도 초기화'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaunchReadinessCard extends ConsumerWidget {
  const _LaunchReadinessCard({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = state.launchReadinessScore;
    final controller = ref.read(masilPetControllerProvider.notifier);
    final coreLoopCount = _readinessCoreLoopCount(state);
    final nextAction = _readinessNextAction(state, controller);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.rocket_launch_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '탐험 준비 상태',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '$score%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: score / 100,
                backgroundColor: const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(height: 12),
            _ReadinessSummaryLine(
              icon: Icons.route_outlined,
              label: '오늘의 탐험 루프',
              value: '$coreLoopCount/3단계',
              passed: coreLoopCount == 3,
            ),
            const SizedBox(height: 6),
            _ReadinessSummaryLine(
              icon: state.firebaseReady
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              label: '배포 동기화',
              value: state.firebaseReady
                  ? '연결 완료'
                  : state.firebaseStartupIssue.profileLabel,
              passed: state.firebaseReady,
            ),
            const SizedBox(height: 10),
            Text(
              _readinessSummaryText(state, coreLoopCount),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF475569),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ReadinessChip(
                  passed: state.firebaseReady,
                  label: '온라인 동기화',
                ),
                _ReadinessChip(
                  passed: state.todayCheckInCount > 0,
                  label: '체크인 기록',
                ),
                _ReadinessChip(
                  passed: state.pets.isNotEmpty,
                  label: '펫 보유',
                ),
                _ReadinessChip(
                  passed: state.eggs.isNotEmpty || state.pets.length > 1,
                  label: '부화 루프',
                ),
              ],
            ),
            if (nextAction != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: state.isBusy ? null : nextAction.onPressed,
                  icon: Icon(nextAction.icon),
                  label: Text(nextAction.label),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadinessSummaryLine extends StatelessWidget {
  const _ReadinessSummaryLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.passed,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final color = passed ? const Color(0xFF16A34A) : const Color(0xFF64748B);
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 4,
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadinessAction {
  const _ReadinessAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

int _readinessCoreLoopCount(MasilPetState state) {
  var count = 0;
  if (state.todayCheckInCount > 0) {
    count++;
  }
  if (state.pets.isNotEmpty) {
    count++;
  }
  if (state.eggs.isNotEmpty || state.pets.length > 1) {
    count++;
  }
  return count;
}

String _readinessSummaryText(MasilPetState state, int coreLoopCount) {
  if (state.firebaseReady && coreLoopCount == 3) {
    return '온라인 저장까지 연결되어 오늘의 탐험 기록이 안정적으로 이어집니다.';
  }
  if (!state.firebaseReady && coreLoopCount == 3) {
    return '체크인·펫 보유·부화 루프가 기기 내 진행으로 이어지고 있습니다.';
  }
  if (coreLoopCount >= 2) {
    return '남은 체크포인트를 따라가면 오늘의 탐험 루프를 완성할 수 있습니다.';
  }
  return '지도 체크인부터 시작하면 핵심 탐험 루프가 순서대로 열립니다.';
}

_ReadinessAction? _readinessNextAction(
  MasilPetState state,
  MasilPetController controller,
) {
  if (state.todayCheckInCount == 0) {
    return _ReadinessAction(
      icon: Icons.map_outlined,
      label: '지도에서 체크인하기',
      onPressed: () => controller.setTab(0),
    );
  }

  if (state.pets.isEmpty) {
    return _ReadinessAction(
      icon: Icons.home_outlined,
      label: '하우스에서 알 보기',
      onPressed: () => controller.setTab(2),
    );
  }

  final hasTalkedToday = _dialogueCountToday(state) > 0;
  if (!hasTalkedToday) {
    return _ReadinessAction(
      icon: Icons.forum_outlined,
      label: '마실펫 돌보기',
      onPressed: () => controller.setTab(1),
    );
  }

  return null;
}

class _ReadinessChip extends StatelessWidget {
  const _ReadinessChip({
    required this.passed,
    required this.label,
  });

  final bool passed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = passed ? const Color(0xFF16A34A) : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
