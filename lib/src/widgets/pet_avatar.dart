import 'package:flutter/material.dart';

import '../models.dart';
import '../pet_assets.dart';
import '../theme.dart';
import 'paper_kit.dart';

/// A pet sprite on the page — no frame, no gradient. The pixel art carries
/// itself, exactly as in the design.
class PetAvatar extends StatelessWidget {
  const PetAvatar({
    required this.template,
    this.size = 72,
    this.stage = 'baby',
    this.emotion,
    this.action,
    super.key,
  });

  final PetTemplate template;
  final double size;
  final String stage;
  final String? emotion;
  final String? action;

  @override
  Widget build(BuildContext context) {
    final String assetPath;
    if (action != null) {
      assetPath = PetAssets.action(template.assetKey, action!);
    } else if (emotion != null) {
      assetPath = PetAssets.emotion(template.assetKey, emotion!);
    } else {
      assetPath = PetAssets.growth(template.assetKey, stage);
    }

    return PixelSprite(
      asset: assetPath,
      size: size,
      semanticLabel: emotion == null
          ? '${template.name}, $stage 단계'
          : '${template.name}, $emotion 표정',
      fallback: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            template.initials,
            style: MasilPetType.rowTitle.copyWith(
              fontSize: size * 0.34,
              color: Color(template.colorValue),
            ),
          ),
        ),
      ),
    );
  }
}
