import 'package:cloud_functions/cloud_functions.dart';

import '../models.dart';

abstract class MasilPetBackend {
  Future<void> ensureUserBootstrap();

  Future<void> deleteUserProgress();

  Future<List<RemotePoi>> getNearbyPois(Coordinates location);

  Future<RemoteCheckInResult> attemptCheckIn({
    required String poiId,
    required Coordinates location,
  });

  Future<RemoteStepProgressResult> applyStepProgress(int stepDelta);

  Future<String> hatchEgg(String eggId);

  Future<RemotePetInteractionResult> interactWithPet({
    required String petId,
    required String actionType,
  });
}

class FirebaseMasilPetBackend implements MasilPetBackend {
  FirebaseMasilPetBackend({
    FirebaseFunctions? functions,
  }) : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;

  @override
  Future<void> ensureUserBootstrap() async {
    await _call('ensureUserBootstrap');
  }

  @override
  Future<void> deleteUserProgress() async {
    await _call('deleteUserProgress');
  }

  @override
  Future<List<RemotePoi>> getNearbyPois(Coordinates location) async {
    final data = await _call('getNearbyPois', {
      'lat': location.latitude,
      'lng': location.longitude,
    });

    final pois = (data['pois'] as List<dynamic>? ?? const []);
    return pois
        .map(
            (item) => RemotePoi.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<RemoteCheckInResult> attemptCheckIn({
    required String poiId,
    required Coordinates location,
  }) async {
    final data = await _call('attemptCheckIn', {
      'poiId': poiId,
      'lat': location.latitude,
      'lng': location.longitude,
    });
    return RemoteCheckInResult.fromMap(data);
  }

  @override
  Future<RemoteStepProgressResult> applyStepProgress(int stepDelta) async {
    final data = await _call('applyStepProgress', {
      'stepDelta': stepDelta,
    });
    return RemoteStepProgressResult.fromMap(data);
  }

  @override
  Future<String> hatchEgg(String eggId) async {
    final data = await _call('hatchEgg', {
      'eggId': eggId,
    });
    return data['petId'] as String;
  }

  @override
  Future<RemotePetInteractionResult> interactWithPet({
    required String petId,
    required String actionType,
  }) async {
    final data = await _call('interactWithPet', {
      'petId': petId,
      'actionType': actionType,
    });
    return RemotePetInteractionResult.fromMap(data);
  }

  Future<Map<String, dynamic>> _call(String functionName,
      [Map<String, dynamic> payload = const {}]) async {
    try {
      final callable = _functions.httpsCallable(functionName);
      final response = await callable.call<Map<String, dynamic>>(payload);
      return response.data;
    } on FirebaseFunctionsException catch (error) {
      throw MasilPetBackendException(
        code: error.code,
        message: error.message,
        details: error.details,
      );
    }
  }
}

class MasilPetBackendException implements Exception {
  const MasilPetBackendException({
    required this.code,
    this.message,
    this.details,
  });

  final String code;
  final String? message;
  final Object? details;

  @override
  String toString() {
    final label = message == null ? code : '$code: $message';
    return 'MasilPetBackendException($label)';
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
    required this.eggProgress,
    required this.updatedPet,
  });

  factory RemoteCheckInResult.fromMap(Map<String, dynamic> map) {
    final updatedPet = map['updatedPet'] is Map
        ? RemotePetUpdate.fromMap(
            Map<String, dynamic>.from(map['updatedPet'] as Map),
          )
        : null;

    return RemoteCheckInResult(
      success: map['success'] == true,
      distanceMeters: (map['distanceMeters'] as num? ?? 0).toDouble(),
      reward: _statsFromMap(Map<String, dynamic>.from(map['reward'] as Map)),
      eggProgress: (map['eggProgress'] as num?)?.toInt(),
      updatedPet: updatedPet,
    );
  }

  final bool success;
  final double distanceMeters;
  final GrowthStats reward;
  final int? eggProgress;
  final RemotePetUpdate? updatedPet;
}

class RemoteStepProgressResult {
  const RemoteStepProgressResult({
    required this.hatchableCount,
    required this.appliedStepDelta,
  });

  factory RemoteStepProgressResult.fromMap(Map<String, dynamic> map) {
    return RemoteStepProgressResult(
      hatchableCount: (map['hatchableCount'] as num? ?? 0).toInt(),
      appliedStepDelta: (map['appliedStepDelta'] as num? ?? 0).toInt(),
    );
  }

  final int hatchableCount;
  final int appliedStepDelta;
}

class RemotePetInteractionResult {
  const RemotePetInteractionResult({
    required this.reward,
    required this.updatedPet,
  });

  factory RemotePetInteractionResult.fromMap(Map<String, dynamic> map) {
    final updatedPet = map['updatedPet'] is Map
        ? RemotePetUpdate.fromMap(
            Map<String, dynamic>.from(map['updatedPet'] as Map),
          )
        : null;

    return RemotePetInteractionResult(
      reward: _statsFromMap(Map<String, dynamic>.from(map['reward'] as Map)),
      updatedPet: updatedPet,
    );
  }

  final GrowthStats reward;
  final RemotePetUpdate? updatedPet;
}

class RemotePetUpdate {
  const RemotePetUpdate({
    this.id,
    required this.stats,
    required this.level,
    required this.stage,
  });

  factory RemotePetUpdate.fromMap(Map<String, dynamic> map) {
    return RemotePetUpdate(
      id: map['id'] as String?,
      stats: _statsFromMap(Map<String, dynamic>.from(map['stats'] as Map)),
      level: (map['level'] as num? ?? 1).toInt(),
      stage: _petStageFromName(map['stage'] as String?),
    );
  }

  final String? id;
  final GrowthStats stats;
  final int level;
  final PetStage stage;
}

PoiCategory _categoryFromName(String? name) {
  return PoiCategory.values.firstWhere(
    (category) => category.name == name,
    orElse: () => PoiCategory.other,
  );
}

PetStage _petStageFromName(String? name) {
  return PetStage.values.firstWhere(
    (stage) => stage.name == name,
    orElse: () => PetStage.baby,
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
