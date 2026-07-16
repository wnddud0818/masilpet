import 'package:flutter/material.dart';

import '../models.dart';
import '../pet_assets.dart';
import '../theme.dart';

class PetAvatar extends StatelessWidget {
  const PetAvatar({
    required this.template,
    this.size = 72,
    this.stage = 'baby',
    this.emotion,
    super.key,
  });

  final PetTemplate template;
  final double size;
  final String stage;
  final String? emotion;

  @override
  Widget build(BuildContext context) {
    final color = Color(template.colorValue);
    final cacheSize =
        (size * MediaQuery.devicePixelRatioOf(context)).round().clamp(64, 256);
    final assetPath = emotion == null
        ? PetAssets.growth(template.assetKey, stage)
        : PetAssets.emotion(template.assetKey, emotion!);

    return Semantics(
      image: true,
      label: emotion == null
          ? '${template.name}, $stage 단계'
          : '${template.name}, $emotion 표정',
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.2),
                MasilPetPalette.paper,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: MasilPetRadii.panelBorder,
            border: Border.all(
              color: color.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: MasilPetShadows.soft,
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.08),
            child: Image.asset(
              assetPath,
              width: size,
              height: size,
              fit: BoxFit.contain,
              cacheWidth: cacheSize,
              cacheHeight: cacheSize,
              filterQuality: FilterQuality.none,
              errorBuilder: (context, error, stackTrace) {
                return Text(
                  template.initials,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
