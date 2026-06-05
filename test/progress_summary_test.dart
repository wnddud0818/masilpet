import 'package:flutter_test/flutter_test.dart';
import 'package:masilpet/src/data/masilpet_backend.dart';
import 'package:masilpet/src/models.dart';
import 'package:masilpet/src/seed_data.dart';
import 'package:masilpet/src/services.dart';
import 'package:masilpet/src/state.dart';

class FakeLocationService extends DeviceLocationService {
  const FakeLocationService();

  @override
  Future<Coordinates> readCurrentLocation() async {
    return busanPoiSeed.first.coordinates;
  }
}

MasilPetController _controller({
  DeviceLocationService locationService = const DeviceLocationService(),
  MasilPetBackend? backend,
}) {
  return MasilPetController(
    firebaseReady: false,
    locationService: locationService,
    backend: backend,
    userRepository: null,
  );
}

class FakeStepBackend implements MasilPetBackend {
  const FakeStepBackend({
    required this.appliedStepDelta,
    this.error,
  });

  final int appliedStepDelta;
  final MasilPetBackendException? error;

  @override
  Future<void> ensureUserBootstrap() async {}

  @override
  Future<void> deleteUserProgress() async {}

  @override
  Future<List<RemotePoi>> getNearbyPois(Coordinates location) async => const [];

  @override
  Future<RemoteCheckInResult> attemptCheckIn({
    required String poiId,
    required Coordinates location,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<RemoteStepProgressResult> applyStepProgress(int stepDelta) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return RemoteStepProgressResult(
      hatchableCount: 0,
      appliedStepDelta: appliedStepDelta,
    );
  }

  @override
  Future<String> hatchEgg(String eggId) async {
    throw UnimplementedError();
  }

  @override
  Future<RemotePetInteractionResult> interactWithPet({
    required String petId,
    required String actionType,
  }) async {
    throw UnimplementedError();
  }
}

class FakeHatchErrorBackend implements MasilPetBackend {
  const FakeHatchErrorBackend({
    required this.error,
  });

  final MasilPetBackendException error;

  @override
  Future<void> ensureUserBootstrap() async {}

  @override
  Future<void> deleteUserProgress() async {}

  @override
  Future<List<RemotePoi>> getNearbyPois(Coordinates location) async => const [];

  @override
  Future<RemoteCheckInResult> attemptCheckIn({
    required String poiId,
    required Coordinates location,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<RemoteStepProgressResult> applyStepProgress(int stepDelta) async {
    return RemoteStepProgressResult(
      hatchableCount: 1,
      appliedStepDelta: stepDelta,
    );
  }

  @override
  Future<String> hatchEgg(String eggId) async {
    throw error;
  }

  @override
  Future<RemotePetInteractionResult> interactWithPet({
    required String petId,
    required String actionType,
  }) async {
    throw UnimplementedError();
  }
}

class FakeCheckInBackend implements MasilPetBackend {
  const FakeCheckInBackend({
    required this.result,
  });

  final RemoteCheckInResult result;

  @override
  Future<void> ensureUserBootstrap() async {}

  @override
  Future<void> deleteUserProgress() async {}

  @override
  Future<List<RemotePoi>> getNearbyPois(Coordinates location) async => const [];

  @override
  Future<RemoteCheckInResult> attemptCheckIn({
    required String poiId,
    required Coordinates location,
  }) async {
    return result;
  }

  @override
  Future<RemoteStepProgressResult> applyStepProgress(int stepDelta) async {
    throw UnimplementedError();
  }

  @override
  Future<String> hatchEgg(String eggId) async {
    throw UnimplementedError();
  }

  @override
  Future<RemotePetInteractionResult> interactWithPet({
    required String petId,
    required String actionType,
  }) async {
    throw UnimplementedError();
  }
}

class FakeCheckInErrorBackend implements MasilPetBackend {
  const FakeCheckInErrorBackend({
    required this.error,
  });

  final MasilPetBackendException error;

  @override
  Future<void> ensureUserBootstrap() async {}

  @override
  Future<void> deleteUserProgress() async {}

  @override
  Future<List<RemotePoi>> getNearbyPois(Coordinates location) async => const [];

  @override
  Future<RemoteCheckInResult> attemptCheckIn({
    required String poiId,
    required Coordinates location,
  }) async {
    throw error;
  }

  @override
  Future<RemoteStepProgressResult> applyStepProgress(int stepDelta) async {
    throw UnimplementedError();
  }

  @override
  Future<String> hatchEgg(String eggId) async {
    throw UnimplementedError();
  }

  @override
  Future<RemotePetInteractionResult> interactWithPet({
    required String petId,
    required String actionType,
  }) async {
    throw UnimplementedError();
  }
}

class FakeInteractionBackend implements MasilPetBackend {
  const FakeInteractionBackend({
    required this.result,
  });

  final RemotePetInteractionResult result;

  @override
  Future<void> ensureUserBootstrap() async {}

  @override
  Future<void> deleteUserProgress() async {}

  @override
  Future<List<RemotePoi>> getNearbyPois(Coordinates location) async => const [];

  @override
  Future<RemoteCheckInResult> attemptCheckIn({
    required String poiId,
    required Coordinates location,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<RemoteStepProgressResult> applyStepProgress(int stepDelta) async {
    throw UnimplementedError();
  }

  @override
  Future<String> hatchEgg(String eggId) async {
    throw UnimplementedError();
  }

  @override
  Future<RemotePetInteractionResult> interactWithPet({
    required String petId,
    required String actionType,
  }) async {
    return result;
  }
}

class FakeInteractionErrorBackend implements MasilPetBackend {
  const FakeInteractionErrorBackend({
    required this.error,
  });

  final MasilPetBackendException error;

  @override
  Future<void> ensureUserBootstrap() async {}

  @override
  Future<void> deleteUserProgress() async {}

  @override
  Future<List<RemotePoi>> getNearbyPois(Coordinates location) async => const [];

  @override
  Future<RemoteCheckInResult> attemptCheckIn({
    required String poiId,
    required Coordinates location,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<RemoteStepProgressResult> applyStepProgress(int stepDelta) async {
    throw UnimplementedError();
  }

  @override
  Future<String> hatchEgg(String eggId) async {
    throw UnimplementedError();
  }

  @override
  Future<RemotePetInteractionResult> interactWithPet({
    required String petId,
    required String actionType,
  }) async {
    throw error;
  }
}

void main() {
  test('initial state exposes collection and check-in summaries', () {
    final state = MasilPetState.initial(firebaseReady: false);

    expect(state.discoveredTemplateIds, contains('wave-naru'));
    expect(state.dexCompletionRatio, greaterThan(0));
    expect(state.nearestPoi, busanPoiSeed.first);
    expect(state.locationVerified, isFalse);
    expect(state.hasFreshVerifiedLocation, isFalse);
    expect(state.canCheckInToday(busanPoiSeed.first), isFalse);
    expect(state.todayAvailableCheckInCount, 0);
    expect(state.todayCheckIns, isEmpty);
    expect(state.todayVisitedCategoryCount, 0);
    expect(state.unvisitedPoiCountToday, busanPoiSeed.length);
    expect(state.nextEgg?.id, 'egg-harbor-maru');
    expect(state.nextRecommendedPoi, isNotNull);
  });

  test('check-in requires verified current location', () async {
    final controller = _controller();

    await controller.attemptCheckIn(busanPoiSeed.first);

    expect(controller.state.todayCheckInCount, 0);
    expect(controller.state.statusMessage, contains('현재 위치'));
  });

  test('expired location verification cannot be used for check-in', () async {
    final expired = MasilPetState.initial(firebaseReady: false).copyWith(
      locationVerified: true,
      locationVerifiedAt: DateTime.now()
          .subtract(locationVerificationTtl + const Duration(seconds: 1)),
    );

    expect(expired.hasFreshVerifiedLocation, isFalse);
    expect(expired.canCheckInToday(busanPoiSeed.first), isFalse);
  });

  test('successful check-in updates daily summary and readiness', () async {
    final controller = _controller(
      locationService: const FakeLocationService(),
    );

    await controller.useDeviceLocation();
    expect(controller.state.hasFreshVerifiedLocation, isTrue);
    await controller.attemptCheckIn(busanPoiSeed.first);

    expect(controller.state.todayCheckInCount, 1);
    expect(controller.state.todayCheckIns.single.poiId, busanPoiSeed.first.id);
    expect(
      controller.state.todayVisitedCategories,
      contains(PoiCategory.nature),
    );
    expect(controller.state.unvisitedPoiCountToday, busanPoiSeed.length - 1);
    expect(
        controller.state.nextRecommendedPoi?.id, isNot(busanPoiSeed.first.id));
    expect(controller.state.hasCheckedInToday(busanPoiSeed.first), isTrue);
    expect(controller.state.launchReadinessScore, greaterThanOrEqualTo(60));
  });

  test('recent check-ins are sorted by newest visit first', () {
    final older = DateTime.now().subtract(const Duration(days: 1));
    final newer = DateTime.now();
    final state = MasilPetState.initial(firebaseReady: false).copyWith(
      checkIns: [
        CheckIn(
          id: 'older-checkin',
          poiId: busanPoiSeed.first.id,
          regionId: busanPoiSeed.first.regionId,
          category: busanPoiSeed.first.category,
          createdAt: older,
          distanceMeters: 24,
          rewardApplied: true,
        ),
        CheckIn(
          id: 'newer-checkin',
          poiId: busanPoiSeed[1].id,
          regionId: busanPoiSeed[1].regionId,
          category: busanPoiSeed[1].category,
          createdAt: newer,
          distanceMeters: 18,
          rewardApplied: true,
        ),
      ],
    );

    expect(state.recentCheckIns.first.id, 'newer-checkin');
    expect(state.recentCheckIns.last.id, 'older-checkin');
  });

  test('remote check-in mirrors the server reward, egg progress, and pet patch',
      () async {
    final controller = _controller(
      locationService: const FakeLocationService(),
      backend: const FakeCheckInBackend(
        result: RemoteCheckInResult(
          success: true,
          distanceMeters: 12,
          reward: GrowthStats(exp: 77, mood: 3, knowledge: 4, affinity: 5),
          eggProgress: 123,
          updatedPet: RemotePetUpdate(
            id: 'pet-starter-wave-naru',
            stats: GrowthStats(exp: 91, mood: 23, knowledge: 9, affinity: 13),
            level: 3,
            stage: PetStage.grown,
          ),
        ),
      ),
    );

    await controller.useDeviceLocation();
    await controller.attemptCheckIn(busanPoiSeed.first);

    final pet = controller.state.activePet!;
    final egg = controller.state.eggs.singleWhere(
      (item) => item.id == 'egg-harbor-maru',
    );
    expect(pet.stats.exp, 91);
    expect(pet.stats.mood, 23);
    expect(pet.stats.knowledge, 9);
    expect(pet.stats.affinity, 13);
    expect(pet.level, 3);
    expect(pet.stage, PetStage.grown);
    expect(egg.progress, 1323);
    expect(controller.state.todayCheckInCount, 1);
    expect(controller.state.statusMessage, contains('EXP +77'));
  });

  test('remote duplicate check-in shows the server rejection reason', () async {
    final controller = _controller(
      locationService: const FakeLocationService(),
      backend: const FakeCheckInErrorBackend(
        error: MasilPetBackendException(
          code: 'already-exists',
          message: 'Already checked in to this POI today.',
        ),
      ),
    );

    await controller.useDeviceLocation();
    await controller.attemptCheckIn(busanPoiSeed.first);

    expect(controller.state.todayCheckInCount, 0);
    expect(controller.state.statusMessage, contains('이미'));
    expect(controller.state.statusMessage, contains(busanPoiSeed.first.title));
  });

  test('remote out-of-range check-in shows the server distance', () async {
    final controller = _controller(
      locationService: const FakeLocationService(),
      backend: const FakeCheckInErrorBackend(
        error: MasilPetBackendException(
          code: 'failed-precondition',
          message: 'User is outside check-in radius.',
          details: {'distanceMeters': 321},
        ),
      ),
    );

    await controller.useDeviceLocation();
    await controller.attemptCheckIn(busanPoiSeed.first);

    expect(controller.state.todayCheckInCount, 0);
    expect(controller.state.statusMessage, contains('321m'));
    expect(controller.state.statusMessage, contains('150m'));
  });

  test('remote daily check-in cap is surfaced clearly', () async {
    final controller = _controller(
      locationService: const FakeLocationService(),
      backend: const FakeCheckInErrorBackend(
        error: MasilPetBackendException(
          code: 'failed-precondition',
          message: 'Daily check-in limit reached.',
        ),
      ),
    );

    await controller.useDeviceLocation();
    await controller.attemptCheckIn(busanPoiSeed.first);

    expect(controller.state.todayCheckInCount, 0);
    expect(controller.state.statusMessage, contains('오늘 가능한 서버 체크인 횟수'));
  });

  test('step progress mirrors the server applied daily allowance', () async {
    final controller = _controller(
      backend: const FakeStepBackend(appliedStepDelta: 400),
    );

    await controller.addStepProgress(1000);

    final egg = controller.state.eggs.singleWhere(
      (item) => item.id == 'egg-harbor-maru',
    );
    expect(egg.progress, 1600);
    expect(controller.state.statusMessage, contains('400'));
  });

  test('remote daily step progress cap is surfaced clearly', () async {
    final controller = _controller(
      backend: const FakeStepBackend(
        appliedStepDelta: 0,
        error: MasilPetBackendException(
          code: 'failed-precondition',
          message: 'Daily step progress limit reached.',
        ),
      ),
    );
    final before = controller.state.eggs.single.progress;

    await controller.addStepProgress(1000);

    expect(controller.state.eggs.single.progress, before);
    expect(controller.state.statusMessage, contains('오늘 서버에 반영할 수 있는 걸음 수'));
  });

  test('remote hatch precondition is surfaced clearly', () async {
    final controller = _controller(
      backend: const FakeHatchErrorBackend(
        error: MasilPetBackendException(
          code: 'failed-precondition',
          message: 'Egg is not hatchable yet.',
        ),
      ),
    );

    await controller.addStepProgress(2300);
    final egg = controller.state.eggs.single;
    expect(egg.status, EggStatus.hatchable);

    await controller.hatchEgg(egg.id);

    expect(controller.state.eggs.single.id, egg.id);
    expect(
      controller.state.pets.where((pet) => pet.templateId == egg.templateId),
      isEmpty,
    );
    expect(controller.state.statusMessage, contains('서버 기준으로 부화할 수 없는 알'));
  });

  test('talking mirrors the server interaction reward and pet update',
      () async {
    final controller = _controller(
      backend: const FakeInteractionBackend(
        result: RemotePetInteractionResult(
          reward: GrowthStats(exp: 30, mood: 1, knowledge: 2, affinity: 3),
          updatedPet: RemotePetUpdate(
            stats: GrowthStats(exp: 50, mood: 21, knowledge: 7, affinity: 11),
            level: 4,
            stage: PetStage.grown,
          ),
        ),
      ),
    );

    await controller.talkWithActivePet();

    final pet = controller.state.activePet!;
    expect(pet.stats.exp, 50);
    expect(pet.stats.mood, 21);
    expect(pet.stats.knowledge, 7);
    expect(pet.stats.affinity, 11);
    expect(pet.level, 4);
    expect(pet.stage, PetStage.grown);
    expect(controller.state.dialogueCountToday, 1);
  });

  test('feeding uses the server reward when no pet patch is returned',
      () async {
    final controller = _controller(
      backend: const FakeInteractionBackend(
        result: RemotePetInteractionResult(
          reward: GrowthStats(exp: 10, mood: 20, knowledge: 30, affinity: 40),
          updatedPet: null,
        ),
      ),
    );

    final before = controller.state.activePet!;
    await controller.feedActivePet();

    final pet = controller.state.activePet!;
    expect(pet.stats.exp, before.stats.exp + 10);
    expect(pet.stats.mood, before.stats.mood + 20);
    expect(pet.stats.knowledge, before.stats.knowledge + 30);
    expect(pet.stats.affinity, before.stats.affinity + 40);
  });

  test('remote missing pet interaction is surfaced clearly', () async {
    final controller = _controller(
      backend: const FakeInteractionErrorBackend(
        error: MasilPetBackendException(
          code: 'not-found',
          message: 'Pet not found.',
        ),
      ),
    );
    final before = controller.state.activePet!;

    await controller.feedActivePet();

    final pet = controller.state.activePet!;
    expect(pet.stats.exp, before.stats.exp);
    expect(pet.stats.mood, before.stats.mood);
    expect(controller.state.statusMessage, contains('마실펫을 찾을 수 없습니다'));
  });
}
