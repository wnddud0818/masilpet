import 'package:flutter_test/flutter_test.dart';
import 'package:masilpet/src/data/local_progress_repository.dart';
import 'package:masilpet/src/data/masilpet_backend.dart';
import 'package:masilpet/src/models.dart';
import 'package:masilpet/src/seed_data.dart';
import 'package:masilpet/src/services.dart';
import 'package:masilpet/src/state.dart';

class MemoryLocalProgressRepository implements LocalProgressRepository {
  MemoryLocalProgressRepository([this.snapshot]);

  LocalProgressSnapshot? snapshot;

  @override
  Future<LocalProgressSnapshot?> loadProgress() async {
    return snapshot;
  }

  @override
  Future<void> saveProgress(LocalProgressSnapshot snapshot) async {
    this.snapshot = snapshot;
  }

  @override
  Future<void> clearProgress() async {
    snapshot = null;
  }
}

MasilPetController _controller({
  LocalProgressRepository? localProgressRepository,
  MasilPetBackend? backend,
  bool firebaseReady = false,
}) {
  return MasilPetController(
    firebaseReady: firebaseReady,
    locationService: const DeviceLocationService(),
    backend: backend,
    userRepository: null,
    localProgressRepository: localProgressRepository,
  );
}

class ResetProgressBackend implements MasilPetBackend {
  bool deleted = false;

  @override
  Future<void> ensureUserBootstrap() async {}

  @override
  Future<void> deleteUserProgress() async {
    deleted = true;
  }

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
    throw UnimplementedError();
  }
}

void main() {
  test('local progress snapshot round-trips gameplay data', () {
    final snapshot = LocalProgressSnapshot(
      onboardingComplete: true,
      pois: starterPoiSeed,
      pets: [
        Pet(
          id: 'pet-local',
          templateId: 'wave-naru',
          name: '파도나루',
          stage: PetStage.grown,
          level: 3,
          stats: const GrowthStats(
              exp: 240, mood: 64, knowledge: 22, affinity: 35),
          originRegionId: 'busan',
          hatchedAt: DateTime(2026, 6, 4, 10),
          lastInteractedAt: DateTime(2026, 6, 4, 11),
        ),
      ],
      eggs: [
        Egg(
          id: 'egg-local',
          templateId: 'harbor-maru',
          originRegionId: 'busan',
          progress: 2400,
          requiredSteps: 3500,
          status: EggStatus.incubating,
          createdAt: DateTime(2026, 6, 3),
        ),
      ],
      checkIns: [
        CheckIn(
          id: 'checkin-local',
          poiId: starterPoiSeed.first.id,
          regionId: 'busan',
          category: PoiCategory.nature,
          createdAt: DateTime(2026, 6, 4, 12),
          distanceMeters: 12,
          rewardApplied: true,
          reward: const CheckInReward(
            stats: GrowthStats(exp: 33, mood: 4, knowledge: 5, affinity: 6),
            eggProgress: 77,
          ),
        ),
      ],
      currentLocation: starterPoiSeed.first.coordinates,
      locationVerified: true,
      locationVerifiedAt: DateTime(2026, 6, 4, 12),
      activePetId: 'pet-local',
      lastVisitedCategory: PoiCategory.nature,
      dialogueCountToday: 2,
      dialogueDay: DateTime(2026, 6, 4),
    );

    final restored = LocalProgressSnapshot.fromMap(snapshot.toMap());

    expect(restored.onboardingComplete, isTrue);
    expect(restored.pets.single.id, 'pet-local');
    expect(restored.pets.single.stage, PetStage.grown);
    expect(restored.eggs.single.progress, 2400);
    expect(restored.checkIns.single.poiId, starterPoiSeed.first.id);
    expect(restored.checkIns.single.reward?.summaryLabel,
        'EXP +33 · 기분 +4 · 지식 +5 · 친밀도 +6 · 알 +77');
    expect(restored.locationVerified, isTrue);
    expect(restored.locationVerifiedAt, DateTime(2026, 6, 4, 12));
    expect(restored.lastVisitedCategory, PoiCategory.nature);
  });

  test('local progress snapshot tolerates malformed stored values', () {
    final restored = LocalProgressSnapshot.fromMap({
      'pois': [
        7,
        {
          'id': 42,
          'title': 99,
          'category': false,
          'coordinates': {'latitude': 'north', 'longitude': 129.16},
        },
      ],
      'pets': [
        {
          'id': 99,
          'name': false,
          'level': 'high',
          'stage': 12,
          'stats': {'exp': 'many', 'mood': null},
          'lastInteractedAt': 404,
        },
      ],
      'eggs': [
        {
          'progress': 'half',
          'requiredSteps': 'soon',
          'status': 17,
        },
      ],
      'checkIns': [
        {
          'category': 7,
          'distanceMeters': 'near',
          'createdAt': 'not-a-date',
        },
      ],
      'currentLocation': {'latitude': 'bad', 'longitude': 129.16},
      'activePetId': 42,
      'lastVisitedCategory': false,
      'dialogueCountToday': 'five',
    });

    expect(restored.pois, hasLength(1));
    expect(restored.pois.single.id, '');
    expect(restored.pois.single.title, '장소');
    expect(restored.pois.single.category, PoiCategory.other);
    expect(restored.pois.single.coordinates.latitude, 35.1587);
    expect(restored.pets.single.name, '마실펫');
    expect(restored.pets.single.level, 1);
    expect(restored.pets.single.stage, PetStage.baby);
    expect(restored.pets.single.stats.exp, 0);
    expect(restored.pets.single.lastInteractedAt, isNull);
    expect(restored.eggs.single.progress, 0);
    expect(restored.eggs.single.requiredSteps, 3500);
    expect(restored.eggs.single.status, EggStatus.incubating);
    expect(restored.checkIns.single.category, PoiCategory.other);
    expect(restored.checkIns.single.distanceMeters, 0);
    expect(restored.checkIns.single.reward, isNull);
    expect(restored.currentLocation.latitude, 35.1587);
    expect(restored.activePetId, '');
    expect(restored.lastVisitedCategory, isNull);
    expect(restored.dialogueCountToday, 0);
  });

  test('controller restores and saves local progress', () async {
    final repository = MemoryLocalProgressRepository(
      LocalProgressSnapshot(
        onboardingComplete: true,
        pois: starterPoiSeed,
        pets: [
          Pet(
            id: 'pet-restored',
            templateId: 'wave-naru',
            name: '파도나루',
            stage: PetStage.baby,
            level: 1,
            stats: const GrowthStats(
              exp: 20,
              mood: 20,
              knowledge: 5,
              affinity: 8,
            ),
            originRegionId: 'busan',
            hatchedAt: DateTime(2026, 6, 4),
            lastInteractedAt: null,
          ),
        ],
        eggs: const [],
        checkIns: const [],
        currentLocation: starterPoiSeed.first.coordinates,
        locationVerified: true,
        locationVerifiedAt: DateTime.now(),
        activePetId: 'pet-restored',
        lastVisitedCategory: null,
        dialogueCountToday: 0,
        dialogueDay: DateTime(2026, 6, 4),
      ),
    );
    final controller = _controller(localProgressRepository: repository);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.onboardingComplete, isTrue);
    expect(controller.state.activePetId, 'pet-restored');

    await controller.attemptCheckIn(starterPoiSeed.first);
    await Future<void>.delayed(Duration.zero);

    expect(repository.snapshot?.checkIns.length, 1);
    expect(repository.snapshot?.onboardingComplete, isTrue);
  });

  test('controller does not reuse stale verified location from storage',
      () async {
    final repository = MemoryLocalProgressRepository(
      LocalProgressSnapshot(
        onboardingComplete: true,
        pois: starterPoiSeed,
        pets: const [],
        eggs: const [],
        checkIns: const [],
        currentLocation: starterPoiSeed.first.coordinates,
        locationVerified: true,
        locationVerifiedAt: DateTime.now()
            .subtract(locationVerificationTtl + const Duration(minutes: 1)),
        activePetId: '',
        lastVisitedCategory: null,
        dialogueCountToday: 0,
        dialogueDay: DateTime.now(),
      ),
    );
    final controller = _controller(localProgressRepository: repository);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.locationVerified, isTrue);
    expect(controller.state.hasFreshVerifiedLocation, isFalse);

    await controller.attemptCheckIn(starterPoiSeed.first);

    expect(controller.state.todayCheckInCount, 0);
    expect(controller.state.statusMessage, contains('다시 확인'));
  });

  test('controller reset clears local and remote progress', () async {
    final repository = MemoryLocalProgressRepository(
      LocalProgressSnapshot(
        onboardingComplete: true,
        pois: starterPoiSeed,
        pets: [
          Pet(
            id: 'pet-reset',
            templateId: 'wave-naru',
            name: '파도나루',
            stage: PetStage.grown,
            level: 3,
            stats: const GrowthStats(
              exp: 240,
              mood: 64,
              knowledge: 22,
              affinity: 35,
            ),
            originRegionId: 'busan',
            hatchedAt: DateTime(2026, 6, 4),
            lastInteractedAt: null,
          ),
        ],
        eggs: const [],
        checkIns: [
          CheckIn(
            id: 'checkin-reset',
            poiId: starterPoiSeed.first.id,
            regionId: 'busan',
            category: PoiCategory.nature,
            createdAt: DateTime.now(),
            distanceMeters: 10,
            rewardApplied: true,
          ),
        ],
        currentLocation: starterPoiSeed.first.coordinates,
        locationVerified: true,
        locationVerifiedAt: DateTime.now(),
        activePetId: 'pet-reset',
        lastVisitedCategory: PoiCategory.nature,
        dialogueCountToday: 1,
        dialogueDay: DateTime.now(),
      ),
    );
    final backend = ResetProgressBackend();
    final controller = _controller(
      localProgressRepository: repository,
      backend: backend,
      firebaseReady: true,
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.onboardingComplete, isTrue);
    expect(controller.state.todayCheckInCount, 1);

    await controller.resetProgress();

    expect(backend.deleted, isTrue);
    expect(repository.snapshot, isNull);
    expect(controller.state.onboardingComplete, isFalse);
    expect(controller.state.todayCheckInCount, 0);
    expect(controller.state.activePetId, 'pet-starter-wave-naru');
    expect(controller.state.statusMessage, contains('기기와 서버 진행도'));
  });
}
