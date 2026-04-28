import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state.dart';
import '../widgets/pet_play_field.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(masilPetControllerProvider.notifier);
    final state = ref.watch(masilPetControllerProvider);
    final firebaseReady = ref.watch(
      masilPetControllerProvider.select((state) => state.firebaseReady),
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 780;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: isWide ? 28 : 12),
                      Text(
                        'MasilPet',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '부산을 걸으며 만나는 나만의 마실펫',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 18),
                      PetPlayField(
                        templates: state.templates,
                        pets: state.pets,
                        eggs: state.eggs,
                        activePetId: state.activePetId,
                        activity: state.fieldActivity,
                        activityNonce: state.fieldActivityNonce,
                        height: isWide ? 300 : 230,
                      ),
                      const SizedBox(height: 18),
                      _OnboardingPoint(
                        icon: Icons.map_outlined,
                        title: 'TourAPI 기반 지역 탐험',
                        body: '부산 POI를 카테고리별로 방문하고 체크인합니다.',
                      ),
                      const SizedBox(height: 12),
                      _OnboardingPoint(
                        icon: Icons.egg_alt_outlined,
                        title: '알 수집과 부화',
                        body: '체크인 보상과 걸음 수가 알 부화 진행도로 이어집니다.',
                      ),
                      const SizedBox(height: 12),
                      _OnboardingPoint(
                        icon: Icons.forum_outlined,
                        title: '고정 대사 기반 교감',
                        body: 'MVP에서는 비용 없이 상황별 대사로 펫과 대화합니다.',
                      ),
                      const SizedBox(height: 24),
                      Text(
                        firebaseReady
                            ? 'Firebase 연결 준비 완료'
                            : 'Firebase 미설정 상태라 데모 모드로 실행됩니다.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: controller.completeOnboarding,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('마실펫 시작'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingPoint extends StatelessWidget {
  const _OnboardingPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
