import 'package:flutter/material.dart';

import '../models.dart';
import '../pet_assets.dart';
import '../seed_data.dart';
import '../theme.dart';
import 'paper_kit.dart';

/// EXP needed for the next stage, mirroring the design's 500-point scale.
const petEvolutionExpGoal = 500;

/// Opens one pet's page: sprite, rarity, care bars, personality, first meeting.
///
/// Reachable from the 마실펫 roster and from tapping a pet out in the yard.
void showPetDetailSheet({
  required BuildContext context,
  required Pet pet,
  required PetTemplate template,
  required PetCareState? care,
  required bool isActive,
  required VoidCallback onSetMain,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => PetDetailSheet(
      pet: pet,
      template: template,
      care: care,
      isActive: isActive,
      onSetMain: onSetMain,
    ),
  );
}

class PetDetailSheet extends StatelessWidget {
  const PetDetailSheet({
    super.key,
    required this.pet,
    required this.template,
    required this.care,
    required this.isActive,
    required this.onSetMain,
  });

  final Pet pet;
  final PetTemplate template;
  final PetCareState? care;
  final bool isActive;
  final VoidCallback onSetMain;

  @override
  Widget build(BuildContext context) {
    final care = this.care;

    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    PixelSprite(
                      asset:
                          PetAssets.growth(template.assetKey, pet.stage.name),
                      size: 96,
                      semanticLabel: pet.name,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${template.rarityLabel} · '
                            '${regionNameForId(template.regionId)}',
                            style: MasilPetType.eyebrow.copyWith(
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pet.name,
                            style:
                                MasilPetType.heroTitle.copyWith(fontSize: 27),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Lv.${pet.level} · ${pet.stage.label} 단계 · '
                            '${petDaysTogether(pet)}일째',
                            style:
                                MasilPetType.caption.copyWith(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const DashedRule(),
                const SizedBox(height: 16),
                if (care != null) ...[
                  PaperStatBar(
                    label: '배부름',
                    valueLabel: '${care.satiety}',
                    ratio: care.satiety / 100,
                    color: MasilPetPalette.statSatiety,
                  ),
                  const SizedBox(height: 13),
                  PaperStatBar(
                    label: '청결',
                    valueLabel: '${care.cleanliness}',
                    ratio: care.cleanliness / 100,
                    color: MasilPetPalette.statClean,
                  ),
                  const SizedBox(height: 13),
                  PaperStatBar(
                    label: '활력',
                    valueLabel: '${care.vitality}',
                    ratio: care.vitality / 100,
                    color: MasilPetPalette.statVitality,
                  ),
                  const SizedBox(height: 13),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        '진화까지',
                        style: MasilPetType.bodySmall.copyWith(
                          fontSize: 13.5,
                          height: 1.2,
                          color: MasilPetPalette.inkSoft,
                        ),
                      ),
                    ),
                    Text(
                      'EXP ${pet.stats.exp} / $petEvolutionExpGoal',
                      style: MasilPetType.rowTitle.copyWith(fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const DashedRule(),
                const SizedBox(height: 16),
                Text(template.basePersonality, style: MasilPetType.prose),
                const SizedBox(height: 16),
                const DashedRule(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '첫 만남',
                      style: MasilPetType.caption.copyWith(fontSize: 12.5),
                    ),
                    const Spacer(),
                    Text(
                      '${petFirstMetLabel(pet.hatchedAt)} · '
                      '${regionNameForId(pet.originRegionId)}',
                      style: MasilPetType.caption.copyWith(
                        fontSize: 12.5,
                        color: MasilPetPalette.inkSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: isActive
                          ? DashedBox(
                              fill: null,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              child: Text(
                                '지금 함께 다니는 친구',
                                textAlign: TextAlign.center,
                                style: MasilPetType.rowTitle.copyWith(
                                  fontSize: 15,
                                  color: MasilPetPalette.mutedWarm,
                                ),
                              ),
                            )
                          : PaperButton.stamp(
                              label: '주 캐릭터로 설정',
                              onPressed: () {
                                onSetMain();
                                Navigator.of(context).pop();
                              },
                              fontSize: 16,
                              padding: const EdgeInsets.symmetric(
                                horizontal: MasilPetSpacing.lg,
                                vertical: 15,
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PaperButton.ghost(
                        label: '닫기',
                        onPressed: () => Navigator.of(context).pop(),
                        fontSize: 16,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How long this pet has been walking with you.
int petDaysTogether(Pet pet) {
  final days = DateTime.now().difference(pet.hatchedAt).inDays;
  return days < 0 ? 0 : days;
}

String petFirstMetLabel(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}
