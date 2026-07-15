import 'package:flutter_test/flutter_test.dart';
import 'package:masilpet/src/data/local_progress_repository.dart';
import 'package:masilpet/src/models.dart';
import 'package:masilpet/src/seed_data.dart';
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

void main() {
  const engine = CareEngine();

  test('care decay is gentle and capped at 24 hours', () {
    final startedAt = DateTime(2026, 7, 14, 9);
    final care = PetCareState(
      satiety: 80,
      cleanliness: 80,
      vitality: 80,
      updatedAt: startedAt,
      dailyCountDay: startedAt,
      feedCountToday: 2,
      playCountToday: 2,
      cleanCountToday: 2,
    );

    final afterOneDay = engine.resolve(
      care,
      startedAt.add(const Duration(hours: 24)),
    );
    final afterTwoDays = engine.resolve(
      care,
      startedAt.add(const Duration(hours: 48)),
    );

    expect(afterOneDay.satiety, 68);
    expect(afterOneDay.cleanliness, 72);
    expect(afterOneDay.vitality, 74);
    expect(afterTwoDays.satiety, afterOneDay.satiety);
    expect(afterTwoDays.cleanliness, afterOneDay.cleanliness);
    expect(afterTwoDays.vitality, afterOneDay.vitality);
    expect(afterTwoDays.feedCountToday, 0);
    expect(afterTwoDays.playCountToday, 0);
    expect(afterTwoDays.cleanCountToday, 0);
  });

  test('care values stay bounded and daily action counts roll over', () {
    final startedAt = DateTime(2026, 7, 14, 9);
    final nextDay = DateTime(2026, 7, 15, 9);
    final care = PetCareState(
      satiety: 120,
      cleanliness: -10,
      vitality: 98,
      updatedAt: startedAt,
      dailyCountDay: startedAt,
      feedCountToday: 5,
      playCountToday: 4,
      cleanCountToday: 3,
    );

    expect(care.satiety, 100);
    expect(care.cleanliness, 0);

    final fed = engine.afterFeed(care, nextDay);
    final played = engine.afterPlay(fed, nextDay);
    final cleaned = engine.afterClean(played, nextDay);

    expect(cleaned.satiety, inInclusiveRange(0, 100));
    expect(cleaned.cleanliness, inInclusiveRange(0, 100));
    expect(cleaned.vitality, inInclusiveRange(0, 100));
    expect(cleaned.feedCountToday, 1);
    expect(cleaned.playCountToday, 1);
    expect(cleaned.cleanCountToday, 1);
    expect(isSameLocalDay(cleaned.dailyCountDay, nextDay), isTrue);
  });

  test('daily care routine completes when any four conditions are met', () {
    final now = DateTime.now();
    final initial = MasilPetState.initial(firebaseReady: false);
    final petId = initial.activePetId;
    final state = initial.copyWith(
      careByPetId: {
        petId: PetCareState(
          updatedAt: now,
          dailyCountDay: now,
          feedCountToday: 1,
          playCountToday: 1,
          cleanCountToday: 1,
        ),
      },
      dialogueCountToday: 0,
      dialogueDay: now,
      checkIns: [
        CheckIn(
          id: 'care-check-in',
          poiId: starterPoiSeed.first.id,
          regionId: starterPoiSeed.first.regionId,
          category: starterPoiSeed.first.category,
          createdAt: now,
          distanceMeters: 12,
          rewardApplied: true,
        ),
      ],
    );

    final routine = state.dailyCareRoutineAt(now);

    expect(routine.fed, isTrue);
    expect(routine.played, isTrue);
    expect(routine.cleaned, isTrue);
    expect(routine.talked, isFalse);
    expect(routine.checkedIn, isTrue);
    expect(routine.completedCount, 4);
    expect(routine.remainingCount, 0);
    expect(routine.isComplete, isTrue);
  });

  test('controller care actions update care and claim points only once',
      () async {
    final controller = _controller();

    controller.playActivePet();
    controller.cleanActivePet();
    await controller.feedActivePet();
    await controller.talkWithActivePet();

    final care = controller.state.activePetCare!;
    expect(care.feedCountToday, 1);
    expect(care.playCountToday, 1);
    expect(care.cleanCountToday, 1);
    expect(controller.state.dailyCareCompletedCount, 4);
    expect(controller.state.canClaimDailyCareReward, isTrue);

    controller.sleepActivePet();
    expect(controller.state.fieldActivity, PetFieldActivity.sleeping);

    final statsBeforeClaim = controller.state.activePet!.stats;
    controller.claimDailyCareReward();

    expect(controller.state.carePoints, dailyCareRewardPoints);
    expect(
      controller.state.dailyCareRewardClaimKey,
      controller.state.dailyCareRewardClaimKeyForToday,
    );
    expect(controller.state.canClaimDailyCareReward, isFalse);
    expect(controller.state.activePet!.stats.exp, statsBeforeClaim.exp);
    expect(controller.state.activePet!.stats.mood, statsBeforeClaim.mood);
    expect(controller.state.activePet!.stats.knowledge,
        statsBeforeClaim.knowledge);
    expect(
        controller.state.activePet!.stats.affinity, statsBeforeClaim.affinity);

    controller.claimDailyCareReward();
    expect(controller.state.carePoints, dailyCareRewardPoints);
    expect(controller.state.statusMessage, contains('이미'));
  });

  test('feeding stops at the daily care limit', () async {
    final controller = _controller();

    for (var count = 0; count < dailyFeedCareLimit; count += 1) {
      await controller.feedActivePet();
    }
    final statsAtLimit = controller.state.activePet!.stats;

    await controller.feedActivePet();

    expect(
      controller.state.activePetCare!.feedCountToday,
      dailyFeedCareLimit,
    );
    expect(controller.state.activePet!.stats, statsAtLimit);
    expect(controller.state.statusMessage, contains('배불러요'));
  });

  test('local progress round-trips care data and defaults legacy snapshots',
      () {
    final now = DateTime(2026, 7, 15, 10);
    final initial = MasilPetState.initial(firebaseReady: false);
    final snapshot = LocalProgressSnapshot(
      onboardingComplete: true,
      pois: starterPoiSeed,
      pets: initial.pets,
      eggs: initial.eggs,
      checkIns: const [],
      currentLocation: initial.currentLocation,
      locationVerified: false,
      locationVerifiedAt: null,
      activePetId: initial.activePetId,
      lastVisitedCategory: null,
      dialogueCountToday: 0,
      dialogueDay: now,
      careByPetId: {
        initial.activePetId: PetCareState(
          satiety: 61,
          cleanliness: 73,
          vitality: 82,
          updatedAt: now,
          dailyCountDay: now,
          feedCountToday: 1,
          playCountToday: 2,
          cleanCountToday: 3,
        ),
      },
      carePoints: 90,
      dailyCareRewardClaimKey: '2026-07-15',
    );

    final restored = LocalProgressSnapshot.fromMap(snapshot.toMap());
    final restoredCare = restored.careByPetId[initial.activePetId]!;

    expect(restoredCare.satiety, 61);
    expect(restoredCare.cleanliness, 73);
    expect(restoredCare.vitality, 82);
    expect(restoredCare.feedCountToday, 1);
    expect(restoredCare.playCountToday, 2);
    expect(restoredCare.cleanCountToday, 3);
    expect(restored.carePoints, 90);
    expect(restored.dailyCareRewardClaimKey, '2026-07-15');

    final legacy = LocalProgressSnapshot.fromMap(const {});
    expect(legacy.careByPetId, isEmpty);
    expect(legacy.carePoints, 0);
    expect(legacy.dailyCareRewardClaimKey, isNull);
  });
}
