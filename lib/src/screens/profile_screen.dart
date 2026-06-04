import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_build_info.dart';
import '../services/privacy_navigation.dart';
import '../state.dart';
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
            primaryCount: 5,
            secondaryStartIndex: 6,
            children: [
              const StatusBanner(),
              const SizedBox(height: 12),
              _LaunchReadinessCard(state: state),
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
              _ProfileActionsCard(
                useDeviceLocation:
                    state.isBusy ? null : controller.useDeviceLocation,
                useStarterLocation:
                    state.isBusy ? null : controller.useStarterBusanLocation,
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

class _ProfileActionsCard extends StatelessWidget {
  const _ProfileActionsCard({
    required this.useDeviceLocation,
    required this.useStarterLocation,
    required this.ensureRemoteUserBootstrap,
    required this.refreshRemoteProgress,
  });

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
                final stackButtons = constraints.maxWidth < 300;
                final starterButton = OutlinedButton.icon(
                  onPressed: useStarterLocation,
                  icon: const Icon(Icons.location_city_outlined),
                  label: const Text('해운대 지도 보기'),
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

class _LaunchReadinessCard extends StatelessWidget {
  const _LaunchReadinessCard({required this.state});

  final MasilPetState state;

  @override
  Widget build(BuildContext context) {
    final score = state.launchReadinessScore;

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
          ],
        ),
      ),
    );
  }
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
