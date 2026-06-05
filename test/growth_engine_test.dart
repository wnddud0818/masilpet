import 'package:flutter_test/flutter_test.dart';
import 'package:masilpet/src/models.dart';
import 'package:masilpet/src/seed_data.dart';
import 'package:masilpet/src/services.dart';

void main() {
  const engine = GrowthEngine();

  test('food POI primarily increases mood', () {
    final reward = engine.rewardFor(PoiCategory.food);

    expect(reward.stats.exp, greaterThan(0));
    expect(reward.stats.mood, greaterThan(reward.stats.knowledge));
  });

  test('culture POI primarily increases knowledge', () {
    final reward = engine.rewardFor(PoiCategory.culture);

    expect(reward.stats.knowledge, greaterThan(reward.stats.mood));
  });

  test('egg becomes hatchable when progress reaches required steps', () {
    final egg = Egg(
      id: 'egg-test',
      templateId: 'wave-naru',
      originRegionId: 'busan',
      progress: 3400,
      requiredSteps: 3500,
      status: EggStatus.incubating,
      createdAt: DateTime(2026),
    );

    final progressed = engine.progressEgg(egg, 200);

    expect(progressed.progress, 3500);
    expect(progressed.status, EggStatus.hatchable);
  });

  test('evolution requires level, affinity, and knowledge', () {
    final stage = engine.stageFor(
      level: 5,
      stats:
          const GrowthStats(exp: 500, mood: 80, knowledge: 50, affinity: 100),
      currentStage: PetStage.grown,
    );

    expect(stage, PetStage.evolved);
  });

  test('dialogue seed covers every pet and visit category', () {
    const dialogue = StaticDialogueService();

    for (final template in busanPetTemplates) {
      expect(
        busanDialogueSeed,
        contains(
          isA<DialogueLine>()
              .having((line) => line.templateId, 'templateId', template.id)
              .having((line) => line.trigger, 'trigger', 'default'),
        ),
      );

      for (final category in PoiCategory.values) {
        final line = dialogue.lineFor(
          template: template,
          lastCategory: category,
        );
        expect(line.templateId, template.id);
        expect(line.trigger, category.name);
        expect(line.text, isNotEmpty);
      }
    }
  });
}
