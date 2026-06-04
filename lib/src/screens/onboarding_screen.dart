import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state.dart';
import '../widgets/pet_play_field.dart';

const double _onboardingWideBreakpoint = 780.0;

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(masilPetControllerProvider.notifier);
    final state = ref.watch(masilPetControllerProvider);

    return Scaffold(
      bottomNavigationBar: _OnboardingStartAction(
        onPressed: controller.completeOnboarding,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _onboardingWideBreakpoint;
            final intro = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MasilPet',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  '부산을 걸으며 만나는 나만의 마실펫',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '실제 위치 체크인, TourAPI 지역 데이터, Firebase 진행도 동기화를 연결한 지역 탐험형 펫 성장 앱입니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
            final playField = PetPlayField(
              templates: state.templates,
              pets: state.pets,
              eggs: state.eggs,
              activePetId: state.activePetId,
              activity: state.fieldActivity,
              activityNonce: state.fieldActivityNonce,
              height: isWide ? 300 : 230,
            );
            final metrics = Row(
              children: [
                Expanded(
                  child: _IntroMetric(
                    value: '${state.pois.length}',
                    label: '부산 POI',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _IntroMetric(
                    value: '${state.templates.length}',
                    label: '마실펫',
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: _IntroMetric(
                    value: '150m',
                    label: '체크인 반경',
                  ),
                ),
              ],
            );
            const featurePoints = Column(
              children: [
                _OnboardingPoint(
                  icon: Icons.map_outlined,
                  title: 'TourAPI 기반 지역 탐험',
                  body: '현재 위치 확인 후 부산 POI를 카테고리별로 방문하고 체크인합니다.',
                ),
                SizedBox(height: 12),
                _OnboardingPoint(
                  icon: Icons.egg_alt_outlined,
                  title: '알 수집과 부화',
                  body: '체크인 보상과 지역 방문 기록이 알 부화 진행도로 이어집니다.',
                ),
                SizedBox(height: 12),
                _OnboardingPoint(
                  icon: Icons.forum_outlined,
                  title: '장소 맥락 기반 교감',
                  body: '방문한 장소에 맞춘 상황별 대사로 펫과 대화합니다.',
                ),
              ],
            );
            final connectionStatus = Text(
              state.firebaseReady
                  ? 'Firebase 연결 준비 완료'
                  : state.firebaseStartupIssue.fallbackMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            );
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _OnboardingAdaptiveLayout(
                        isWide: isWide,
                        topSpacing: SizedBox(height: isWide ? 28 : 12),
                        intro: intro,
                        playField: playField,
                        metrics: metrics,
                        featurePoints: featurePoints,
                        connectionStatus: connectionStatus,
                      ),
                    ),
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

class _OnboardingStartAction extends StatelessWidget {
  const _OnboardingStartAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _onboardingWideBreakpoint;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 420 : 1040,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('마실펫 시작'),
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

class _OnboardingAdaptiveLayout extends StatelessWidget {
  const _OnboardingAdaptiveLayout({
    required this.isWide,
    required this.topSpacing,
    required this.intro,
    required this.playField,
    required this.metrics,
    required this.featurePoints,
    required this.connectionStatus,
  });

  final bool isWide;
  final Widget topSpacing;
  final Widget intro;
  final Widget playField;
  final Widget metrics;
  final Widget featurePoints;
  final Widget connectionStatus;

  @override
  Widget build(BuildContext context) {
    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          topSpacing,
          intro,
          const SizedBox(height: 18),
          playField,
          const SizedBox(height: 18),
          metrics,
          const SizedBox(height: 18),
          featurePoints,
          const SizedBox(height: 24),
          connectionStatus,
          const SizedBox(height: 24),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        topSpacing,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  intro,
                  const SizedBox(height: 18),
                  metrics,
                  const SizedBox(height: 24),
                  connectionStatus,
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  playField,
                  const SizedBox(height: 18),
                  featurePoints,
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _IntroMetric extends StatelessWidget {
  const _IntroMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
