import 'package:flutter/material.dart';

import '../models.dart';
import '../pet_assets.dart';

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
    final assetPath = emotion == null
        ? PetAssets.growth(template.assetKey, stage)
        : PetAssets.emotion(template.assetKey, emotion!);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
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
    );
  }
}
