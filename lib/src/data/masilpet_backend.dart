import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models.dart';

const masilPetApiBaseUrl = String.fromEnvironment(
  'MASILPET_API_BASE_URL',
  defaultValue: 'https://masilpet-api.firstghrn818.workers.dev',
);

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

  /// Records which pet walks with the user, so server-side rewards land on the
  /// same companion the app is showing.
  Future<void> setActivePet(String petId);

  /// Records which egg receives walking and check-in incubation credit.
  Future<void> setActiveEgg(String eggId);
}

abstract interface class DetailedHatchBackend {
  Future<RemoteHatchResult> hatchEggWithOutcome(String eggId);
}

abstract interface class CumulativeStepSyncBackend {
  Future<RemoteStepProgressResult> syncStepsV2({
    required String operationId,
    required String deviceId,
    required String dayKey,
    required int observedCumulativeSteps,
    required DateTime observedAt,
  });
}

MasilPetBackend createMasilPetBackend() {
  final workerUrl = masilPetApiBaseUrl.trim();
  if (workerUrl.isNotEmpty) {
    return CloudflareMasilPetBackend(baseUrl: workerUrl);
  }
  return FirebaseMasilPetBackend();
}

class CloudflareMasilPetBackend
    implements
        MasilPetBackend,
        DetailedHatchBackend,
        CumulativeStepSyncBackend {
  CloudflareMasilPetBackend({
    required String baseUrl,
    FirebaseAuth? auth,
    http.Client? client,
    Future<String?> Function()? tokenProvider,
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _tokenProvider = tokenProvider ??
            (() async =>
                (auth ?? FirebaseAuth.instance).currentUser?.getIdToken()),
        _client = client ?? http.Client();

  final String _baseUrl;
  final Future<String?> Function() _tokenProvider;
  final http.Client _client;

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
    return (await hatchEggWithOutcome(eggId)).petId;
  }

  @override
  Future<RemoteStepProgressResult> syncStepsV2({
    required String operationId,
    required String deviceId,
    required String dayKey,
    required int observedCumulativeSteps,
    required DateTime observedAt,
  }) async {
    final data = await _call('syncStepsV2', {
      'operationId': operationId,
      'deviceId': deviceId,
      'dayKey': dayKey,
      'observedCumulativeSteps': observedCumulativeSteps,
      'observedAt': observedAt.toUtc().toIso8601String(),
    });
    return RemoteStepProgressResult.fromMap(data);
  }

  @override
  Future<RemoteHatchResult> hatchEggWithOutcome(String eggId) async {
    final data = await _call('hatchEgg', {'eggId': eggId});
    return RemoteHatchResult.fromMap(data);
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

  @override
  Future<void> setActivePet(String petId) async {
    await _call('setActivePet', {'petId': petId});
  }

  @override
  Future<void> setActiveEgg(String eggId) async {
    await _call('setActiveEgg', {'eggId': eggId});
  }

  Future<Map<String, dynamic>> _call(
    String functionName, [
    Map<String, dynamic> payload = const {},
  ]) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const MasilPetBackendException(
        code: 'unauthenticated',
        message: 'Firebase authentication is required.',
      );
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/v1/$functionName'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'data': payload}),
          )
          .timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(response.body);
      final body = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : const <String, dynamic>{};
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _mapFromValue(body['data']);
      }

      final error = _mapFromValue(body['error']);
      throw MasilPetBackendException(
        code: _stringFromValue(error['code'], fallback: 'internal'),
        message: _stringFromValue(error['message']).isEmpty
            ? null
            : _stringFromValue(error['message']),
        details: error['details'],
      );
    } on MasilPetBackendException {
      rethrow;
    } on Object catch (error) {
      throw MasilPetBackendException(
        code: 'unavailable',
        message: 'MasilPet API request failed.',
        details: error.toString(),
      );
    }
  }
}

class FirebaseMasilPetBackend
    implements
        MasilPetBackend,
        DetailedHatchBackend,
        CumulativeStepSyncBackend {
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
    return (await hatchEggWithOutcome(eggId)).petId;
  }

  @override
  Future<RemoteStepProgressResult> syncStepsV2({
    required String operationId,
    required String deviceId,
    required String dayKey,
    required int observedCumulativeSteps,
    required DateTime observedAt,
  }) async {
    final data = await _call('syncStepsV2', {
      'operationId': operationId,
      'deviceId': deviceId,
      'dayKey': dayKey,
      'observedCumulativeSteps': observedCumulativeSteps,
      'observedAt': observedAt.toUtc().toIso8601String(),
    });
    return RemoteStepProgressResult.fromMap(data);
  }

  @override
  Future<RemoteHatchResult> hatchEggWithOutcome(String eggId) async {
    final data = await _call('hatchEgg', {
      'eggId': eggId,
    });
    return RemoteHatchResult.fromMap(data);
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

  @override
  Future<void> setActivePet(String petId) async {
    await _call('setActivePet', {'petId': petId});
  }

  @override
  Future<void> setActiveEgg(String eggId) async {
    await _call('setActiveEgg', {'eggId': eggId});
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
    this.tendency = PoiTendency.balanced,
    this.address,
    this.imageUrl,
    this.tel,
    this.openTime,
    this.restDate,
    this.signatureMenu,
    this.petFriendlyGuide,
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
      tendency: _tendencyFromName(_stringFromValue(map['tendency'])),
      address: _optionalStringFromValue(map['address']),
      imageUrl: _optionalStringFromValue(map['imageUrl']),
      tel: _optionalStringFromValue(map['tel']),
      openTime: _optionalStringFromValue(map['openTime']),
      restDate: _optionalStringFromValue(map['restDate']),
      signatureMenu: _optionalStringFromValue(map['signatureMenu']),
      petFriendlyGuide: _petFriendlyGuideFromValue(map['petFriendly']),
    );
  }

  final String id;
  final String tourApiContentId;
  final String title;
  final String regionId;
  final PoiCategory category;
  final Coordinates coordinates;
  final double distanceMeters;
  final PoiTendency tendency;
  final String? address;
  final String? imageUrl;
  final String? tel;
  final String? openTime;
  final String? restDate;
  final String? signatureMenu;
  final String? petFriendlyGuide;
}

PoiTendency _tendencyFromName(String name) {
  for (final tendency in PoiTendency.values) {
    if (tendency.name == name) {
      return tendency;
    }
  }
  return PoiTendency.balanced;
}

String? _optionalStringFromValue(Object? value) {
  final text = _stringFromValue(value).trim();
  return text.isEmpty ? null : text;
}

/// detailPetTour2 승인 전에는 이 값이 비어 있어 안내 문구가 표시되지 않는다.
String? _petFriendlyGuideFromValue(Object? value) {
  if (value is! Map) {
    return null;
  }
  final petInfo = _mapFromValue(value);
  for (final key in const ['guide', 'accompanyType', 'availableFacility']) {
    final text = _optionalStringFromValue(petInfo[key]);
    if (text != null) {
      return text;
    }
  }
  return null;
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
    this.companionPetId,
    this.creditedEggId,
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
      companionPetId: _nullableStringFromValue(map['companionPetId']),
      creditedEggId: _nullableStringFromValue(map['creditedEggId']),
    );
  }

  final bool success;
  final double distanceMeters;
  final GrowthStats reward;
  final int? eggProgress;
  final RemotePetUpdate? updatedPet;
  final String? companionPetId;
  final String? creditedEggId;
}

class RemoteHatchResult {
  const RemoteHatchResult({
    required this.petId,
    required this.reunion,
    required this.updatedPet,
    this.reunionCount,
  });

  factory RemoteHatchResult.fromMap(Map<String, dynamic> map) {
    final petId = _stringFromValue(map['petId']);
    if (petId.isEmpty) {
      throw const MasilPetBackendException(
        code: 'invalid-response',
        message: 'Hatch response did not include a petId.',
      );
    }
    return RemoteHatchResult(
      petId: petId,
      reunion: map['reunion'] == true,
      updatedPet: map['updatedPet'] is Map
          ? RemotePetUpdate.fromMap(
              Map<String, dynamic>.from(map['updatedPet'] as Map),
            )
          : null,
      reunionCount: _intFromValue(
        _mapFromValue(map['updatedPet'])['reunionCount'],
      ),
    );
  }

  final String petId;
  final bool reunion;
  final RemotePetUpdate? updatedPet;
  final int? reunionCount;
}

class RemoteStepProgressResult {
  const RemoteStepProgressResult({
    required this.hatchableCount,
    required this.appliedStepDelta,
    this.creditedEggId,
    this.companionPetId,
    this.updatedPet,
    this.baselineInitialized = false,
    this.counterReset = false,
  });

  factory RemoteStepProgressResult.fromMap(Map<String, dynamic> map) {
    return RemoteStepProgressResult(
      hatchableCount: _intFromValue(map['hatchableCount']) ?? 0,
      appliedStepDelta: _intFromValue(map['appliedStepDelta']) ?? 0,
      creditedEggId: _nullableStringFromValue(map['creditedEggId']),
      companionPetId: _nullableStringFromValue(map['companionPetId']),
      updatedPet: map['updatedPet'] is Map
          ? RemotePetUpdate.fromMap(
              Map<String, dynamic>.from(map['updatedPet'] as Map),
            )
          : null,
      baselineInitialized: map['baselineInitialized'] == true,
      counterReset: map['counterReset'] == true,
    );
  }

  final int hatchableCount;
  final int appliedStepDelta;
  final String? creditedEggId;
  final String? companionPetId;
  final RemotePetUpdate? updatedPet;
  final bool baselineInitialized;
  final bool counterReset;
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

String? _nullableStringFromValue(Object? value) {
  final resolved = _stringFromValue(value);
  return resolved.isEmpty ? null : resolved;
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
