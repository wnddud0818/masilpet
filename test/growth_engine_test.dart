import 'dart:io';

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

    for (final template in starterPetTemplates) {
      expect(
        starterDialogueSeed,
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

  test('every character has a unique name and full situational voice', () {
    final names = starterPetTemplates.map((template) => template.name).toSet();
    expect(names, hasLength(starterPetTemplates.length));
    expect(characterDialogueProfiles, hasLength(starterPetTemplates.length));
    expect(starterDialogueSeed, hasLength(777));

    for (final template in starterPetTemplates) {
      final profile = characterDialogueProfiles.singleWhere(
        (profile) => profile.templateId == template.id,
      );
      expect(
        profile.lines.keys,
        containsAll(dialogueSituationTriggers),
        reason: '${template.name}에 빠진 상황 대사가 있습니다.',
      );
      expect(
        profile.lines['default'],
        hasLength(greaterThanOrEqualTo(2)),
        reason: '${template.name}의 반복 대화 변주가 부족합니다.',
      );
      for (final lines in profile.lines.values) {
        for (final text in lines) {
          expect(text.trim(), isNotEmpty, reason: template.name);
          expect(
            text,
            isNot(matches(RegExp(r'보상|친밀도|경험치|EXP'))),
            reason: '${template.name}의 대사가 시스템 문구처럼 들립니다.',
          );
        }
      }
    }
  });

  test('conversation context prioritizes needs and rotates situations', () {
    const dialogue = StaticDialogueService();
    final template = starterPetTemplates.first;
    final now = DateTime(2026, 7, 16, 8);
    final pet = Pet(
      id: 'pet-dialogue-test',
      templateId: template.id,
      name: template.name,
      stage: PetStage.evolved,
      level: 5,
      stats: const GrowthStats(exp: 500, mood: 80, knowledge: 60, affinity: 80),
      originRegionId: template.regionId,
      hatchedAt: now,
      lastInteractedAt: null,
    );

    final hungry = dialogue.lineForConversation(
      template: template,
      pet: pet,
      care: PetCareState(
        satiety: 20,
        cleanliness: 80,
        vitality: 80,
        updatedAt: now,
      ),
      lastCategory: PoiCategory.history,
      now: now,
      interactionIndex: 0,
    );
    expect(hungry.trigger, 'hungry');

    final healthyCare = PetCareState(updatedAt: now);
    expect(
      dialogue
          .lineForConversation(
            template: template,
            pet: pet,
            care: healthyCare,
            lastCategory: PoiCategory.history,
            now: now,
            interactionIndex: 0,
          )
          .trigger,
      'history',
    );
    expect(
      dialogue
          .lineForConversation(
            template: template,
            pet: pet,
            care: healthyCare,
            lastCategory: PoiCategory.history,
            now: now,
            interactionIndex: 1,
          )
          .trigger,
      'morning',
    );
    expect(
      dialogue
          .lineForConversation(
            template: template,
            pet: pet,
            care: healthyCare,
            lastCategory: PoiCategory.history,
            now: now,
            interactionIndex: 3,
          )
          .trigger,
      'close',
    );
    expect(
      dialogue
          .lineForConversation(
            template: template,
            pet: pet,
            care: healthyCare,
            lastCategory: PoiCategory.history,
            now: now,
            interactionIndex: 4,
          )
          .trigger,
      'evolved',
    );
  });

  test('pet templates reference complete display asset sets', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    const requiredGrowth = ['baby', 'grown', 'evolved'];
    const requiredActions = ['idle'];
    const requiredEmotions = ['happy'];
    const animatedPrefixes = ['walk', 'eat', 'greet', 'sleep', 'idle'];

    for (final template in starterPetTemplates) {
      final root = 'assets/pets/${template.assetKey}';
      expect(Directory(root).existsSync(), isTrue, reason: template.id);
      expect(pubspec, contains('- $root/actions/'), reason: template.id);
      expect(pubspec, contains('- $root/emotions/'), reason: template.id);
      expect(pubspec, contains('- $root/growth/'), reason: template.id);

      for (final stage in requiredGrowth) {
        expect(
          File('$root/growth/$stage.png').existsSync(),
          isTrue,
          reason: '${template.id} missing growth/$stage.png',
        );
      }

      for (final action in requiredActions) {
        expect(
          File('$root/actions/$action.png').existsSync(),
          isTrue,
          reason: '${template.id} missing actions/$action.png',
        );
      }

      for (final emotion in requiredEmotions) {
        expect(
          File('$root/emotions/$emotion.png').existsSync(),
          isTrue,
          reason: '${template.id} missing emotions/$emotion.png',
        );
      }

      final animations = Directory('$root/animations');
      if (!animations.existsSync()) {
        continue;
      }

      expect(pubspec, contains('- $root/animations/'), reason: template.id);
      for (final prefix in animatedPrefixes) {
        for (var frame = 1; frame <= 4; frame += 1) {
          final frameName = frame.toString().padLeft(2, '0');
          expect(
            File('$root/animations/${prefix}_$frameName.png').existsSync(),
            isTrue,
            reason:
                '${template.id} missing animations/${prefix}_$frameName.png',
          );
        }
      }
    }
  });
}
