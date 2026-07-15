import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state.dart';
import '../widgets/pet_play_field.dart';

const double _onboardingWideBreakpoint = 820;

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final controller = ref.read(masilPetControllerProvider.notifier);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF8E7),
              Color(0xFFFFFDF8),
              Color(0xFFEAF8F1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide =
                        constraints.maxWidth >= _onboardingWideBreakpoint;
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        isWide ? 32 : 20,
                        isWide ? 30 : 18,
                        isWide ? 32 : 20,
                        24,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: _OnboardingHero(
                            state: state,
                            isWide: isWide,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _StartDock(
                isBusy: state.isBusy,
                onPressed: controller.completeOnboarding,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero({
    required this.state,
    required this.isWide,
  });

  final MasilPetState state;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final story = _StoryColumn(state: state, isWide: isWide);
    final preview = _PocketPreview(state: state, isWide: isWide);

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          story,
          const SizedBox(height: 24),
          preview,
          const SizedBox(height: 24),
          const _JourneyStrip(),
          const SizedBox(height: 18),
          _LocalFirstNote(
            connectionAvailable: state.firebaseReady,
            fallbackMessage: state.firebaseStartupIssue.fallbackMessage,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 9, child: story),
            const SizedBox(width: 52),
            Expanded(flex: 11, child: preview),
          ],
        ),
        const SizedBox(height: 32),
        const _JourneyStrip(),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.center,
          child: _LocalFirstNote(
            connectionAvailable: state.firebaseReady,
            fallbackMessage: state.firebaseStartupIssue.fallbackMessage,
          ),
        ),
      ],
    );
  }
}

class _StoryColumn extends StatelessWidget {
  const _StoryColumn({
    required this.state,
    required this.isWide,
  });

  final MasilPetState state;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BrandMark(),
        SizedBox(height: isWide ? 28 : 20),
        Text(
          '걷고, 만나고,\n함께 자라요',
          style: (isWide ? textTheme.displayMedium : textTheme.displaySmall)
              ?.copyWith(
            color: const Color(0xFF27332D),
            fontWeight: FontWeight.w900,
            height: 1.08,
            letterSpacing: -1.6,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '동네의 작은 발견이 새로운 친구와 추억이 되는 산책.\n오늘의 한 걸음부터 나만의 마실펫을 키워보세요.',
          style: textTheme.titleMedium?.copyWith(
            color: const Color(0xFF56635D),
            height: 1.55,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PromiseChip(
              icon: Icons.pets_rounded,
              label: '${state.templates.length}마리 친구',
            ),
            _PromiseChip(
              icon: Icons.directions_walk_rounded,
              label: '${state.pois.length}곳 산책지',
            ),
            const _PromiseChip(
              icon: Icons.auto_awesome_rounded,
              label: '매일 새로운 반응',
            ),
          ],
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD166),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF27332D), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF27332D),
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.pets_rounded,
            color: Color(0xFF27332D),
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MasilPet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF27332D),
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
            ),
            Text(
              '주머니 속 산책 친구',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF287A62),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PromiseChip extends StatelessWidget {
  const _PromiseChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFDCCFB2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF287A62)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF3C4943),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _PocketPreview extends StatelessWidget {
  const _PocketPreview({required this.state, required this.isWide});

  final MasilPetState state;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final activeName = state.activePet?.name ?? '마실펫';

    return Semantics(
      label: '$activeName과 함께하는 산책 미리보기',
      child: Container(
        padding: EdgeInsets.fromLTRB(
          isWide ? 18 : 14,
          isWide ? 16 : 13,
          isWide ? 18 : 14,
          isWide ? 18 : 15,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFAEE8D1), Color(0xFF8FD9C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFF27332D), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3327332D),
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
            BoxShadow(
              color: Color(0xFF287A62),
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF7A5C),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    activeName,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF27332D),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                const _LivePill(),
              ],
            ),
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF27332D),
                borderRadius: BorderRadius.circular(23),
              ),
              child: PetPlayField(
                templates: state.templates,
                pets: state.pets,
                eggs: state.eggs,
                activePetId: state.activePetId,
                activity: state.fieldActivity,
                activityNonce: state.fieldActivityNonce,
                height: isWide ? 318 : 230,
                spriteScale: 1.25,
                showVisitors: false,
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                const _SpeakerDots(),
                const Spacer(),
                for (final color in const [
                  Color(0xFFFFD166),
                  Color(0xFFFF8A5B),
                  Color(0xFFA9DFF3),
                ]) ...[
                  _ConsoleButton(color: color),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0x6627332D)),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Color(0xFF287A62),
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SpeakerDots extends StatelessWidget {
  const _SpeakerDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (index) => Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(right: 4),
          decoration: const BoxDecoration(
            color: Color(0x8827332D),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _ConsoleButton extends StatelessWidget {
  const _ConsoleButton({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF27332D), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0xFF27332D), offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

class _JourneyStrip extends StatelessWidget {
  const _JourneyStrip();

  @override
  Widget build(BuildContext context) {
    const steps = [
      _JourneyStepData(
        number: '01',
        icon: Icons.directions_walk_rounded,
        title: '동네를 걷고',
        body: '내 주변 산책지를 찾아요',
        color: Color(0xFFA9DFF3),
      ),
      _JourneyStepData(
        number: '02',
        icon: Icons.place_rounded,
        title: '장소를 만나고',
        body: '방문을 새로운 기억으로 남겨요',
        color: Color(0xFFFFD166),
      ),
      _JourneyStepData(
        number: '03',
        icon: Icons.pets_rounded,
        title: '함께 자라요',
        body: '대화하고 돌보며 진화해요',
        color: Color(0xFFAEE8D1),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: [
              for (var index = 0; index < steps.length; index++) ...[
                _JourneyCard(data: steps[index]),
                if (index != steps.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < steps.length; index++) ...[
              Expanded(child: _JourneyCard(data: steps[index])),
              if (index != steps.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.data});

  final _JourneyStepData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCCFB2), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1427332D),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: data.color,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0x4427332D)),
            ),
            child: Icon(data.icon, color: const Color(0xFF27332D), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.number}  ${data.title}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF27332D),
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF647169),
                        height: 1.35,
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

class _JourneyStepData {
  const _JourneyStepData({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final String number;
  final IconData icon;
  final String title;
  final String body;
  final Color color;
}

class _LocalFirstNote extends StatelessWidget {
  const _LocalFirstNote({
    required this.connectionAvailable,
    required this.fallbackMessage,
  });

  final bool connectionAvailable;
  final String fallbackMessage;

  @override
  Widget build(BuildContext context) {
    final usesLocalProgress =
        !connectionAvailable && fallbackMessage.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8F4),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFB8DECF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            usesLocalProgress
                ? Icons.shield_outlined
                : Icons.cloud_done_outlined,
            size: 17,
            color: const Color(0xFF287A62),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              usesLocalProgress
                  ? '연결이 없어도 오늘의 돌봄과 산책 기록은 안전하게 이어져요'
                  : '오늘의 돌봄과 산책 기록을 안전하게 이어가요',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF406054),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartDock extends StatelessWidget {
  const _StartDock({required this.isBusy, required this.onPressed});

  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8).withValues(alpha: 0.94),
        border: const Border(top: BorderSide(color: Color(0x33B9A987))),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1427332D),
            blurRadius: 20,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isBusy ? null : onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: const Color(0xFF287A62),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('첫 산책 시작하기'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
