import 'package:flutter_test/flutter_test.dart';
import 'package:masilpet/src/data/masilpet_backend.dart';
import 'package:masilpet/src/models.dart';

void main() {
  test('remote POI parser skips incomplete payloads safely', () {
    expect(RemotePoi.tryFromMap(const {'id': 'missing-location'}), isNull);

    final poi = RemotePoi.tryFromMap(const {
      'id': 'tourapi-1',
      'title': '테스트 장소',
      'category': 42,
      'lat': 35.17,
      'lng': 129.12,
    });

    expect(poi, isNotNull);
    expect(poi!.regionId, 'korea');
    expect(poi.tourApiContentId, '1');
    expect(poi.category, PoiCategory.other);
    expect(poi.distanceMeters, 0);
  });

  test('remote check-in parser tolerates missing optional progress fields', () {
    final result = RemoteCheckInResult.fromMap(const {
      'success': true,
      'updatedPet': {
        'stats': {'exp': 42},
      },
    });

    expect(result.success, isTrue);
    expect(result.distanceMeters, 0);
    expect(result.reward.exp, 0);
    expect(result.eggProgress, isNull);
    expect(result.updatedPet?.stats.exp, 42);
    expect(result.updatedPet?.stats.mood, 0);
    expect(result.updatedPet?.level, 1);
    expect(result.updatedPet?.stage, PetStage.baby);
  });

  test('remote interaction parser falls back to zero reward', () {
    final result = RemotePetInteractionResult.fromMap(const {
      'updatedPet': {
        'id': 42,
        'level': 3,
        'stage': 99,
      },
    });

    expect(result.reward.exp, 0);
    expect(result.reward.mood, 0);
    expect(result.updatedPet?.id, isNull);
    expect(result.updatedPet?.stats.affinity, 0);
    expect(result.updatedPet?.level, 3);
    expect(result.updatedPet?.stage, PetStage.baby);
  });

  test('remote step parser treats absent counters as zero', () {
    final result = RemoteStepProgressResult.fromMap(const {});

    expect(result.hatchableCount, 0);
    expect(result.appliedStepDelta, 0);
  });
}
