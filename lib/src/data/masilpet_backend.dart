import 'package:cloud_functions/cloud_functions.dart';

import '../models.dart';

abstract class MasilPetBackend {
  Future<void> seedStarterRegionData();

  Future<void> ensureUserBootstrap();

  Future<List<RemotePoi>> getNearbyPois(Coordinates location);

  Future<RemoteCheckInResult> attemptCheckIn({
    required String poiId,
    required Coordinates location,
  });

  Future<int> applyStepProgress(int stepDelta);

  Future<String> hatchEgg(String eggId);

  Future<GrowthStats> interactWithPet({
    required String petId,
    required String actionType,
  });
}

class FirebaseMasilPetBackend implements MasilPetBackend {
  FirebaseMasilPetBackend({
    FirebaseFunctions? functions,
  }) : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;

  @override
  Future<void> seedStarterRegionData() async {
    await _functions.httpsCallable('seedStarterRegionData').call();
  }

  @override
  Future<void> ensureUserBootstrap() async {
    await _functions.httpsCallable('ensureUserBootstrap').call();
  }

  @override
  Future<List<RemotePoi>> getNearbyPois(Coordinates location) async {
    final callable = _functions.httpsCallable('getNearbyPois');
    final response = await callable.call<Map<String, dynamic>>({
      'lat': location.latitude,
      'lng': location.longitude,
    });

    final pois = (response.data['pois'] as List<dynamic>? ?? const []);
    return pois.map((item) => RemotePoi.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }

  @override
  Future<RemoteCheckInResult> attemptCheckIn({
    required String poiId,
    required Coordinates location,
  }) async {
    final callable = _functions.httpsCallable('attemptCheckIn');
    final response = await callable.call<Map<String, dynamic>>({
      'poiId': poiId,
      'lat': location.latitude,
      'lng': location.longitude,
    });
    return RemoteCheckInResult.fromMap(response.data);
  }

  @override
  Future<int> applyStepProgress(int stepDelta) async {
    final callable = _functions.httpsCallable('applyStepProgress');
    final response = await callable.call<Map<String, dynamic>>({
      'stepDelta': stepDelta,
    });
    return (response.data['hatchableCount'] as num? ?? 0).toInt();
  }

  @override
  Future<String> hatchEgg(String eggId) async {
    final response = await _functions.httpsCallable('hatchEgg').call<Map<String, dynamic>>({
      'eggId': eggId,
    });
    return response.data['petId'] as String;
  }

  @override
  Future<GrowthStats> interactWithPet({
    required String petId,
    required String actionType,
  }) async {
    final callable = _functions.httpsCallable('interactWithPet');
    final response = await callable.call<Map<String, dynamic>>({
      'petId': petId,
      'actionType': actionType,
    });
    return _statsFromMap(Map<String, dynamic>.from(response.data['reward'] as Map));
  }
}

class RemotePoi {
  const RemotePoi({
    required this.id,
    required this.title,
    required this.regionId,
    required this.category,
    required this.coordinates,
    required this.distanceMeters,
  });

  factory RemotePoi.fromMap(Map<String, dynamic> map) {
    return RemotePoi(
      id: map['id'] as String,
      title: map['title'] as String,
      regionId: map['regionId'] as String,
      category: _categoryFromName(map['category'] as String?),
      coordinates: Coordinates(
        latitude: (map['lat'] as num).toDouble(),
        longitude: (map['lng'] as num).toDouble(),
      ),
      distanceMeters: (map['distanceMeters'] as num).toDouble(),
    );
  }

  final String id;
  final String title;
  final String regionId;
  final PoiCategory category;
  final Coordinates coordinates;
  final double distanceMeters;
}

class RemoteCheckInResult {
  const RemoteCheckInResult({
    required this.success,
    required this.distanceMeters,
    required this.reward,
  });

  factory RemoteCheckInResult.fromMap(Map<String, dynamic> map) {
    return RemoteCheckInResult(
      success: map['success'] == true,
      distanceMeters: (map['distanceMeters'] as num? ?? 0).toDouble(),
      reward: _statsFromMap(Map<String, dynamic>.from(map['reward'] as Map)),
    );
  }

  final bool success;
  final double distanceMeters;
  final GrowthStats reward;
}

PoiCategory _categoryFromName(String? name) {
  return PoiCategory.values.firstWhere(
    (category) => category.name == name,
    orElse: () => PoiCategory.other,
  );
}

GrowthStats _statsFromMap(Map<String, dynamic> map) {
  return GrowthStats(
    exp: (map['exp'] as num? ?? 0).toInt(),
    mood: (map['mood'] as num? ?? 0).toInt(),
    knowledge: (map['knowledge'] as num? ?? 0).toInt(),
    affinity: (map['affinity'] as num? ?? 0).toInt(),
  );
}
