import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../pet_assets.dart';
import '../theme.dart';

enum PetPlayFieldScene {
  seasidePark,
  neighborhoodYard,
}

class PetPlayField extends StatefulWidget {
  const PetPlayField({
    required this.templates,
    required this.pets,
    required this.activePetId,
    required this.activity,
    required this.activityNonce,
    this.eggs = const [],
    this.height = 260,
    this.scene = PetPlayFieldScene.seasidePark,
    this.spriteScale = 1.0,
    this.showVisitors = true,
    this.onPetTap,
    this.onKickBall,
    this.onFillBowl,
    this.bowlFilled = false,
    super.key,
  }) : assert(spriteScale > 0);

  final List<PetTemplate> templates;
  final List<Pet> pets;
  final List<Egg> eggs;
  final String? activePetId;
  final PetFieldActivity activity;
  final int activityNonce;
  final double height;
  final PetPlayFieldScene scene;
  final double spriteScale;
  final bool showVisitors;
  final ValueChanged<String>? onPetTap;

  /// Kicking the ball sends everyone running — wire it to play.
  final VoidCallback? onKickBall;

  /// Filling the bowl is the yard's shortcut to feeding.
  final VoidCallback? onFillBowl;

  /// Whether the bowl already has food in it today.
  final bool bowlFilled;

  @override
  State<PetPlayField> createState() => _PetPlayFieldState();
}

class _PetPlayFieldState extends State<PetPlayField>
    with SingleTickerProviderStateMixin {
  static const _fieldLoopDuration = Duration(milliseconds: 14000);

  late final AnimationController _controller;
  Timer? _activityTimer;
  PetFieldActivity _displayActivity = PetFieldActivity.idle;
  int _seenActivityNonce = 0;
  bool _animationsEnabled = false;
  double _animationTimeSeconds = 0;
  double _lastControllerTimeSeconds = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _fieldLoopDuration,
    );
    _seenActivityNonce = widget.activityNonce;
    if (widget.activityNonce > 0) {
      _showActivity(widget.activity);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationsEnabled = TickerMode.valuesOf(context).enabled &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (_animationsEnabled == animationsEnabled) {
      return;
    }

    _animationsEnabled = animationsEnabled;
    if (_animationsEnabled) {
      _controller.repeat();
    } else {
      _controller.stop(canceled: false);
    }
  }

  @override
  void didUpdateWidget(covariant PetPlayField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activityNonce != _seenActivityNonce) {
      _seenActivityNonce = widget.activityNonce;
      _showActivity(widget.activity);
    }
  }

  void _showActivity(PetFieldActivity activity) {
    _activityTimer?.cancel();
    setState(() {
      _displayActivity = activity;
    });

    if (activity == PetFieldActivity.idle) {
      return;
    }

    _activityTimer = Timer(const Duration(milliseconds: 3200), () {
      if (!mounted || widget.activityNonce != _seenActivityNonce) {
        return;
      }
      setState(() {
        _displayActivity = PetFieldActivity.idle;
      });
    });
  }

  @override
  void dispose() {
    _activityTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playmates = _buildPlaymates();
    final borderRadius = _playFieldBorderRadius(context);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _playFieldSemanticsLabel(playmates),
      child: ClipRRect(
        borderRadius: borderRadius,
        // The frame belongs to the card this field sits in, so the yard itself
        // draws edge to edge.
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: borderRadius),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final timeSeconds = _readAnimationTime();
                    final t = (timeSeconds /
                            (_fieldLoopDuration.inMilliseconds /
                                Duration.millisecondsPerSecond)) %
                        1.0;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _PlayFieldPainter(t, scene: widget.scene),
                          ),
                        ),
                        for (var i = 0; i < widget.eggs.take(2).length; i++)
                          _PlayEgg(
                            index: i,
                            t: t,
                            fieldSize: constraints.biggest,
                          ),
                        for (var i = 0; i < playmates.length; i++)
                          _PlayPet(
                            key: ValueKey(
                              'pet-play-field-pet-${playmates[i].id}',
                            ),
                            playmate: playmates[i],
                            index: i,
                            totalCount: playmates.length,
                            t: t,
                            timeSeconds: timeSeconds,
                            fieldSize: constraints.biggest,
                            activeActivity: _displayActivity,
                            spriteScale: widget.spriteScale,
                            onTap: widget.onPetTap,
                          ),
                        if (widget.onKickBall != null)
                          Positioned(
                            left: constraints.maxWidth * 0.66,
                            bottom: constraints.maxHeight * 0.16,
                            child: _YardBall(onKick: widget.onKickBall!),
                          ),
                        if (widget.onFillBowl != null)
                          Positioned(
                            right: constraints.maxWidth * 0.09,
                            bottom: constraints.maxHeight * 0.11,
                            child: _YardBowl(
                              filled: widget.bowlFilled,
                              onFill: widget.onFillBowl!,
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  BorderRadius _playFieldBorderRadius(BuildContext context) {
    final cardShape = Theme.of(context).cardTheme.shape;
    if (cardShape is RoundedRectangleBorder) {
      return cardShape.borderRadius.resolve(Directionality.of(context));
    }
    return BorderRadius.circular(8);
  }

  double _readAnimationTime() {
    final controllerTimeSeconds =
        (_controller.lastElapsedDuration?.inMicroseconds ?? 0) /
            Duration.microsecondsPerSecond;
    if (controllerTimeSeconds < _lastControllerTimeSeconds) {
      _lastControllerTimeSeconds = 0;
    }
    _animationTimeSeconds +=
        math.max(0, controllerTimeSeconds - _lastControllerTimeSeconds);
    _lastControllerTimeSeconds = controllerTimeSeconds;
    return _animationTimeSeconds;
  }

  String _playFieldSemanticsLabel(List<_Playmate> playmates) {
    Pet? activePet;
    for (final pet in widget.pets) {
      if (pet.id == widget.activePetId) {
        activePet = pet;
        break;
      }
    }

    final activePetLabel = activePet == null
        ? '동행 마실펫이 없어요'
        : '동행 마실펫 ${activePet.name}, ${_activitySemanticsLabel(_displayActivity)}';
    return '마실펫 놀이터. $activePetLabel. 함께 있는 마실펫 ${playmates.length}마리.';
  }

  List<_Playmate> _buildPlaymates() {
    final byTemplateId = {
      for (final template in widget.templates) template.id: template,
    };
    final owned = widget.pets
        .map((pet) {
          final template = byTemplateId[pet.templateId];
          if (template == null) {
            return null;
          }
          return _Playmate(
            id: pet.id,
            template: template,
            stage: pet.stage.name,
            isActive: pet.id == widget.activePetId,
          );
        })
        .nonNulls
        .toList();

    if (!widget.showVisitors || owned.length >= 5) {
      return owned.take(5).toList();
    }

    final usedTemplateIds = owned.map((item) => item.template.id).toSet();
    final visitors = widget.templates
        .where((template) => !usedTemplateIds.contains(template.id))
        .take(5 - owned.length)
        .map(
          (template) => _Playmate(
            id: 'visitor-${template.id}',
            template: template,
            stage: PetStage.baby.name,
            isActive: false,
          ),
        );

    return [...owned, ...visitors].take(5).toList();
  }
}

String _activitySemanticsLabel(PetFieldActivity activity) {
  return switch (activity) {
    PetFieldActivity.idle => '놀이터를 산책하는 중',
    PetFieldActivity.walking => '산책하는 중',
    PetFieldActivity.eating => '간식을 먹는 중',
    PetFieldActivity.greeting => '인사하는 중',
    PetFieldActivity.jumping => '신나게 뛰는 중',
    PetFieldActivity.sleeping => '잠자는 중',
  };
}

class _Playmate {
  const _Playmate({
    required this.id,
    required this.template,
    required this.stage,
    required this.isActive,
  });

  final String id;
  final PetTemplate template;
  final String stage;
  final bool isActive;
}

class _PlayPet extends StatefulWidget {
  const _PlayPet({
    required this.playmate,
    required this.index,
    required this.totalCount,
    required this.t,
    required this.timeSeconds,
    required this.fieldSize,
    required this.activeActivity,
    required this.spriteScale,
    required this.onTap,
    super.key,
  });

  final _Playmate playmate;
  final int index;
  final int totalCount;
  final double t;
  final double timeSeconds;
  final Size fieldSize;
  final PetFieldActivity activeActivity;
  final double spriteScale;
  final ValueChanged<String>? onTap;

  @override
  State<_PlayPet> createState() => _PlayPetState();
}

class _PlayPetState extends State<_PlayPet> {
  Timer? _reactionTimer;
  PetFieldActivity? _reactionActivity;
  double? _reactionAnchor;
  bool _pressed = false;
  int _tapCount = 0;

  @override
  void didUpdateWidget(covariant _PlayPet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeActivity == oldWidget.activeActivity ||
        !widget.playmate.isActive) {
      return;
    }

    if (widget.activeActivity != PetFieldActivity.idle) {
      _reactionAnchor = _patrolMotion(
        widget.index,
        widget.timeSeconds,
      ).xOffset;
    } else if (_reactionActivity == null) {
      _reactionAnchor = null;
    }
  }

  @override
  void dispose() {
    _reactionTimer?.cancel();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed || !mounted) {
      return;
    }
    setState(() {
      _pressed = pressed;
    });
  }

  void _handleTap() {
    final motion = _patrolMotion(widget.index, widget.timeSeconds);
    _reactionTimer?.cancel();
    setState(() {
      _tapCount += 1;
      _pressed = false;
      _reactionAnchor = motion.xOffset;
      _reactionActivity = _tapCount.isOdd
          ? PetFieldActivity.greeting
          : PetFieldActivity.jumping;
    });
    widget.onTap?.call(widget.playmate.id);

    _reactionTimer = Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _reactionActivity = null;
        if (widget.activeActivity == PetFieldActivity.idle) {
          _reactionAnchor = null;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final motion = _patrolMotion(widget.index, widget.timeSeconds);
    final externalActivity = widget.playmate.isActive &&
            widget.activeActivity != PetFieldActivity.idle
        ? widget.activeActivity
        : null;
    final activity = externalActivity ??
        _reactionActivity ??
        _ambientActivity(
          widget.index,
          motion,
          isActive: widget.playmate.isActive,
        );
    final sizeRatio = widget.totalCount >= 5 ? 0.105 : 0.12;
    final size = ((widget.fieldSize.width * sizeRatio).clamp(58.0, 108.0) *
            widget.spriteScale)
        .clamp(58.0, 128.0);
    final baseX = switch (widget.index % 5) {
      0 => 0.14,
      1 => 0.33,
      2 => 0.54,
      3 => 0.74,
      _ => 0.88,
    };
    final lane = (widget.index * 2) % 3;
    final yBase = widget.fieldSize.height * (0.47 + lane * 0.09);
    final isReacting = externalActivity != null || _reactionActivity != null;
    final pose = _poseFor(
      activity: activity,
      motion: motion,
      baseX: baseX,
      yBase: yBase,
      size: size,
      fixedXOffset: isReacting ? _reactionAnchor : null,
    );
    final frame =
        ((widget.timeSeconds * _frameRate(activity) + widget.index) % 4)
                .floor() +
            1;
    final imagePath = _activityAsset(
      widget.playmate.template.assetKey,
      widget.playmate.stage,
      activity: activity,
      frame: frame,
    );
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Positioned(
      left: pose.x,
      top: pose.y,
      child: Semantics(
        button: true,
        label: '${widget.playmate.template.name} 캐릭터',
        hint: '터치하면 캐릭터가 반응해요',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _setPressed(true),
            onTapCancel: () => _setPressed(false),
            onTapUp: (_) => _setPressed(false),
            onTap: _handleTap,
            child: AnimatedScale(
              scale: _pressed ? 0.94 : 1,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 110),
              curve: Curves.easeOutBack,
              child: SizedBox(
                width: size,
                height: size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      // The soft olive pool a sprite casts on the lawn.
                      BoxShadow(
                        color: const Color(0xFF46583C).withValues(alpha: 0.22),
                        blurRadius: 10,
                        spreadRadius: -6,
                        offset: Offset(0, size * 0.42 + pose.shadowLift),
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: pose.rotation,
                        child: Transform.scale(
                          scaleX: (pose.isFacingLeft ? -1 : 1) * pose.scaleX,
                          scaleY: pose.scaleY,
                          child: _assetImage(
                            context,
                            imagePath,
                            size,
                            errorBuilder: (context, error, stackTrace) {
                              return _assetImage(
                                context,
                                PetAssets.action(
                                  widget.playmate.template.assetKey,
                                  _fallbackAction(activity),
                                ),
                                size,
                                errorBuilder: (context, error, stackTrace) {
                                  return _assetImage(
                                    context,
                                    PetAssets.growth(
                                      widget.playmate.template.assetKey,
                                      widget.playmate.stage,
                                    ),
                                    size,
                                    errorBuilder: (context, error, stackTrace) {
                                      return DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Color(widget
                                                  .playmate.template.colorValue)
                                              .withValues(alpha: 0.18),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            widget.playmate.template.initials,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  color: Color(widget.playmate
                                                      .template.colorValue),
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      if (activity != PetFieldActivity.idle &&
                          (isReacting ||
                              (widget.playmate.isActive &&
                                  widget.activeActivity !=
                                      PetFieldActivity.idle)))
                        _ActivityCue(
                          activity: activity,
                          t: widget.t,
                          size: size,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _assetImage(
    BuildContext context,
    String assetPath,
    double logicalSize, {
    ImageErrorWidgetBuilder? errorBuilder,
  }) {
    final cacheSize = (logicalSize * MediaQuery.devicePixelRatioOf(context))
        .ceil()
        .clamp(64, 256)
        .toInt();
    return Image.asset(
      assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      gaplessPlayback: true,
      errorBuilder: errorBuilder,
    );
  }

  PetFieldActivity _ambientActivity(
    int index,
    _PatrolMotion motion, {
    required bool isActive,
  }) {
    if (motion.isWalking) {
      return PetFieldActivity.walking;
    }
    if (isActive) {
      return PetFieldActivity.idle;
    }
    return switch (index % 4) {
      0 => PetFieldActivity.eating,
      1 => PetFieldActivity.greeting,
      2 => PetFieldActivity.jumping,
      _ => PetFieldActivity.idle,
    };
  }

  _PetPose _poseFor({
    required PetFieldActivity activity,
    required _PatrolMotion motion,
    required double baseX,
    required double yBase,
    required double size,
    required double? fixedXOffset,
  }) {
    final phaseSeed = widget.index * 0.37;
    final travel = 0.1 - (widget.index % 3) * 0.013;
    final idleSway = activity == PetFieldActivity.walking
        ? 0.0
        : math.sin(widget.timeSeconds * 0.74 + phaseSeed) * 0.005;
    final xRatio = baseX + (fixedXOffset ?? motion.xOffset) * travel + idleSway;

    final strideWave = motion.stepWave;
    final actionWave =
        math.sin((widget.timeSeconds * 0.85 + phaseSeed) * math.pi * 2);
    final jumpPhase = (widget.timeSeconds * 0.72 + phaseSeed) % 1;
    final jumpLift = math
        .pow(math.sin(jumpPhase * math.pi).clamp(0.0, 1.0), 1.15)
        .toDouble();
    final jumpHeight = widget.playmate.isActive ? 22.0 : 10.0;
    final double lift = switch (activity) {
      PetFieldActivity.walking => strideWave.abs() * 1.8 * motion.speedEnvelope,
      PetFieldActivity.eating => (actionWave + 1) * 0.45,
      PetFieldActivity.greeting => (actionWave + 1) * 1.2,
      PetFieldActivity.jumping => jumpLift * jumpHeight,
      PetFieldActivity.sleeping =>
        (math.sin((widget.timeSeconds * 0.42 + phaseSeed) * math.pi * 2) + 1) *
            0.4,
      PetFieldActivity.idle => (actionWave + 1) * 0.45,
    };
    final groundRoll =
        activity == PetFieldActivity.walking ? strideWave * 0.35 : 0.0;
    final x = (xRatio * widget.fieldSize.width)
        .clamp(8.0, widget.fieldSize.width - size - 8);
    final y = (yBase + groundRoll - lift)
        .clamp(42.0, widget.fieldSize.height - size - 18);
    final double rotation = switch (activity) {
      PetFieldActivity.walking =>
        (motion.facingLeft ? -1 : 1) * 0.014 * motion.speedEnvelope +
            strideWave * 0.004,
      PetFieldActivity.greeting => actionWave * 0.014,
      PetFieldActivity.jumping => -actionWave * 0.018,
      PetFieldActivity.eating => actionWave * 0.006,
      PetFieldActivity.sleeping => 0.0,
      PetFieldActivity.idle => actionWave * 0.004,
    };
    final double scaleX = switch (activity) {
      PetFieldActivity.walking => 1.0 + strideWave.abs() * 0.007,
      PetFieldActivity.jumping => 1.0 - jumpLift * 0.009,
      PetFieldActivity.eating => 1.0 + actionWave.abs() * 0.002,
      PetFieldActivity.greeting => 1.0 - actionWave.abs() * 0.002,
      PetFieldActivity.sleeping => 1.0,
      PetFieldActivity.idle => 1.0,
    };
    final double scaleY = switch (activity) {
      PetFieldActivity.walking => 1.0 - strideWave.abs() * 0.012,
      PetFieldActivity.jumping => 1.0 + jumpLift * 0.018,
      PetFieldActivity.eating => 1.0 - actionWave.abs() * 0.003,
      PetFieldActivity.greeting => 1.0 + actionWave.abs() * 0.004,
      PetFieldActivity.sleeping => 1.0,
      PetFieldActivity.idle => 1.0,
    };

    return _PetPose(
      x: x,
      y: y,
      isFacingLeft: motion.facingLeft,
      rotation: rotation,
      scaleX: scaleX,
      scaleY: scaleY,
      shadowLift: lift * 0.08,
    );
  }

  double _frameRate(PetFieldActivity activity) {
    return switch (activity) {
      PetFieldActivity.walking => 4.2,
      PetFieldActivity.eating => 3.2,
      PetFieldActivity.greeting => 3.8,
      PetFieldActivity.sleeping => 1.8,
      PetFieldActivity.jumping => 4.0,
      PetFieldActivity.idle => 2.4,
    };
  }

  String _activityAsset(
    String petKey,
    String stage, {
    required PetFieldActivity activity,
    required int frame,
  }) {
    return switch (activity) {
      PetFieldActivity.walking => PetAssets.animation(petKey, 'walk', frame),
      PetFieldActivity.eating => PetAssets.animation(petKey, 'eat', frame),
      PetFieldActivity.greeting => PetAssets.animation(petKey, 'greet', frame),
      PetFieldActivity.sleeping => PetAssets.animation(petKey, 'sleep', frame),
      PetFieldActivity.idle => PetAssets.animation(petKey, 'idle', frame),
      PetFieldActivity.jumping => PetAssets.action(petKey, 'jumping'),
    };
  }

  String _fallbackAction(PetFieldActivity activity) {
    return switch (activity) {
      PetFieldActivity.walking => 'walking',
      PetFieldActivity.eating => 'eating',
      PetFieldActivity.greeting => 'greeting',
      PetFieldActivity.sleeping => 'sleeping',
      PetFieldActivity.jumping => 'jumping',
      PetFieldActivity.idle => 'idle',
    };
  }
}

class _PatrolMotion {
  const _PatrolMotion({
    required this.xOffset,
    required this.isWalking,
    required this.facingLeft,
    required this.stepWave,
    required this.speedEnvelope,
  });

  final double xOffset;
  final bool isWalking;
  final bool facingLeft;
  final double stepWave;
  final double speedEnvelope;
}

_PatrolMotion _patrolMotion(int index, double timeSeconds) {
  final cycleDuration = 8.8 + (index % 3) * 1.15;
  final phase = (timeSeconds / cycleDuration + index * 0.173) % 1.0;

  if (phase < 0.38) {
    final progress = phase / 0.38;
    final eased = 0.5 - math.cos(progress * math.pi) * 0.5;
    return _PatrolMotion(
      xOffset: -1 + eased * 2,
      isWalking: true,
      facingLeft: false,
      stepWave: math.sin(progress * math.pi * 4),
      speedEnvelope: math.sin(progress * math.pi),
    );
  }
  if (phase < 0.5) {
    return const _PatrolMotion(
      xOffset: 1,
      isWalking: false,
      facingLeft: false,
      stepWave: 0,
      speedEnvelope: 0,
    );
  }
  if (phase < 0.88) {
    final progress = (phase - 0.5) / 0.38;
    final eased = 0.5 - math.cos(progress * math.pi) * 0.5;
    return _PatrolMotion(
      xOffset: 1 - eased * 2,
      isWalking: true,
      facingLeft: true,
      stepWave: math.sin(progress * math.pi * 4),
      speedEnvelope: math.sin(progress * math.pi),
    );
  }
  return const _PatrolMotion(
    xOffset: -1,
    isWalking: false,
    facingLeft: true,
    stepWave: 0,
    speedEnvelope: 0,
  );
}

class _PetPose {
  const _PetPose({
    required this.x,
    required this.y,
    required this.isFacingLeft,
    required this.rotation,
    required this.scaleX,
    required this.scaleY,
    required this.shadowLift,
  });

  final double x;
  final double y;
  final bool isFacingLeft;
  final double rotation;
  final double scaleX;
  final double scaleY;
  final double shadowLift;
}

class _ActivityCue extends StatelessWidget {
  const _ActivityCue({
    required this.activity,
    required this.t,
    required this.size,
  });

  final PetFieldActivity activity;
  final double t;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bob = math.sin(t * math.pi * 8) * 4;
    // The design speaks in glyphs, not icons: ♥ for food, ✦ for play, ○ for a
    // bath, ♪ for a hello.
    final glyph = switch (activity) {
      PetFieldActivity.eating => '♥',
      PetFieldActivity.greeting => '♪',
      PetFieldActivity.jumping => '✦',
      PetFieldActivity.walking => '·',
      PetFieldActivity.sleeping => 'z',
      PetFieldActivity.idle => '·',
    };
    final color = switch (activity) {
      PetFieldActivity.eating => MasilPetPalette.stamp,
      PetFieldActivity.greeting => MasilPetPalette.forest,
      PetFieldActivity.jumping => MasilPetPalette.statSatiety,
      PetFieldActivity.walking => MasilPetPalette.mutedWarm,
      PetFieldActivity.sleeping => MasilPetPalette.statClean,
      PetFieldActivity.idle => const Color(0xFF7E9184),
    };

    return Positioned(
      right: -size * 0.04,
      top: -size * 0.1 + bob,
      child: Container(
        width: size * 0.28,
        height: size * 0.28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MasilPetPalette.paper,
          border: Border.all(color: MasilPetPalette.ink, width: 1.5),
          borderRadius: MasilPetRadii.smallBorder,
          boxShadow: const [
            BoxShadow(
              color: Color(0x383C2D19),
              blurRadius: 0,
              offset: Offset(2, 2),
            ),
          ],
        ),
        // Decorative: the pet's own semantics already describe what it is up to.
        child: ExcludeSemantics(
          child: Text(
            glyph,
            style: MasilPetType.rowTitle.copyWith(
              fontSize: size * 0.15,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayEgg extends StatelessWidget {
  const _PlayEgg({
    required this.index,
    required this.t,
    required this.fieldSize,
  });

  final int index;
  final double t;
  final Size fieldSize;

  @override
  Widget build(BuildContext context) {
    final size = (fieldSize.width * 0.055).clamp(38.0, 54.0);
    final wobble = math.sin((t * 3 + index * 0.25) * math.pi * 2);
    final left = fieldSize.width * (0.72 + index * 0.09);
    final top = fieldSize.height * (0.68 + index * 0.03);

    return Positioned(
      left: left.clamp(8.0, fieldSize.width - size - 8),
      top: top.clamp(40.0, fieldSize.height - size - 10),
      child: Transform.rotate(
        angle: wobble * 0.09,
        child: Container(
          width: size,
          height: size * 1.12,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF3E6C8), Color(0xFFE2CFA4)],
            ),
            border: Border.all(color: const Color(0xFFC2A97B), width: 1.5),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(size),
              topRight: Radius.circular(size),
              bottomLeft: Radius.circular(size * 0.9),
              bottomRight: Radius.circular(size * 0.9),
            ),
          ),
          child: Text(
            '?',
            style: MasilPetType.hand.copyWith(
              fontSize: size * 0.52,
              color: const Color(0xFFB09A6E),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ball in the yard. Kicking it is the shortcut to playing with everyone.
class _YardBall extends StatefulWidget {
  const _YardBall({required this.onKick});

  final VoidCallback onKick;

  @override
  State<_YardBall> createState() => _YardBallState();
}

class _YardBallState extends State<_YardBall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 620),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _kick() {
    // `@keyframes ballHop` — two bounces, then rest.
    _controller
      ..reset()
      ..repeat(count: 2);
    widget.onKick();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '공 차기',
      child: GestureDetector(
        onTap: _kick,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final phase = _controller.value;
            final lift = phase < 0.3
                ? phase / 0.3 * 26
                : phase < 0.55
                    ? (1 - (phase - 0.3) / 0.25) * 26
                    : phase < 0.78
                        ? (phase - 0.55) / 0.23 * 10
                        : (1 - (phase - 0.78) / 0.22) * 10;
            return Transform.translate(
              offset: Offset(0, -lift),
              child: child,
            );
          },
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF1E4C6),
              border: Border.all(color: MasilPetPalette.ink, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: MasilPetPalette.stamp.withValues(alpha: 0.28),
                  blurRadius: 0,
                  spreadRadius: -5,
                  offset: const Offset(-5, -5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The food bowl. Filling it feeds whoever is out in the yard.
class _YardBowl extends StatelessWidget {
  const _YardBowl({required this.filled, required this.onFill});

  final bool filled;
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: filled ? '밥그릇 · 이미 채웠어요' : '밥그릇 채우기',
      child: GestureDetector(
        onTap: onFill,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 40,
          height: 23,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8A45A),
                    border: Border.all(
                      color: const Color(0xFF8E6224),
                      width: 1.5,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(2),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                top: 3,
                height: 7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: filled
                        ? const Color(0xFFA8763A)
                        : const Color(0x2E785A2D),
                    borderRadius: MasilPetRadii.pillBorder,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayFieldPainter extends CustomPainter {
  const _PlayFieldPainter(this.t, {required this.scene});

  final double t;
  final PetPlayFieldScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    switch (scene) {
      case PetPlayFieldScene.seasidePark:
        _paintSeasidePark(canvas, size);
      case PetPlayFieldScene.neighborhoodYard:
        _paintNeighborhoodYard(canvas, size);
    }
  }

  void _paintSeasidePark(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE7EDE2), Color(0xFFEAF1E7)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final sun = Paint()..color = const Color(0xFFF6C85F);
    canvas.drawCircle(Offset(size.width * 0.86, size.height * 0.18), 24, sun);

    final sea = Paint()
      ..color = const Color(0xFF60929E).withValues(alpha: 0.24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height * 0.36, size.width, size.height * 0.16),
        const Radius.circular(24),
      ),
      sea,
    );

    final wavePaint = Paint()
      ..color = const Color(0xFFFBF6EA).withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.4 + i * 0.03);
      final path = Path()..moveTo(-20, y);
      for (var x = -20.0; x <= size.width + 20; x += 24) {
        final phase = math.sin(t * math.pi * 2 + i);
        path.quadraticBezierTo(x + 12, y + phase * 4, x + 24, y);
      }
      canvas.drawPath(path, wavePaint);
    }

    final grass = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFD6E2C9), Color(0xFFB9CFA9)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.48, size.width, size.height * 0.52),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.48, size.width, size.height * 0.52),
      grass,
    );

    final hillPaint = Paint()..color = const Color(0xFFBCCEB1);
    canvas.drawOval(
      Rect.fromLTWH(-size.width * 0.18, size.height * 0.46, size.width * 0.7,
          size.height * 0.34),
      hillPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.42, size.height * 0.43, size.width * 0.78,
          size.height * 0.38),
      Paint()..color = const Color(0xFFAAC09E),
    );

    final pathPaint = Paint()..color = const Color(0xFFE7D6AE);
    final path = Path()
      ..moveTo(size.width * 0.44, size.height)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.83,
        size.width * 0.51,
        size.height * 0.68,
        size.width * 0.43,
        size.height * 0.5,
      )
      ..lineTo(size.width * 0.59, size.height * 0.5)
      ..cubicTo(
        size.width * 0.7,
        size.height * 0.67,
        size.width * 0.55,
        size.height * 0.84,
        size.width * 0.64,
        size.height,
      )
      ..close();
    canvas.drawPath(path, pathPaint);

    _drawTree(canvas, size, Offset(size.width * 0.12, size.height * 0.55), 1.0);
    _drawTree(canvas, size, Offset(size.width * 0.9, size.height * 0.58), 0.82);
    _drawFlowers(canvas, size);
  }

  /// 우리 마당 — sky over hills, a paling fence at the horizon, and a lawn of
  /// dry-brush grass, all in the notebook's parchment palette.
  void _paintNeighborhoodYard(Canvas canvas, Size size) {
    final ground = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFEAF1E7),
          Color(0xFFE3EDE0),
          Color(0xFFD6E2C9),
          Color(0xFFC6D8B7),
          Color(0xFFB9CFA9),
        ],
        stops: [0, 0.31, 0.32, 0.68, 1],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, ground);

    // Low sun with two haloes.
    final sunCenter = Offset(size.width * 0.9, size.height * 0.12);
    canvas.drawCircle(
      sunCenter,
      30,
      Paint()..color = const Color(0x33F6C85F),
    );
    canvas.drawCircle(
      sunCenter,
      25,
      Paint()..color = const Color(0x55F6C85F),
    );
    canvas.drawCircle(sunCenter, 21, Paint()..color = const Color(0xFFF6C85F));
    canvas.drawCircle(
      sunCenter,
      21,
      Paint()
        ..color = const Color(0xFFE0AE3E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    _drawYardCloud(canvas, size, offset: t, scale: 1);
    _drawYardCloud(canvas, size, offset: (t * 0.68 + 0.45) % 1, scale: 0.72);

    // Two domes of distant hills.
    canvas.drawOval(
      Rect.fromLTWH(
        -size.width * 0.1,
        size.height * 0.13,
        size.width * 0.56,
        size.height * 0.38,
      ),
      Paint()..color = const Color(0xFFBCCEB1),
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.34,
        size.height * 0.17,
        size.width * 0.48,
        size.height * 0.3,
      ),
      Paint()..color = const Color(0xFFAAC09E),
    );

    // The horizon, ruled in dashes like everything else in the notebook.
    final horizonPaint = Paint()
      ..color = const Color(0xFFA2B792)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, size.height * 0.32),
        Offset(x + 4, size.height * 0.32),
        horizonPaint,
      );
    }

    // Paling fence.
    final palePaint = Paint()..color = const Color(0xFFCDB88E);
    final paleTop = size.height * 0.29;
    for (var x = 0.0; x < size.width; x += 27) {
      canvas.drawRect(Rect.fromLTWH(x, paleTop, 4, 28), palePaint);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.31, size.width, 2.5),
      palePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.345, size.width, 2.5),
      palePaint,
    );

    // Dry-brush grass.
    final grassPaint = Paint()
      ..color = const Color(0x268CA478)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 26) {
      canvas.drawLine(
        Offset(x, size.height * 0.32),
        Offset(x, size.height),
        grassPaint,
      );
    }

    _drawYardHouse(canvas, size);
    _drawTree(canvas, size, Offset(size.width * 0.06, size.height * 0.44), 1);
    _drawTree(
      canvas,
      size,
      Offset(size.width * 0.92, size.height * 0.46),
      0.78,
    );
    _drawYardStones(canvas, size);
    _drawYardFlowers(canvas, size);
    _drawYardButterfly(canvas, size);
  }

  void _drawYardCloud(
    Canvas canvas,
    Size size, {
    required double offset,
    required double scale,
  }) {
    final paint = Paint()..color = const Color(0xFFFCF9F1);
    final x = -size.width * 0.3 + (size.width * 1.5) * offset;
    final y = size.height * (scale > 0.9 ? 0.09 : 0.18);
    final width = 76 * scale;
    final height = 19 * scale;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, height),
        Radius.circular(height),
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromLTWH(x + 14 * scale, y - 12 * scale, 34 * scale, 25 * scale),
      paint,
    );
    canvas.drawOval(
      Rect.fromLTWH(x + 41 * scale, y - 6 * scale, 23 * scale, 19 * scale),
      paint,
    );
  }

  /// The little house in the corner: red roof, cream walls, one dark door.
  void _drawYardHouse(Canvas canvas, Size size) {
    final left = size.width * 0.06;
    final bottom = size.height * 0.91;
    const bodyWidth = 54.0;
    const bodyHeight = 31.0;
    final bodyTop = bottom - bodyHeight;

    final roof = Path()
      ..moveTo(left + 32, bodyTop - 21)
      ..lineTo(left + 64, bodyTop)
      ..lineTo(left, bodyTop)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFB23A2E));

    final body = Rect.fromLTWH(left + 5, bodyTop, bodyWidth, bodyHeight);
    canvas.drawRect(body, Paint()..color = const Color(0xFFE7D6AE));
    canvas.drawRect(
      body,
      Paint()
        ..color = const Color(0xFFC2A97B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final door = RRect.fromRectAndCorners(
      Rect.fromLTWH(left + 23, bottom - 22, 19, 22),
      topLeft: const Radius.circular(10),
      topRight: const Radius.circular(10),
    );
    canvas.drawRRect(door, Paint()..color = const Color(0xFF6E5B3E));
  }

  void _drawYardStones(Canvas canvas, Size size) {
    final stones = <(double, double, double, double, Color)>[
      (0.44, 0.96, 0.09, 0.05, const Color(0xFFCFC6AE)),
      (0.53, 0.87, 0.075, 0.04, const Color(0xFFD5CCB5)),
      (0.45, 0.78, 0.065, 0.034, const Color(0xFFCFC6AE)),
    ];
    for (final (x, y, width, height, color) in stones) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * x, size.height * y),
          width: size.width * width,
          height: size.height * height,
        ),
        Paint()..color = color,
      );
    }
  }

  void _drawYardButterfly(Canvas canvas, Size size) {
    // `@keyframes flutter` — a slow figure-eight over the lawn.
    final phase = t * math.pi * 2;
    final center = Offset(
      size.width * 0.24 + math.sin(phase) * 34,
      size.height * 0.46 + math.sin(phase * 2) * 16,
    );
    final wing = Paint()..color = const Color(0xFFE8A5B4);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 9, height: 7),
      wing,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(6, 2),
        width: 8,
        height: 6,
      ),
      wing,
    );
  }

  void _drawYardFlowers(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = const Color(0xFF6F8F64)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const blooms = <(double, double, Color)>[
      (0.20, 0.92, Color(0xFFD98BA0)),
      (0.31, 0.74, Color(0xFFE8C25E)),
      (0.58, 0.94, Color(0xFFC97FB0)),
      (0.74, 0.70, Color(0xFFD98BA0)),
      (0.88, 0.60, Color(0xFFE8C25E)),
      (0.08, 0.66, Color(0xFFC97FB0)),
    ];

    for (final (x, y, color) in blooms) {
      final base = Offset(size.width * x, size.height * y);
      canvas.drawLine(base, base.translate(0, -11), stem);
      canvas.drawCircle(
        base.translate(0, -14),
        4.5,
        Paint()..color = color,
      );
    }
  }

  /// A round shrub-tree that leans with the breeze.
  void _drawTree(Canvas canvas, Size size, Offset root, double scale) {
    // `@keyframes sway` — the whole crown tips a couple of degrees.
    final lean = math.sin(t * math.pi * 2) * 0.03;
    canvas.save();
    canvas.translate(root.dx, root.dy + 34 * scale);
    canvas.rotate(lean);
    canvas.translate(-root.dx, -(root.dy + 34 * scale));

    canvas.drawRect(
      Rect.fromLTWH(root.dx - 4 * scale, root.dy, 8 * scale, 34 * scale),
      Paint()..color = const Color(0xFF8E6C48),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: root.translate(0, -12 * scale),
        width: 48 * scale,
        height: 44 * scale,
      ),
      Paint()..color = const Color(0xFF6F9166),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: root.translate(-2 * scale, -30 * scale),
        width: 35 * scale,
        height: 33 * scale,
      ),
      Paint()..color = const Color(0xFF80A476),
    );
    canvas.restore();
  }

  void _drawFlowers(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = const Color(0xFF6F8F64)
      ..strokeWidth = 2;
    const colors = [
      Color(0xFFD98BA0),
      Color(0xFFE8C25E),
      Color(0xFFC97FB0),
    ];

    for (var i = 0; i < 12; i++) {
      final x = size.width * (0.08 + (i * 0.075) % 0.84);
      final y = size.height * (0.78 + (i % 3) * 0.05);
      canvas.drawLine(Offset(x, y + 8), Offset(x, y - 5), stem);
      canvas.drawCircle(
        Offset(x, y - 8),
        4,
        Paint()..color = colors[i % colors.length],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlayFieldPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.scene != scene;
  }
}
