import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state.dart';
import '../widgets/responsive_sliver_list.dart';
import '../widgets/status_banner.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(title: Text('내 정보')),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: ResponsiveSliverList(
            children: [
              const StatusBanner(),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        label: '실행 모드',
                        value: state.firebaseReady ? 'Firebase 준비' : '데모 모드',
                      ),
                      _InfoRow(label: '첫 탐험 지역', value: state.region.name),
                      _InfoRow(label: '오늘 체크인', value: '${state.todayCheckInCount}회'),
                      _InfoRow(label: '보유 마실펫', value: '${state.pets.length}종'),
                      _InfoRow(label: '보유 알', value: '${state.eggs.length}개'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: state.isBusy ? null : controller.useDeviceLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('현재 위치 사용'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: controller.useDemoBusanLocation,
                icon: const Icon(Icons.location_city_outlined),
                label: const Text('해운대 데모 위치로 이동'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => controller.addStepProgress(1000),
                icon: const Icon(Icons.directions_walk),
                label: const Text('1000걸음 반영'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: state.isBusy ? null : controller.seedRemoteStarterRegionData,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('서버 시드 준비'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: state.isBusy ? null : controller.ensureRemoteUserBootstrap,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('서버 사용자 초기화'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: state.isBusy ? null : () => controller.refreshRemoteProgress(),
                icon: const Icon(Icons.cloud_sync_outlined),
                label: const Text('서버 진행도 불러오기'),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '계정 연동',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text('MVP는 Firebase 익명 인증을 기본값으로 사용합니다. 카카오/애플/구글 연동은 다음 단계에서 붙입니다.'),
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
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
