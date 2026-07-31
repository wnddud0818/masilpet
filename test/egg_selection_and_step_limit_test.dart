import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:masilpet/src/data/masilpet_backend.dart';
import 'package:masilpet/src/models.dart';
import 'package:masilpet/src/seed_data.dart';
import 'package:masilpet/src/services.dart';
import 'package:masilpet/src/state.dart';

MasilPetController _controller({MasilPetBackend? backend}) {
  return MasilPetController(
    firebaseReady: false,
    locationService: const DeviceLocationService(),
    backend: backend,
    userRepository: null,
  );
}

Egg _egg({
  required String id,
  required EggStatus status,
  required int progress,
  int requiredSteps = 3500,
}) {
  return Egg(
    id: id,
    templateId: starterPetTemplates.first.id,
    originRegionId: 'korea',
    progress: progress,
    requiredSteps: requiredSteps,
    status: status,
    createdAt: DateTime(2026, 7, 14, 9),
  );
}

class _FakeDeviceStepService extends DeviceStepService {
  _FakeDeviceStepService(this.events);

  final Stream<int> events;

  @override
  bool get isSupported => true;

  @override
  Future<Stream<int>> openStepCountStream() async => events;
}

/// 오늘 상한에 걸려 새 걸음을 하나도 싣지 못하는 상황을 재현한다.
class _DailyLimitStepBackend
    implements MasilPetBackend, CumulativeStepSyncBackend {
  int calls = 0;

  @override
  Future<RemoteStepProgressResult> syncStepsV2({
    required String operationId,
    required String deviceId,
    required String dayKey,
    required int observedCumulativeSteps,
    required DateTime observedAt,
  }) async {
    calls += 1;
    return const RemoteStepProgressResult(
      hatchableCount: 0,
      appliedStepDelta: 0,
      dailyLimitReached: true,
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
  }) async =>
      throw UnimplementedError();

  @override
  Future<RemoteStepProgressResult> applyStepProgress(int stepDelta) async =>
      throw UnimplementedError();

  @override
  Future<String> hatchEgg(String eggId) async => throw UnimplementedError();

  @override
  Future<RemotePetInteractionResult> interactWithPet({
    required String petId,
    required String actionType,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> setActivePet(String petId) async {}

  @override
  Future<void> setActiveEgg(String eggId) async {}
}

void main() {
  group('active egg selection', () {
    test('부화 준비를 마친 알보다 아직 품고 있는 알을 먼저 고른다', () {
      final ready = _egg(id: 'egg-ready', status: EggStatus.hatchable, progress: 3500);
      final incubating =
          _egg(id: 'egg-incubating', status: EggStatus.incubating, progress: 100);

      // 준비된 알이 선택돼 있어도 품고 있는 알로 넘어간다.
      expect(
        MasilPetState.selectActiveEgg([ready, incubating], ready.id)?.id,
        incubating.id,
      );
      // 품고 있는 알이 하나도 없을 때만 준비된 알을 가리킨다.
      expect(
        MasilPetState.selectActiveEgg([ready], ready.id)?.id,
        ready.id,
      );
      expect(MasilPetState.selectActiveEgg(const [], 'egg-ready'), isNull);
    });

    test('같은 상태라면 부화가 가장 가까운 알을 고르고 선택은 존중한다', () {
      final far = _egg(id: 'egg-far', status: EggStatus.incubating, progress: 100);
      final near = _egg(id: 'egg-near', status: EggStatus.incubating, progress: 3000);

      expect(MasilPetState.selectActiveEgg([far, near], '')?.id, near.id);
      expect(MasilPetState.selectActiveEgg([far, near], far.id)?.id, far.id);
    });

    test('부화 준비를 마친 알이 골라져 있어도 걸음은 품고 있는 알에 쌓인다', () async {
      final controller = _controller();
      final ready = _egg(id: 'egg-ready', status: EggStatus.hatchable, progress: 3500);
      final incubating =
          _egg(id: 'egg-incubating', status: EggStatus.incubating, progress: 100);
      controller.state = controller.state.copyWith(
        eggs: [ready, incubating],
        activeEggId: ready.id,
      );

      await controller.addStepProgress(250);

      expect(controller.state.activeEggId, incubating.id);
      expect(
        controller.state.eggs.singleWhere((egg) => egg.id == incubating.id).progress,
        350,
      );
      expect(
        controller.state.eggs.singleWhere((egg) => egg.id == ready.id).progress,
        ready.progress,
      );

      controller.dispose();
    });

    test('부화해도 이미 품고 있던 다른 알의 선택은 유지된다', () async {
      final controller = _controller();
      final ready = _egg(id: 'egg-ready', status: EggStatus.hatchable, progress: 3500);
      final keeping =
          _egg(id: 'egg-keeping', status: EggStatus.incubating, progress: 100);
      final closer =
          _egg(id: 'egg-closer', status: EggStatus.incubating, progress: 3400);
      controller.state = controller.state.copyWith(
        eggs: [ready, keeping, closer],
        activeEggId: keeping.id,
      );

      await controller.hatchEgg(ready.id);

      // 부화한 알만 빠지고, 고르고 있던 알은 그대로 남는다.
      expect(controller.state.activeEggId, keeping.id);

      controller.dispose();
    });
  });

  group('daily step limit', () {
    test('오늘 상한에 걸리면 대기 걸음을 비우고 재시도를 멈춘다', () async {
      final backend = _DailyLimitStepBackend();
      final events = StreamController<int>();
      final controller = MasilPetController(
        firebaseReady: false,
        locationService: const DeviceLocationService(),
        backend: backend,
        userRepository: null,
        stepService: _FakeDeviceStepService(events.stream),
      );

      // 센서 기준점을 먼저 잡아 둔다.
      await controller.startStepTracking();
      events.add(1000);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final callsAfterBaseline = backend.calls;

      controller.state = controller.state.copyWith(deviceStepsWaiting: 900);
      await controller.flushDeviceSteps();

      expect(controller.state.deviceStepsWaiting, 0);
      // 상한에 걸린 뒤에는 같은 동기화를 반복하지 않는다.
      expect(backend.calls, callsAfterBaseline + 1);
      expect(
        controller.state.statusMessage,
        contains('오늘 반영할 수 있는 걸음 수를 모두 썼어요'),
      );

      await events.close();
      controller.dispose();
    });
  });
}
