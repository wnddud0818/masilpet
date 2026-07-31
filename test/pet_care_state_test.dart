import 'dart:async';

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

class _FakeStepService extends DeviceStepService {
  _FakeStepService(this.events);

  final Stream<int> events;

  @override
  bool get isSupported => true;

  @override
  Future<Stream<int>> openStepCountStream() async => events;
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

  test('time creates cleanable waste and only temporary discomfort', () {
    final startedAt = DateTime(2026, 7, 14, 9);
    final later = startedAt.add(const Duration(hours: 16));
    final care = PetCareState(updatedAt: startedAt);

    final waiting = engine.resolve(care, later);
    expect(waiting.wasteCount, 2);
    expect(waiting.ailment, PetAilment.itchy);

    final cleaned = engine.afterWasteClean(waiting, later);
    expect(cleaned.wasteCount, 0);
    expect(cleaned.ailment, PetAilment.none);
    expect(cleaned.cleanliness, greaterThan(waiting.cleanliness));
  });

  test('food preferences, repeated meals, touch, and walking shape a pet', () {
    final now = DateTime(2026, 7, 14, 12);
    final template = starterPetTemplates.first;
    final favorite = engine.favoriteFoodFor(template);
    final disliked = engine.dislikedFoodFor(template);
    final preferredTouch = engine.preferredTouchFor(template);
    var care = PetCareState(updatedAt: now);

    care = engine.afterFeed(
      care,
      now,
      food: favorite,
      favoriteFood: favorite,
      dislikedFood: disliked,
    );
    expect(care.happiness, greaterThan(72));
    expect(care.gourmetScore, 3);
    expect(care.memories.first.category, PoiCategory.food);

    care = engine.afterFeed(
      care,
      now,
      food: favorite,
      favoriteFood: favorite,
      dislikedFood: disliked,
    );
    expect(care.ailment, PetAilment.tummyAche);

    care = engine.afterTouch(
      care,
      now,
      touch: preferredTouch,
      preferredTouch: preferredTouch,
    );
    expect(care.affectionScore, 3);

    care = engine.afterWalk(care, now, steps: 1800);
    expect(care.walkStepsToday, 1800);
    expect(care.adventureScore, greaterThan(0));
    expect(care.memories.first.title, contains('1800걸음'));
  });

  test('check-ins become companion memories and influence growth tendency', () {
    final now = DateTime(2026, 7, 14, 12);
    final care = engine.afterCheckIn(
      PetCareState(updatedAt: now),
      now,
      poi: starterPoiSeed.first,
      firstVisit: true,
    );

    expect(care.memories.single.title, contains('처음'));
    expect(care.memories.single.title, contains(starterPoiSeed.first.title));
    expect(care.adventureScore, 4);
  });

  test('TourAPI 장소 성향이 같은 이름의 펫 성향 점수를 올린다', () {
    final now = DateTime(2026, 7, 14, 12);
    Poi poiWith(PoiTendency tendency, {String? petGuide}) => Poi(
          id: 'poi-${tendency.name}',
          tourApiContentId: '1234567',
          title: '테스트 장소',
          regionId: 'seoul',
          category: PoiCategory.other,
          coordinates: const Coordinates(latitude: 37.5, longitude: 127.0),
          shortDescription: '테스트용 장소',
          tendency: tendency,
          petFriendlyGuide: petGuide,
        );

    // 쇼핑(A04)은 우아 성향으로, 체크인만으로 도달할 수 있어야 한다.
    final elegant = engine.afterCheckIn(
      PetCareState(updatedAt: now),
      now,
      poi: poiWith(PoiTendency.elegant),
      firstVisit: true,
    );
    expect(elegant.eleganceScore, 4);
    expect(elegant.adventureScore, 4);

    // 반려동물 동반 가능 장소는 교감 보너스가 더 붙는다.
    final together = engine.afterCheckIn(
      PetCareState(updatedAt: now),
      now,
      poi: poiWith(PoiTendency.affectionate, petGuide: '동반 가능'),
      firstVisit: true,
    );
    expect(together.affectionScore, 9);
    expect(together.memories.single.detail, contains('함께 들어갈 수 있는'));
  });

  test('대표 메뉴가 있으면 수첩에 그대로 남는다', () {
    final now = DateTime(2026, 7, 14, 12);
    final care = engine.afterCheckIn(
      PetCareState(updatedAt: now),
      now,
      poi: Poi(
        id: 'tourapi-2871024',
        tourApiContentId: '2871024',
        title: '가나돈까스의집',
        regionId: 'seoul',
        category: PoiCategory.food,
        coordinates: const Coordinates(latitude: 37.5099, longitude: 127.0377),
        shortDescription: '테스트용 음식점',
        tendency: PoiTendency.gourmet,
        signatureMenu: '돈까스',
      ),
      firstVisit: true,
    );

    expect(care.gourmetScore, 7);
    expect(care.memories.single.detail, contains('돈까스'));
  });

  test('pets staying home lose needs more slowly', () {
    final now = DateTime(2026, 7, 14, 9);
    final care = PetCareState(updatedAt: now);
    final later = now.add(const Duration(hours: 12));

    final companion = engine.resolve(care, later);
    final atHome = engine.resolve(care, later, stayingHome: true);

    expect(atHome.satiety, greaterThan(companion.satiety));
    expect(atHome.cleanliness, greaterThan(companion.cleanliness));
    expect(atHome.happiness, greaterThan(companion.happiness));
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
          happiness: 91,
          updatedAt: now,
          dailyCountDay: now,
          feedCountToday: 1,
          playCountToday: 2,
          cleanCountToday: 3,
          petCountToday: 4,
          wasteCount: 1,
          isSleeping: true,
          sleepStartedAt: now,
          ailment: PetAilment.tummyAche,
          ailmentUntil: now.add(const Duration(hours: 1)),
          lastFood: PetFood.fruit,
          sameFoodStreak: 2,
          walkStepsToday: 1234,
          walkDay: now,
          adventureScore: 8,
          gourmetScore: 6,
          knowledgeScore: 4,
          affectionScore: 9,
          eleganceScore: 3,
          memories: [
            PetMemory(
              id: 'memory-test',
              title: '바다를 본 날',
              detail: '파도 소리를 기억했어요.',
              createdAt: now,
              category: PoiCategory.nature,
            ),
          ],
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
    expect(restoredCare.happiness, 91);
    expect(restoredCare.feedCountToday, 1);
    expect(restoredCare.playCountToday, 2);
    expect(restoredCare.cleanCountToday, 3);
    expect(restoredCare.petCountToday, 4);
    expect(restoredCare.wasteCount, 1);
    expect(restoredCare.isSleeping, isTrue);
    expect(restoredCare.ailment, PetAilment.tummyAche);
    expect(restoredCare.lastFood, PetFood.fruit);
    expect(restoredCare.walkStepsToday, 1234);
    expect(restoredCare.memories.single.title, '바다를 본 날');
    expect(restored.carePoints, 90);
    expect(restored.dailyCareRewardClaimKey, '2026-07-15');

    final legacy = LocalProgressSnapshot.fromMap(const {});
    expect(legacy.careByPetId, isEmpty);
    expect(legacy.carePoints, 0);
    expect(legacy.dailyCareRewardClaimKey, isNull);
  });

  test('device step stream feeds egg and active companion progress', () async {
    final events = StreamController<int>();
    final controller = MasilPetController(
      firebaseReady: false,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      stepService: _FakeStepService(events.stream),
    );
    final eggBefore = controller.state.eggs.single.progress;

    await controller.startStepTracking();
    events.add(1000);
    events.add(1150);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.state.eggs.single.progress, eggBefore + 150);
    expect(controller.state.activePetCare!.walkStepsToday, 150);
    expect(controller.state.stepTrackingActive, isTrue);
    await events.close();
  });
}
