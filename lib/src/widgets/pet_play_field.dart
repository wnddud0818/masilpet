import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../pet_assets.dart';

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
      image: true,
      excludeSemantics: true,
      label: _playFieldSemanticsLabel(playmates),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: borderRadius,
          ),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final t = _controller.value;
                    final timeSeconds = t *
                        _fieldLoopDuration.inMilliseconds /
                        Duration.millisecondsPerSecond;
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
                            playmate: playmates[i],
                            index: i,
                            totalCount: playmates.length,
                            t: t,
                            timeSeconds: timeSeconds,
                            fieldSize: constraints.biggest,
                            activeActivity: _displayActivity,
                            spriteScale: widget.spriteScale,
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

  String _playFieldSemanticsLabel(List<_Playmate> playmates) {
    Pet? activePet;
    for (final pet in widget.pets) {
      if (pet.id == widget.activePetId) {
        activePet = pet;
        break;
      }
    }

    final activePetLabel = activePet == null
        ? '대표 마실펫이 없습니다'
        : '대표 마실펫 ${activePet.name}, ${_activitySemanticsLabel(_displayActivity)}';
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
    required this.template,
    required this.stage,
    required this.isActive,
  });

  final PetTemplate template;
  final String stage;
  final bool isActive;
}

class _PlayPet extends StatelessWidget {
  const _PlayPet({
    required this.playmate,
    required this.index,
    required this.totalCount,
    required this.t,
    required this.timeSeconds,
    required this.fieldSize,
    required this.activeActivity,
    required this.spriteScale,
  });

  final _Playmate playmate;
  final int index;
  final int totalCount;
  final double t;
  final double timeSeconds;
  final Size fieldSize;
  final PetFieldActivity activeActivity;
  final double spriteScale;

  @override
  Widget build(BuildContext context) {
    final activity =
        playmate.isActive && activeActivity != PetFieldActivity.idle
            ? activeActivity
            : _ambientActivity(index, t, isActive: playmate.isActive);
    final sizeRatio = totalCount >= 5 ? 0.105 : 0.12;
    final size =
        ((fieldSize.width * sizeRatio).clamp(58.0, 108.0) * spriteScale)
            .clamp(58.0, 128.0);
    final baseX = switch (index % 5) {
      0 => 0.14,
      1 => 0.33,
      2 => 0.54,
      3 => 0.74,
      _ => 0.88,
    };
    final lane = (index * 2) % 3;
    final yBase = fieldSize.height * (0.47 + lane * 0.09);
    final pose = _poseFor(
      activity: activity,
      baseX: baseX,
      yBase: yBase,
      size: size,
    );
    final frame =
        ((timeSeconds * _frameRate(activity) + index) % 4).floor() + 1;
    final imagePath = _activityAsset(playmate.template.assetKey, playmate.stage,
        activity: activity, frame: frame);

    return Positioned(
      left: pose.x,
      top: pose.y,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 16,
                offset: Offset(0, 7 + pose.shadowLift),
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
                  scaleX: pose.isFacingLeft ? -1 : 1,
                  scaleY: pose.scaleY,
                  child: _assetImage(
                    context,
                    imagePath,
                    size,
                    errorBuilder: (context, error, stackTrace) {
                      return _assetImage(
                        context,
                        PetAssets.action(
                          playmate.template.assetKey,
                          _fallbackAction(activity),
                        ),
                        size,
                        errorBuilder: (context, error, stackTrace) {
                          return _assetImage(
                            context,
                            PetAssets.growth(
                              playmate.template.assetKey,
                              playmate.stage,
                            ),
                            size,
                            errorBuilder: (context, error, stackTrace) {
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(playmate.template.colorValue)
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    playmate.template.initials,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Color(
                                              playmate.template.colorValue),
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
              if (playmate.isActive &&
                  activeActivity != PetFieldActivity.idle &&
                  activity != PetFieldActivity.idle)
                _ActivityCue(activity: activity, t: t, size: size),
            ],
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
    double t, {
    required bool isActive,
  }) {
    final phase = (t + index * 0.19) % 1;
    if (!isActive && phase > 0.88) {
      return PetFieldActivity.greeting;
    }
    if (!isActive && index.isOdd && phase > 0.78) {
      return PetFieldActivity.jumping;
    }
    if (!isActive && index % 4 == 0 && phase > 0.68) {
      return PetFieldActivity.eating;
    }
    return PetFieldActivity.walking;
  }

  _PetPose _poseFor({
    required PetFieldActivity activity,
    required double baseX,
    required double yBase,
    required double size,
  }) {
    final phaseSeed = index * 0.37;
    final walkDuration = 8.4 + (index % 3) * 1.25;
    final walkPhase = timeSeconds / walkDuration + phaseSeed;
    final walkAngle = walkPhase * math.pi * 2;
    final walkWave = math.sin(walkAngle);
    final travel = 0.105 - (index % 3) * 0.014;
    final idleSway = math.sin(timeSeconds * 0.74 + phaseSeed) * 0.012;
    final xRatio = activity == PetFieldActivity.walking
        ? baseX + walkWave * travel
        : baseX + idleSway;

    final stridePhase = timeSeconds * (0.95 + index * 0.04) + phaseSeed;
    final strideWave = math.sin(stridePhase * math.pi * 2);
    final actionWave = math.sin((timeSeconds * 0.85 + phaseSeed) * math.pi * 2);
    final jumpPhase = (timeSeconds * 0.72 + phaseSeed) % 1;
    final jumpLift = math
        .pow(math.sin(jumpPhase * math.pi).clamp(0.0, 1.0), 1.15)
        .toDouble();
    final jumpHeight = playmate.isActive ? 22.0 : 10.0;
    final double lift = switch (activity) {
      PetFieldActivity.walking => strideWave.abs() * 1.1,
      PetFieldActivity.eating => (actionWave + 1) * 0.45,
      PetFieldActivity.greeting => (actionWave + 1) * 1.2,
      PetFieldActivity.jumping => jumpLift * jumpHeight,
      PetFieldActivity.sleeping =>
        (math.sin((timeSeconds * 0.42 + phaseSeed) * math.pi * 2) + 1) * 0.4,
      PetFieldActivity.idle => (actionWave + 1) * 0.45,
    };
    final groundRoll = activity == PetFieldActivity.walking
        ? math.sin(walkAngle + index) * 0.35
        : 0.0;
    final x = (xRatio * fieldSize.width).clamp(8.0, fieldSize.width - size - 8);
    final y =
        (yBase + groundRoll - lift).clamp(42.0, fieldSize.height - size - 18);
    final double rotation = switch (activity) {
      PetFieldActivity.walking => strideWave * 0.006,
      PetFieldActivity.greeting => actionWave * 0.014,
      PetFieldActivity.jumping => -actionWave * 0.018,
      PetFieldActivity.eating => actionWave * 0.006,
      PetFieldActivity.sleeping => 0.0,
      PetFieldActivity.idle => actionWave * 0.004,
    };
    final double scaleY = switch (activity) {
      PetFieldActivity.walking => 1.0 - strideWave.abs() * 0.003,
      PetFieldActivity.jumping => 1.0 + jumpLift * 0.018,
      PetFieldActivity.eating => 1.0 - actionWave.abs() * 0.003,
      PetFieldActivity.greeting => 1.0 + actionWave.abs() * 0.004,
      PetFieldActivity.sleeping => 1.0,
      PetFieldActivity.idle => 1.0,
    };

    return _PetPose(
      x: x,
      y: y,
      isFacingLeft: activity == PetFieldActivity.walking
          ? math.cos(walkAngle) < 0
          : index.isOdd,
      rotation: rotation,
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

class _PetPose {
  const _PetPose({
    required this.x,
    required this.y,
    required this.isFacingLeft,
    required this.rotation,
    required this.scaleY,
    required this.shadowLift,
  });

  final double x;
  final double y;
  final bool isFacingLeft;
  final double rotation;
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
    final icon = switch (activity) {
      PetFieldActivity.eating => Icons.restaurant,
      PetFieldActivity.greeting => Icons.waving_hand,
      PetFieldActivity.jumping => Icons.star_rounded,
      PetFieldActivity.walking => Icons.directions_walk,
      PetFieldActivity.sleeping => Icons.bedtime,
      PetFieldActivity.idle => Icons.circle,
    };
    final color = switch (activity) {
      PetFieldActivity.eating => const Color(0xFFF97316),
      PetFieldActivity.greeting => const Color(0xFF0F766E),
      PetFieldActivity.jumping => const Color(0xFFF59E0B),
      PetFieldActivity.walking => const Color(0xFF2563EB),
      PetFieldActivity.sleeping => const Color(0xFF6366F1),
      PetFieldActivity.idle => const Color(0xFF64748B),
    };

    return Positioned(
      right: -size * 0.02,
      top: -size * 0.08 + bob,
      child: Container(
        width: size * 0.28,
        height: size * 0.28,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.16),
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
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(size),
            border: Border.all(color: const Color(0xFFF59E0B), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.11),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.egg_alt,
            color: const Color(0xFFB45309),
            size: size * 0.58,
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
        colors: [Color(0xFFE0F2FE), Color(0xFFF0FDFA)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final sun = Paint()..color = const Color(0xFFFBBF24);
    canvas.drawCircle(Offset(size.width * 0.86, size.height * 0.18), 30, sun);

    final sea = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.34);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height * 0.36, size.width, size.height * 0.16),
        const Radius.circular(24),
      ),
      sea,
    );

    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
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
        colors: [Color(0xFFBBF7D0), Color(0xFF4ADE80)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.48, size.width, size.height * 0.52),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.48, size.width, size.height * 0.52),
      grass,
    );

    final hillPaint = Paint()..color = const Color(0xFF86EFAC);
    canvas.drawOval(
      Rect.fromLTWH(-size.width * 0.18, size.height * 0.46, size.width * 0.7,
          size.height * 0.34),
      hillPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.42, size.height * 0.43, size.width * 0.78,
          size.height * 0.38),
      Paint()..color = const Color(0xFF6EE7B7),
    );

    final pathPaint = Paint()..color = const Color(0xFFFDE68A);
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

  void _paintNeighborhoodYard(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFF7ED), Color(0xFFD9F99D), Color(0xFFF8FAFC)],
        stops: [0, 0.54, 1],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final sun = Paint()..color = const Color(0xFFFCD34D);
    canvas.drawCircle(Offset(size.width * 0.86, size.height * 0.16), 26, sun);

    _drawNeighborhoodHouse(
      canvas,
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.17,
        size.width * 0.35,
        size.height * 0.29,
      ),
      isPrimary: true,
    );
    _drawNeighborhoodHouse(
      canvas,
      Rect.fromLTWH(
        size.width * 0.58,
        size.height * 0.2,
        size.width * 0.3,
        size.height * 0.24,
      ),
      isPrimary: false,
    );

    final wallTop = size.height * 0.41;
    final wallPaint = Paint()..color = const Color(0xFFF5E6C8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-8, wallTop, size.width + 16, size.height * 0.12),
        const Radius.circular(12),
      ),
      wallPaint,
    );
    final wallLine = Paint()
      ..color = const Color(0xFFE0C89D)
      ..strokeWidth = 2;
    for (var x = -8.0; x < size.width + 16; x += 44) {
      canvas.drawLine(
          Offset(x, wallTop + 8), Offset(x, wallTop + 34), wallLine);
    }
    canvas.drawLine(
      Offset(0, wallTop + size.height * 0.12),
      Offset(size.width, wallTop + size.height * 0.12),
      wallLine,
    );

    final yard = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFA7F3D0), Color(0xFF34D399)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5),
      yard,
    );

    final matPaint = Paint()..color = const Color(0xFFFDE68A);
    final yardPath = Path()
      ..moveTo(size.width * 0.42, size.height)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.84,
        size.width * 0.45,
        size.height * 0.7,
        size.width * 0.43,
        size.height * 0.53,
      )
      ..lineTo(size.width * 0.57, size.height * 0.53)
      ..cubicTo(
        size.width * 0.61,
        size.height * 0.7,
        size.width * 0.72,
        size.height * 0.84,
        size.width * 0.62,
        size.height,
      )
      ..close();
    canvas.drawPath(yardPath, matPaint);

    final stonePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.58 + i * 0.08);
      final width = size.width * (0.12 + i * 0.02);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * (0.5 + math.sin(i) * 0.03), y),
          width: width,
          height: 12,
        ),
        stonePaint,
      );
    }

    _drawYardPlanter(
      canvas,
      Offset(size.width * 0.13, size.height * 0.65),
      1.0,
    );
    _drawYardPlanter(
      canvas,
      Offset(size.width * 0.88, size.height * 0.67),
      0.82,
    );
    _drawYardFlowers(canvas, size);
  }

  void _drawNeighborhoodHouse(
    Canvas canvas,
    Rect body, {
    required bool isPrimary,
  }) {
    final wall = Paint()
      ..color = isPrimary ? const Color(0xFFFFEDD5) : const Color(0xFFE0F2FE);
    final wallShadow = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        body.shift(const Offset(0, 5)),
        const Radius.circular(8),
      ),
      wallShadow,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(8)),
      wall,
    );

    final roofHeight = body.height * 0.38;
    final roof = Path()
      ..moveTo(body.left - body.width * 0.08, body.top + roofHeight * 0.35)
      ..quadraticBezierTo(
        body.center.dx,
        body.top - roofHeight * 0.55,
        body.right + body.width * 0.08,
        body.top + roofHeight * 0.35,
      )
      ..lineTo(body.right, body.top + roofHeight)
      ..lineTo(body.left, body.top + roofHeight)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFB45309));

    final tileLine = Paint()
      ..color = const Color(0xFF7C2D12).withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 4; i++) {
      final y = body.top + roofHeight * (0.42 + i * 0.15);
      final path = Path()..moveTo(body.left + body.width * 0.05, y);
      path.quadraticBezierTo(
          body.center.dx, y - 9, body.right - body.width * 0.05, y);
      canvas.drawPath(path, tileLine);
    }

    final door = Rect.fromLTWH(
      body.left + body.width * 0.42,
      body.top + body.height * 0.52,
      body.width * 0.16,
      body.height * 0.34,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(door, const Radius.circular(6)),
      Paint()..color = const Color(0xFF92400E),
    );

    final windowPaint = Paint()..color = const Color(0xFFBAE6FD);
    final windowStroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..strokeWidth = 2;
    for (final dx in [0.18, 0.68]) {
      final window = Rect.fromLTWH(
        body.left + body.width * dx,
        body.top + body.height * 0.48,
        body.width * 0.16,
        body.height * 0.16,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(window, const Radius.circular(4)),
        windowPaint,
      );
      canvas.drawLine(window.centerLeft, window.centerRight, windowStroke);
      canvas.drawLine(window.topCenter, window.bottomCenter, windowStroke);
    }
  }

  void _drawYardPlanter(Canvas canvas, Offset base, double scale) {
    final planter = Rect.fromCenter(
      center: base,
      width: 86 * scale,
      height: 24 * scale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(planter, Radius.circular(8 * scale)),
      Paint()..color = const Color(0xFFB45309),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        planter.deflate(4 * scale),
        Radius.circular(6 * scale),
      ),
      Paint()..color = const Color(0xFF78350F),
    );

    final leafColors = [
      const Color(0xFF16A34A),
      const Color(0xFF22C55E),
      const Color(0xFF15803D),
    ];
    for (var i = 0; i < 7; i++) {
      final x = planter.left + planter.width * (0.12 + i * 0.13);
      final y = planter.top - (i.isEven ? 9 : 15) * scale;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 18 * scale,
          height: 28 * scale,
        ),
        Paint()..color = leafColors[i % leafColors.length],
      );
    }
  }

  void _drawYardFlowers(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = const Color(0xFF047857)
      ..strokeWidth = 2;
    final colors = [
      const Color(0xFFF43F5E),
      const Color(0xFFF59E0B),
      const Color(0xFF38BDF8),
      const Color(0xFFA855F7),
    ];

    for (var i = 0; i < 18; i++) {
      final leftSide = i.isEven;
      final x = size.width *
          (leftSide ? 0.04 + (i * 0.031) % 0.22 : 0.74 + (i * 0.027) % 0.22);
      final y = size.height * (0.73 + (i % 4) * 0.045);
      canvas.drawLine(Offset(x, y + 8), Offset(x, y - 5), stem);
      canvas.drawCircle(
        Offset(x, y - 8),
        4,
        Paint()..color = colors[i % colors.length],
      );
    }
  }

  void _drawTree(Canvas canvas, Size size, Offset root, double scale) {
    final trunk = Paint()..color = const Color(0xFFA16207);
    final leaves = Paint()..color = const Color(0xFF16A34A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(root.dx - 5 * scale, root.dy, 10 * scale, 42 * scale),
        Radius.circular(4 * scale),
      ),
      trunk,
    );
    canvas.drawCircle(root + Offset(0, -6 * scale), 28 * scale, leaves);
    canvas.drawCircle(
      root + Offset(-20 * scale, 4 * scale),
      20 * scale,
      Paint()..color = const Color(0xFF22C55E),
    );
    canvas.drawCircle(
      root + Offset(20 * scale, 7 * scale),
      22 * scale,
      Paint()..color = const Color(0xFF15803D),
    );
  }

  void _drawFlowers(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = const Color(0xFF15803D)
      ..strokeWidth = 2;
    final colors = [
      const Color(0xFFF97316),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFFFACC15),
    ];

    for (var i = 0; i < 16; i++) {
      final x = size.width * (0.08 + (i * 0.057) % 0.84);
      final y = size.height * (0.75 + (i % 3) * 0.055);
      canvas.drawLine(Offset(x, y + 8), Offset(x, y - 5), stem);
      canvas.drawCircle(
        Offset(x, y - 7),
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
