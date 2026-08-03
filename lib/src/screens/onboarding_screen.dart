import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../pet_assets.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/paper_kit.dart';

/// Three pages: meet your pet, learn the loop, hand over location.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 3;

  int _step = 0;

  void _next(VoidCallback complete) {
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      return;
    }
    complete();
  }

  /// Walking the story backwards, from the dock button, a dot, or the system
  /// back gesture. Page 0 has nowhere to go, so it stays put.
  void _goTo(int step) {
    final target = step.clamp(0, _stepCount - 1);
    if (target == _step) {
      return;
    }
    setState(() => _step = target);
  }

  @override
  Widget build(BuildContext context) {
    final (
      firebaseStartupIssue,
      firebaseReady,
      templates,
      isBusy,
      activeTemplateId
    ) = ref.watch(
      masilPetControllerProvider.select(
        (state) => (
          state.firebaseStartupIssue,
          state.firebaseReady,
          state.templates,
          state.isBusy,
          state.activePet?.templateId,
        ),
      ),
    );
    final controller = ref.read(masilPetControllerProvider.notifier);

    final template = _onboardingTemplate(templates, activeTemplateId);
    final petName = template?.name ?? '마실펫';
    final fallbackMessage = firebaseStartupIssue.fallbackMessage;
    final localOnlyNote = firebaseReady ? null : fallbackMessage;
    final ctaLabels = [
      '${petCallName(petName)} 만나기',
      '좋아, 알겠어',
      '허용하고 시작하기',
    ];

    return PopScope(
      // The story owns the back gesture until the reader is on page one; only
      // then does back mean "leave the app".
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goTo(_step - 1);
        }
      },
      child: Scaffold(
        backgroundColor: MasilPetPalette.canvas,
        body: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        // The story scrolls; the dock never leaves the screen,
                        // so the primary action is reachable on short displays.
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        26, 34, 26, 8),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 14),
                                          child: BrandMark(),
                                        ),
                                        const SizedBox(
                                          height: MasilPetSpacing.xxl,
                                        ),
                                        _OnboardingStep(
                                          key: ValueKey(_step),
                                          step: _step,
                                          template: template,
                                          petName: petName,
                                          templateCount: templates.length,
                                          localOnlyNote: localOnlyNote,
                                        ),
                                        const SizedBox(
                                          height: MasilPetSpacing.md,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(26, 0, 26, 20),
                          child: _OnboardingDock(
                            step: _step,
                            stepCount: _stepCount,
                            ctaLabel: ctaLabels[_step],
                            isBusy: isBusy,
                            onNext: () => _next(controller.completeOnboarding),
                            onBack: _step == 0 ? null : () => _goTo(_step - 1),
                            onStepSelected: _goTo,
                            onSkip: controller.completeOnboarding,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: GrainOverlay()),
          ],
        ),
      ),
    );
  }
}

/// The pet that greets a new walker: whoever is already active, else the first
/// starter template.
PetTemplate? _onboardingTemplate(
  List<PetTemplate> templates,
  String? activeTemplateId,
) {
  for (final template in templates) {
    if (template.id == activeTemplateId) {
      return template;
    }
  }
  return templates.isEmpty ? null : templates.first;
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    super.key,
    required this.step,
    required this.template,
    required this.petName,
    required this.templateCount,
    required this.localOnlyNote,
  });

  final int step;
  final PetTemplate? template;
  final String petName;
  final int templateCount;

  /// Why progress is staying on this device, when it is.
  final String? localOnlyNote;

  @override
  Widget build(BuildContext context) {
    switch (step) {
      case 0:
        return RiseIn(
          duration: MasilPetMotion.stamp,
          child: _MeetStep(template: template, petName: petName),
        );
      case 1:
        return RiseIn(child: _LoopStep(templateCount: templateCount));
      default:
        return RiseIn(
          child: _LocationStep(
            template: template,
            localOnlyNote: localOnlyNote,
          ),
        );
    }
  }
}

class _MeetStep extends StatelessWidget {
  const _MeetStep({required this.template, required this.petName});

  final PetTemplate? template;
  final String petName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 202,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              const Positioned(
                bottom: 6,
                child: GroundShadow(width: 130, height: 16),
              ),
              BobbingSprite(
                child: _OnboardingSprite(
                  template: template,
                  size: 196,
                  emotion: 'happy',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MasilPetSpacing.xs),
        SpeechBubble(
          text: '안녕! 나 ${petCallName(petName)}야.\n여기서 계속 너 기다리고 있었어.',
          maxWidth: 340,
          style: MasilPetType.bubble.copyWith(fontSize: 17),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        const SizedBox(height: MasilPetSpacing.xxl),
        const Text(
          '걸으면 만나고,\n만나면 자라요',
          textAlign: TextAlign.center,
          style: MasilPetType.display,
        ),
        const SizedBox(height: MasilPetSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: const Text(
            '동네 한 바퀴가 한 마리의 친구가 돼요.\n오늘의 걸음을 수첩에 찍어두세요.',
            textAlign: TextAlign.center,
            style: MasilPetType.body,
          ),
        ),
      ],
    );
  }
}

class _LoopStep extends StatelessWidget {
  const _LoopStep({required this.templateCount});

  final int templateCount;

  @override
  Widget build(BuildContext context) {
    final steps = [
      const _LoopStepData(
        number: '01',
        title: '동네를 걷고',
        body: '주변 ${checkInRadiusMeters ~/ 1}m 안 산책지가 수첩에 떠요',
      ),
      const _LoopStepData(
        number: '02',
        title: '도착하면 도장',
        body: '도장 한 번이 알을 자라게 해요',
      ),
      _LoopStepData(
        number: '03',
        title: '같이 자라요',
        body: '$templateCount마리가 전국에서 너를 기다려요',
      ),
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HandNote(
            '이렇게 하면 돼',
            fontSize: 23,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MasilPetSpacing.xs),
          Text(
            '세 걸음이면 충분해',
            textAlign: TextAlign.center,
            style: MasilPetType.heroTitle.copyWith(fontSize: 27),
          ),
          const SizedBox(height: 26),
          for (final (index, data) in steps.indexed) ...[
            _LoopStepCard(data: data),
            if (index != steps.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _LoopStepData {
  const _LoopStepData({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;
}

class _LoopStepCard extends StatelessWidget {
  const _LoopStepCard({required this.data});

  final _LoopStepData data;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                data.number,
                style: MasilPetType.metaMono.copyWith(
                  color: MasilPetPalette.stamp,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const DashedSpine(color: MasilPetPalette.outlineSoft),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: MasilPetType.sectionTitle.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.body,
                    style: MasilPetType.bodySmall.copyWith(height: 1.6),
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

class _LocationStep extends StatelessWidget {
  const _LocationStep({required this.template, required this.localOnlyNote});

  final PetTemplate? template;
  final String? localOnlyNote;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OnboardingSprite(
            template: template,
            size: 132,
            action: 'walking',
          ),
          const SizedBox(height: 10),
          Text(
            '어디를 걷는지\n알아야 도장을 찍어',
            textAlign: TextAlign.center,
            style: MasilPetType.heroTitle.copyWith(fontSize: 26, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            '위치는 주변 산책지를 찾고 ${checkInRadiusMeters ~/ 1}m 안에 있는지\n'
            '확인하는 데에만 써요. 이름도 이메일도 없이 시작해요.',
            textAlign: TextAlign.center,
            style: MasilPetType.bodySmall.copyWith(height: 1.75),
          ),
          const SizedBox(height: 22),
          DashedBox(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckLine(
                  localOnlyNote == null
                      ? '연결이 끊겨도 오늘의 기록은 기기에 남고, 다시 이어져요'
                      : localOnlyNote!,
                ),
                const SizedBox(height: 9),
                const CheckLine('언제든 수첩에서 전체 기록을 지울 수 있어요'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSprite extends StatelessWidget {
  const _OnboardingSprite({
    required this.template,
    required this.size,
    this.emotion,
    this.action,
  });

  final PetTemplate? template;
  final double size;
  final String? emotion;
  final String? action;

  @override
  Widget build(BuildContext context) {
    final template = this.template;
    if (template == null) {
      return SizedBox(width: size, height: size);
    }
    final asset = action != null
        ? PetAssets.action(template.assetKey, action!)
        : PetAssets.emotion(template.assetKey, emotion ?? 'happy');

    return PixelSprite(
      asset: asset,
      size: size,
      semanticLabel: template.name,
      fallback: Center(
        child: Text(
          template.initials,
          style: MasilPetType.display.copyWith(
            fontSize: size * 0.36,
            color: Color(template.colorValue),
          ),
        ),
      ),
    );
  }
}

class _OnboardingDock extends StatelessWidget {
  const _OnboardingDock({
    required this.step,
    required this.stepCount,
    required this.ctaLabel,
    required this.isBusy,
    required this.onNext,
    required this.onBack,
    required this.onStepSelected,
    required this.onSkip,
  });

  final int step;
  final int stepCount;
  final String ctaLabel;
  final bool isBusy;
  final VoidCallback onNext;

  /// Null on the first page, where there is nothing behind to go back to.
  final VoidCallback? onBack;
  final ValueChanged<int> onStepSelected;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final onBack = this.onBack;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepDots(
            count: stepCount,
            index: step,
            onSelected: isBusy ? null : onStepSelected,
          ),
          const SizedBox(height: MasilPetSpacing.sm),
          PaperButton(
            label: ctaLabel,
            onPressed: isBusy ? null : onNext,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 17,
            ),
          ),
          // 이전과 건너뛰기는 같은 줄에 둔다. 첫 장에서는 이전이 자리만
          // 지키고 사라져, 줄 높이도 건너뛰기 위치도 흔들리지 않는다.
          Row(
            children: [
              Expanded(
                child: Visibility(
                  visible: onBack != null,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: isBusy ? null : onBack,
                    child: Text(
                      '이전',
                      style: MasilPetType.bodySmall.copyWith(
                        fontSize: 13,
                        color: MasilPetPalette.mutedWarm,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: isBusy ? null : onSkip,
                  child: Text(
                    '건너뛰기',
                    style: MasilPetType.bodySmall.copyWith(
                      fontSize: 13,
                      color: MasilPetPalette.mutedWarm,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
