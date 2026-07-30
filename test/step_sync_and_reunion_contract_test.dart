import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:masilpet/src/data/masilpet_backend.dart';
import 'package:masilpet/src/models.dart';
import 'package:masilpet/src/services.dart';
import 'package:masilpet/src/state.dart';

class _FakeDeviceStepService extends DeviceStepService {
  _FakeDeviceStepService(this.events);

  final Stream<int> events;

  @override
  bool get isSupported => true;

  @override
  Future<Stream<int>> openStepCountStream() async => events;
}

class _StepSyncCall {
  const _StepSyncCall({
    required this.operationId,
    required this.deviceId,
    required this.dayKey,
    required this.observedCumulativeSteps,
    required this.observedAt,
  });

  final String operationId;
  final String deviceId;
  final String dayKey;
  final int observedCumulativeSteps;
  final DateTime observedAt;
}

class _RetryableCumulativeStepBackend
    implements MasilPetBackend, CumulativeStepSyncBackend {
  _RetryableCumulativeStepBackend({
    required this.creditedEggId,
    required this.companionPetId,
  });

  final String creditedEggId;
  final String companionPetId;
  final List<_StepSyncCall> calls = [];

  int? _acceptedCumulativeSteps;
  bool _failedDeltaOnce = false;

  @override
  Future<RemoteStepProgressResult> syncStepsV2({
    required String operationId,
    required String deviceId,
    required String dayKey,
    required int observedCumulativeSteps,
    required DateTime observedAt,
  }) async {
    calls.add(
      _StepSyncCall(
        operationId: operationId,
        deviceId: deviceId,
        dayKey: dayKey,
        observedCumulativeSteps: observedCumulativeSteps,
        observedAt: observedAt,
      ),
    );

    final accepted = _acceptedCumulativeSteps;
    if (accepted == null) {
      _acceptedCumulativeSteps = observedCumulativeSteps;
      return RemoteStepProgressResult(
        hatchableCount: 0,
        appliedStepDelta: 0,
        creditedEggId: creditedEggId,
        companionPetId: companionPetId,
        baselineInitialized: true,
      );
    }

    if (!_failedDeltaOnce) {
      _failedDeltaOnce = true;
      throw const MasilPetBackendException(
        code: 'unavailable',
        message: 'retry this operation',
      );
    }

    final delta = observedCumulativeSteps > accepted
        ? observedCumulativeSteps - accepted
        : 0;
    _acceptedCumulativeSteps = observedCumulativeSteps;
    return RemoteStepProgressResult(
      hatchableCount: 0,
      appliedStepDelta: delta,
      creditedEggId: creditedEggId,
      companionPetId: companionPetId,
    );
  }

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
    throw UnimplementedError();
  }

  @override
  Future<void> setActivePet(String petId) async {}

  @override
  Future<void> setActiveEgg(String eggId) async {}
}

class _AuthoritativeInteractionBackend implements MasilPetBackend {
  static const authoritativeStats = <String, GrowthStats>{
    'play': GrowthStats(
      exp: 101,
      mood: 102,
      knowledge: 103,
      affinity: 104,
    ),
    'clean': GrowthStats(
      exp: 201,
      mood: 202,
      knowledge: 203,
      affinity: 204,
    ),
    'sleep': GrowthStats(
      exp: 301,
      mood: 302,
      knowledge: 303,
      affinity: 304,
    ),
    'touch': GrowthStats(
      exp: 401,
      mood: 402,
      knowledge: 403,
      affinity: 404,
    ),
  };

  final List<({String petId, String actionType})> calls = [];

  @override
  Future<RemotePetInteractionResult> interactWithPet({
    required String petId,
    required String actionType,
  }) async {
    calls.add((petId: petId, actionType: actionType));
    final stats = authoritativeStats[actionType];
    if (stats == null) {
      throw StateError('Unexpected interaction action: $actionType');
    }
    return RemotePetInteractionResult(
      // Deliberately very different: an authoritative updatedPet must replace
      // local/reward arithmetic instead of being added to it.
      reward: const GrowthStats(
        exp: 9000,
        mood: 9000,
        knowledge: 9000,
        affinity: 9000,
      ),
      updatedPet: RemotePetUpdate(
        id: petId,
        stats: stats,
        level: calls.length + 10,
        stage: PetStage.evolved,
      ),
    );
  }

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
  Future<void> setActivePet(String petId) async {}

  @override
  Future<void> setActiveEgg(String eggId) async {}
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out while waiting for an asynchronous test condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Pet _reservePet(Pet activePet, DateTime now) {
  return Pet(
    id: 'pet-reserve-step-contract',
    templateId: activePet.templateId,
    name: '${activePet.name}-reserve',
    stage: PetStage.baby,
    level: 1,
    stats: const GrowthStats(
      exp: 3,
      mood: 4,
      knowledge: 5,
      affinity: 6,
    ),
    originRegionId: activePet.originRegionId,
    hatchedAt: now,
    lastInteractedAt: null,
  );
}

void _expectStats(GrowthStats actual, GrowthStats expected) {
  expect(actual.exp, expected.exp);
  expect(actual.mood, expected.mood);
  expect(actual.knowledge, expected.knowledge);
  expect(actual.affinity, expected.affinity);
}

void main() {
  group('cumulative step synchronization contract', () {
    test('RemoteStepProgressResult parses all V2 routing and reset fields', () {
      final result = RemoteStepProgressResult.fromMap({
        'hatchableCount': 2,
        'appliedStepDelta': 640,
        'creditedEggId': 'egg-active-v2',
        'companionPetId': 'pet-active-v2',
        'baselineInitialized': true,
        'counterReset': false,
        'updatedPet': {
          'id': 'pet-active-v2',
          'stats': {
            'exp': 31,
            'mood': 27,
            'knowledge': 14,
            'affinity': 22,
          },
          'level': 3,
          'stage': 'grown',
        },
      });

      expect(result.hatchableCount, 2);
      expect(result.appliedStepDelta, 640);
      expect(result.creditedEggId, 'egg-active-v2');
      expect(result.companionPetId, 'pet-active-v2');
      expect(result.baselineInitialized, isTrue);
      expect(result.counterReset, isFalse);
      expect(result.updatedPet?.id, 'pet-active-v2');
      expect(result.updatedPet?.stats.affinity, 22);
      expect(result.updatedPet?.level, 3);
      expect(result.updatedPet?.stage, PetStage.grown);

      final resetResult = RemoteStepProgressResult.fromMap({
        'hatchableCount': 0,
        'appliedStepDelta': 0,
        'counterReset': true,
      });
      expect(resetResult.baselineInitialized, isFalse);
      expect(resetResult.counterReset, isTrue);
    });

    test(
      'first observation is baseline and retry applies one delta only to '
      'the selected egg and companion',
      () async {
        final events = StreamController<int>();
        final initial = MasilPetState.initial(firebaseReady: false);
        final activePet = initial.activePet!;
        final activeEgg = initial.activeEgg!;
        final backend = _RetryableCumulativeStepBackend(
          creditedEggId: activeEgg.id,
          companionPetId: activePet.id,
        );
        final controller = MasilPetController(
          firebaseReady: false,
          locationService: const DeviceLocationService(),
          backend: backend,
          userRepository: null,
          stepService: _FakeDeviceStepService(events.stream),
        );
        final now = DateTime.now();
        final reservePet = _reservePet(activePet, now);
        final reserveEgg = Egg(
          id: 'egg-reserve-step-contract',
          templateId: activeEgg.templateId,
          originRegionId: activeEgg.originRegionId,
          progress: 350,
          requiredSteps: 3500,
          status: EggStatus.incubating,
          createdAt: now,
        );
        controller.state = controller.state.copyWith(
          pets: [activePet, reservePet],
          eggs: [activeEgg, reserveEgg],
          careByPetId: {
            activePet.id: PetCareState.initial(now),
            reservePet.id: PetCareState.initial(now),
          },
          activePetId: activePet.id,
          activeEggId: activeEgg.id,
        );
        final activeAffinityBefore = activePet.stats.affinity;
        final reserveAffinityBefore = reservePet.stats.affinity;

        await controller.startStepTracking();
        events.add(1000);
        await _waitUntil(
          () => backend.calls.length == 1 && !controller.state.isBusy,
        );

        expect(controller.state.activeEgg!.progress, activeEgg.progress);
        expect(controller.state.activePetCare!.walkStepsToday, 0);

        events.add(1600);
        await _waitUntil(
          () => backend.calls.length == 2 && !controller.state.isBusy,
        );
        await Future<void>.delayed(Duration.zero);

        final failedOperation = backend.calls[1];
        expect(controller.state.activeEgg!.progress, activeEgg.progress);
        expect(controller.state.deviceStepsWaiting, 600);

        await controller.flushDeviceSteps();

        expect(backend.calls, hasLength(3));
        final retriedOperation = backend.calls[2];
        expect(retriedOperation.operationId, failedOperation.operationId);
        expect(retriedOperation.deviceId, failedOperation.deviceId);
        expect(retriedOperation.dayKey, failedOperation.dayKey);
        expect(
          retriedOperation.observedCumulativeSteps,
          failedOperation.observedCumulativeSteps,
        );
        expect(retriedOperation.observedAt, failedOperation.observedAt);

        final updatedActiveEgg = controller.state.eggs.singleWhere(
          (egg) => egg.id == activeEgg.id,
        );
        final unchangedReserveEgg = controller.state.eggs.singleWhere(
          (egg) => egg.id == reserveEgg.id,
        );
        final updatedActivePet = controller.state.pets.singleWhere(
          (pet) => pet.id == activePet.id,
        );
        final unchangedReservePet = controller.state.pets.singleWhere(
          (pet) => pet.id == reservePet.id,
        );

        expect(updatedActiveEgg.progress, activeEgg.progress + 600);
        expect(unchangedReserveEgg.progress, reserveEgg.progress);
        expect(updatedActivePet.stats.affinity, activeAffinityBefore + 1);
        expect(unchangedReservePet.stats.affinity, reserveAffinityBefore);
        expect(
          controller.state.careForPet(activePet.id)!.walkStepsToday,
          600,
        );
        expect(
          controller.state.careForPet(reservePet.id)!.walkStepsToday,
          0,
        );
        expect(controller.state.deviceStepsWaiting, 0);

        controller.dispose();
        await events.close();
      },
    );
  });

  test(
    'local duplicate-template hatch reunites without replacing the companion',
    () async {
      final controller = MasilPetController(
        firebaseReady: false,
        locationService: const DeviceLocationService(),
        backend: null,
        userRepository: null,
      );
      final activeBefore = controller.state.activePet!;
      final careBefore = controller.state.careForPet(activeBefore.id)!;
      final petCountBefore = controller.state.pets.length;
      final reunionEgg = Egg(
        id: 'egg-reunion-contract',
        templateId: activeBefore.templateId,
        originRegionId: activeBefore.originRegionId,
        progress: 3500,
        requiredSteps: 3500,
        status: EggStatus.hatchable,
        createdAt: DateTime.now(),
        incubationBondXp: 4,
        imprints: const [PoiCategory.nature],
      );
      controller.state = controller.state.copyWith(
        eggs: [reunionEgg],
        activeEggId: reunionEgg.id,
      );

      final outcome = await controller.hatchEgg(reunionEgg.id);

      expect(outcome?.reunion, isTrue);
      expect(outcome?.petId, activeBefore.id);
      expect(controller.state.activePetId, activeBefore.id);
      expect(controller.state.pets, hasLength(petCountBefore));
      expect(controller.state.eggs, isEmpty);

      final reunitedPet = controller.state.pets.singleWhere(
        (pet) => pet.id == activeBefore.id,
      );
      final reunitedCare = controller.state.careForPet(activeBefore.id)!;
      expect(reunitedPet.reunionCount, activeBefore.reunionCount + 1);
      expect(reunitedPet.stats.affinity, activeBefore.stats.affinity + 5);
      expect(reunitedCare.affectionScore, careBefore.affectionScore + 5);
      expect(reunitedCare.memories.length, careBefore.memories.length + 1);
      expect(
        reunitedCare.memories.any(
          (memory) => memory.id == 'reunion-${reunionEgg.id}',
        ),
        isTrue,
      );

      controller.dispose();
    },
  );

  test(
    'online care actions use the right API action and authoritative pet stats',
    () async {
      final backend = _AuthoritativeInteractionBackend();
      final controller = MasilPetController(
        firebaseReady: true,
        locationService: const DeviceLocationService(),
        backend: backend,
        userRepository: null,
      );
      final petId = controller.state.activePetId;
      expect(controller.state.activePetCare!.bondedDays, 0);
      expect(controller.state.activePetCare!.lastBondedDay, isNull);

      await controller.playActivePet();

      expect(backend.calls.last, (petId: petId, actionType: 'play'));
      _expectStats(
        controller.state.activePet!.stats,
        _AuthoritativeInteractionBackend.authoritativeStats['play']!,
      );
      expect(controller.state.activePet!.level, 11);
      expect(controller.state.activePet!.stage, PetStage.evolved);
      expect(controller.state.activePetCare!.playCountToday, 1);
      expect(controller.state.activePetCare!.bondedDays, 1);
      expect(controller.state.activePetCare!.lastBondedDay, isNotNull);

      await controller.cleanActivePet();

      expect(backend.calls.last, (petId: petId, actionType: 'clean'));
      _expectStats(
        controller.state.activePet!.stats,
        _AuthoritativeInteractionBackend.authoritativeStats['clean']!,
      );
      expect(controller.state.activePet!.level, 12);
      expect(controller.state.activePetCare!.cleanCountToday, 1);
      expect(controller.state.activePetCare!.bondedDays, 1);
      expect(controller.state.activePetCare!.lastBondedDay, isNotNull);

      await controller.sleepActivePet();

      expect(backend.calls.last, (petId: petId, actionType: 'sleep'));
      _expectStats(
        controller.state.activePet!.stats,
        _AuthoritativeInteractionBackend.authoritativeStats['sleep']!,
      );
      expect(controller.state.activePet!.level, 13);
      expect(controller.state.activePetCare!.isSleeping, isTrue);
      expect(controller.state.activePetCare!.bondedDays, 1);
      expect(controller.state.activePetCare!.lastBondedDay, isNotNull);

      await controller.touchActivePet(PetTouch.hug);

      expect(backend.calls.last, (petId: petId, actionType: 'touch'));
      _expectStats(
        controller.state.activePet!.stats,
        _AuthoritativeInteractionBackend.authoritativeStats['touch']!,
      );
      expect(controller.state.activePet!.level, 14);
      expect(controller.state.activePetCare!.petCountToday, 1);
      expect(controller.state.activePetCare!.isSleeping, isFalse);
      expect(controller.state.activePetCare!.bondedDays, 1);
      expect(controller.state.activePetCare!.lastBondedDay, isNotNull);
      expect(
        backend.calls.map((call) => call.actionType),
        ['play', 'clean', 'sleep', 'touch'],
      );
      expect(
        backend.calls.map((call) => call.petId).toSet(),
        {petId},
      );

      controller.dispose();
    },
  );
}
