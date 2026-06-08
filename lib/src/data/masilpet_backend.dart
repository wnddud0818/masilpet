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

    final pois = data['pois'];
    if (pois is! List) {
      return const [];
    }

    return pois
        .whereType<Map>()
        .map((item) => RemotePoi.tryFromMap(_mapFromValue(item)))
        .whereType<RemotePoi>()
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
    required this.tourApiContentId,
    required this.title,
    required this.regionId,
    required this.category,
    required this.coordinates,
    required this.distanceMeters,
  });

  factory RemotePoi.fromMap(Map<String, dynamic> map) {
    final poi = tryFromMap(map);
    if (poi == null) {
      throw const FormatException('Remote POI response is incomplete.');
    }
    return poi;
  }

  static RemotePoi? tryFromMap(Map<String, dynamic> map) {
    final id = _stringFromValue(map['id']);
    final title = _stringFromValue(map['title']);
    final latitude = _doubleFromValue(map['lat']);
    final longitude = _doubleFromValue(map['lng']);
    if (id.isEmpty || title.isEmpty || latitude == null || longitude == null) {
      return null;
    }

    return RemotePoi(
      id: id,
      tourApiContentId: _tourApiContentIdFromMap(map, id),
      title: title,
      regionId: _stringFromValue(map['regionId'], fallback: 'korea'),
      category: _categoryFromName(_stringFromValue(map['category'])),
      coordinates: Coordinates(
        latitude: latitude,
        longitude: longitude,
      ),
      distanceMeters: _doubleFromValue(map['distanceMeters']) ?? 0,
    );
  }

  final String id;
  final String tourApiContentId;
  final String title;
  final String regionId;
  final PoiCategory category;
  final Coordinates coordinates;
  final double distanceMeters;
}

String _tourApiContentIdFromMap(Map<String, dynamic> map, String id) {
  final contentId = _stringFromValue(map['tourApiContentId']);
  if (contentId.isNotEmpty) {
    return contentId;
  }
  const prefix = 'tourapi-';
  return id.startsWith(prefix) ? id.substring(prefix.length) : id;
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
      distanceMeters: _doubleFromValue(map['distanceMeters']) ?? 0,
      reward: _statsFromMap(_mapFromValue(map['reward'])),
      eggProgress: _intFromValue(map['eggProgress']),
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
      hatchableCount: _intFromValue(map['hatchableCount']) ?? 0,
      appliedStepDelta: _intFromValue(map['appliedStepDelta']) ?? 0,
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
      reward: _statsFromMap(_mapFromValue(map['reward'])),
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
    final id = _stringFromValue(map['id']);

    return RemotePetUpdate(
      id: id.isEmpty ? null : id,
      stats: _statsFromMap(_mapFromValue(map['stats'])),
      level: _intFromValue(map['level']) ?? 1,
      stage: _petStageFromName(_stringFromValue(map['stage'])),
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
    exp: _intFromValue(map['exp']) ?? 0,
    mood: _intFromValue(map['mood']) ?? 0,
    knowledge: _intFromValue(map['knowledge']) ?? 0,
    affinity: _intFromValue(map['affinity']) ?? 0,
  );
}

Map<String, dynamic> _mapFromValue(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }
  return const {};
}

String _stringFromValue(Object? value, {String fallback = ''}) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return fallback;
}

int? _intFromValue(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return null;
}

double? _doubleFromValue(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}
