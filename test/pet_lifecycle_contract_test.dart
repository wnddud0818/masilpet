import 'package:flutter_test/flutter_test.dart';
import 'package:masilpet/src/models.dart';
import 'package:masilpet/src/services.dart';
import 'package:masilpet/src/state.dart';

MasilPetController _controller() {
  return MasilPetController(
    firebaseReady: false,
    locationService: const DeviceLocationService(),
    backend: null,
    userRepository: null,
  );
}

Egg _readyToHatch(Egg egg) {
  return egg.copyWith(
    progress: egg.requiredSteps,
    status: EggStatus.hatchable,
  );
}

Future<({Egg egg, Pet pet})> _hatchSecondPet(
  MasilPetController controller,
) async {
  final egg = _readyToHatch(controller.state.eggs.first);
  controller.state = controller.state.copyWith(
    eggs: [egg],
    activeEggId: egg.id,
  );

  await controller.hatchEgg(egg.id);

  final pet = controller.state.pets.singleWhere(
    (candidate) => candidate.originEggId == egg.id,
  );
  return (egg: egg, pet: pet);
}

void _expectSmallAffinityGain({
  required int before,
  required int after,
  required String action,
}) {
  expect(
    after - before,
    inInclusiveRange(1, 5),
    reason: '$action should make a small, permanent contribution to bond XP.',
  );
}

void main() {
  group('egg-to-pet lifecycle contract', () {
    test('hatching preserves the companion and transfers egg identity and bond',
        () async {
      final controller = _controller();
      final previousActivePetId = controller.state.activePetId;
      final result = await _hatchSecondPet(controller);

      expect(controller.state.activePetId, previousActivePetId);
      expect(result.pet.originEggId, result.egg.id);
      expect(result.pet.stats.affinity, greaterThan(0));
      expect(result.pet.bondLevel, isA<PetBondLevel>());

      final care = controller.state.careForPet(result.pet.id)!;
      expect(care.memories, isNotEmpty);
      expect(care.bondedDays, greaterThanOrEqualTo(1));
      expect(care.lastBondedDay, isNotNull);
    });

    test('only the selected active egg receives device step progress',
        () async {
      final controller = _controller();
      final activeEgg = controller.state.eggs.first;
      final reserveEgg = Egg(
        id: 'egg-reserve-contract',
        templateId: activeEgg.templateId,
        originRegionId: activeEgg.originRegionId,
        progress: 400,
        requiredSteps: 3500,
        status: EggStatus.incubating,
        createdAt: activeEgg.createdAt.add(const Duration(seconds: 1)),
      );
      controller.state = controller.state.copyWith(
        eggs: [activeEgg, reserveEgg],
        activeEggId: activeEgg.id,
      );

      await controller.addStepProgress(250);

      expect(
        controller.state.activeEgg?.id,
        activeEgg.id,
      );
      expect(
        controller.state.eggs
            .singleWhere((egg) => egg.id == activeEgg.id)
            .progress,
        activeEgg.progress + 250,
      );
      expect(
        controller.state.eggs
            .singleWhere((egg) => egg.id == reserveEgg.id)
            .progress,
        reserveEgg.progress,
      );
    });
  });

  group('per-pet care and relationship contract', () {
    test('talk limits and daily routine progress are isolated per pet',
        () async {
      final controller = _controller();
      final firstPet = controller.state.activePet!;
      final secondPet = (await _hatchSecondPet(controller)).pet;

      for (var count = 0; count < 5; count += 1) {
        await controller.talkWithActivePet();
      }
      final firstAfterFiveTalks =
          controller.state.pets.singleWhere((pet) => pet.id == firstPet.id);
      final firstAffinityAfterFiveTalks = firstAfterFiveTalks.stats.affinity;

      await controller.talkWithActivePet();

      expect(controller.state.careForPet(firstPet.id)!.talkCountToday, 5);
      expect(
        controller.state.pets
            .singleWhere((pet) => pet.id == firstPet.id)
            .stats
            .affinity,
        firstAffinityAfterFiveTalks,
      );
      expect(
        controller.state.dailyCareRoutineForPet(firstPet.id).talked,
        isTrue,
      );
      expect(
        controller.state.dailyCareRoutineForPet(secondPet.id).talked,
        isFalse,
      );

      await controller.selectPet(secondPet.id);
      await controller.talkWithActivePet();

      expect(controller.state.careForPet(firstPet.id)!.talkCountToday, 5);
      expect(controller.state.careForPet(secondPet.id)!.talkCountToday, 1);
      expect(
        controller.state.dailyCareRoutineForPet(secondPet.id).talked,
        isTrue,
      );

      controller.playPet(firstPet.id);
      controller.cleanPet(firstPet.id);
      await controller.feedPet(firstPet.id);

      final firstRoutine = controller.state.dailyCareRoutineForPet(firstPet.id);
      final secondRoutine =
          controller.state.dailyCareRoutineForPet(secondPet.id);
      expect(firstRoutine.fed, isTrue);
      expect(firstRoutine.played, isTrue);
      expect(firstRoutine.cleaned, isTrue);
      expect(secondRoutine.fed, isFalse);
      expect(secondRoutine.played, isFalse);
      expect(secondRoutine.cleaned, isFalse);
    });

    test('play, touch, clean, and sleep each grant a small bond contribution',
        () {
      final controller = _controller();

      var pet = controller.state.activePet!;
      var affinity = pet.stats.affinity;

      controller.playActivePet();
      pet = controller.state.activePet!;
      _expectSmallAffinityGain(
        before: affinity,
        after: pet.stats.affinity,
        action: 'play',
      );
      affinity = pet.stats.affinity;

      controller.touchActivePet(controller.preferredTouchFor(pet));
      pet = controller.state.activePet!;
      _expectSmallAffinityGain(
        before: affinity,
        after: pet.stats.affinity,
        action: 'touch',
      );
      affinity = pet.stats.affinity;

      controller.cleanActivePet();
      pet = controller.state.activePet!;
      _expectSmallAffinityGain(
        before: affinity,
        after: pet.stats.affinity,
        action: 'clean',
      );
      affinity = pet.stats.affinity;

      controller.sleepActivePet();
      pet = controller.state.activePet!;
      _expectSmallAffinityGain(
        before: affinity,
        after: pet.stats.affinity,
        action: 'sleep',
      );

      final care = controller.state.activePetCare!;
      expect(care.bondedDays, greaterThanOrEqualTo(1));
      expect(care.lastBondedDay, isNotNull);
      expect(pet.bondLevel, isA<PetBondLevel>());
    });

    test('staying-home care decays more slowly without losing permanent bond',
        () {
      final startedAt = DateTime(2026, 7, 30, 8);
      final later = startedAt.add(const Duration(hours: 12));
      final care = PetCareState(
        satiety: 80,
        cleanliness: 80,
        vitality: 80,
        happiness: 80,
        updatedAt: startedAt,
        lastWasteAt: startedAt,
        bondedDays: 7,
        lastBondedDay: startedAt,
      );
      const engine = CareEngine();

      final walkingCompanion = engine.resolve(care, later);
      final stayingHome = engine.resolve(
        care,
        later,
        stayingHome: true,
      );

      expect(stayingHome.satiety, greaterThan(walkingCompanion.satiety));
      expect(
        stayingHome.cleanliness,
        greaterThan(walkingCompanion.cleanliness),
      );
      expect(stayingHome.vitality, greaterThan(walkingCompanion.vitality));
      expect(stayingHome.happiness, greaterThan(walkingCompanion.happiness));
      expect(walkingCompanion.bondedDays, care.bondedDays);
      expect(stayingHome.bondedDays, care.bondedDays);
      expect(walkingCompanion.lastBondedDay, care.lastBondedDay);
      expect(stayingHome.lastBondedDay, care.lastBondedDay);
    });
  });
}
