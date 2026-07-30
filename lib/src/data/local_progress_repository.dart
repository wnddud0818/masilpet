import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'local_progress_storage.dart' as fallback_storage;

abstract class LocalProgressRepository {
  Future<LocalProgressSnapshot?> loadProgress();

  Future<void> saveProgress(LocalProgressSnapshot snapshot);

  Future<void> clearProgress();
}

class SharedPreferencesLocalProgressRepository
    implements LocalProgressRepository {
  const SharedPreferencesLocalProgressRepository();

  static const _storageKey = 'masilpet.local_progress.v1';

  @override
  Future<LocalProgressSnapshot?> loadProgress() async {
    String? raw;
    try {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_storageKey);
    } on Object {
      raw = _fallbackRawProgress();
      if (raw == null || raw.isEmpty) {
        rethrow;
      }
    }

    if (raw == null || raw.isEmpty) {
      raw = _fallbackRawProgress();
    }

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return LocalProgressSnapshot.fromMap(decoded);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveProgress(LocalProgressSnapshot snapshot) async {
    final raw = jsonEncode(snapshot.toMap());

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, raw);
      _saveFallbackRawProgress(raw);
    } on Object {
      if (_saveFallbackRawProgress(raw)) {
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> clearProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      _clearFallbackRawProgress();
    } on Object {
      if (_clearFallbackRawProgress()) {
        return;
      }
      rethrow;
    }
  }

  static const _legacyWebStorageKey = 'flutter.$_storageKey';

  static String? _fallbackRawProgress() {
    if (!fallback_storage.isAvailable) {
      return null;
    }

    try {
      return fallback_storage.getString(_legacyWebStorageKey) ??
          fallback_storage.getString(_storageKey);
    } on Object {
      return null;
    }
  }

  static bool _saveFallbackRawProgress(String raw) {
    if (!fallback_storage.isAvailable) {
      return false;
    }

    try {
      fallback_storage.setString(_legacyWebStorageKey, raw);
      fallback_storage.setString(_storageKey, raw);
      return true;
    } on Object {
      return false;
    }
  }

  static bool _clearFallbackRawProgress() {
    if (!fallback_storage.isAvailable) {
      return false;
    }

    try {
      fallback_storage.remove(_legacyWebStorageKey);
      fallback_storage.remove(_storageKey);
      return true;
    } on Object {
      return false;
    }
  }
}

class LocalProgressSnapshot {
  const LocalProgressSnapshot({
    required this.onboardingComplete,
    required this.pois,
    required this.pets,
    required this.eggs,
    required this.checkIns,
    required this.currentLocation,
    required this.locationVerified,
    required this.locationVerifiedAt,
    required this.activePetId,
    this.activeEggId = '',
    required this.lastVisitedCategory,
    required this.dialogueCountToday,
    required this.dialogueDay,
    this.careByPetId = const {},
    this.carePoints = 0,
    this.dailyCareRewardClaimKey,
    this.stepSyncDeviceId = '',
  });

  factory LocalProgressSnapshot.fromMap(Map<String, dynamic> map) {
    final dailyCareRewardClaimKey =
        _stringFromValue(map['dailyCareRewardClaimKey']);
    return LocalProgressSnapshot(
      onboardingComplete: map['onboardingComplete'] == true,
      pois: _listOfMaps(map['pois']).map(_poiFromMap).toList(),
      pets: _listOfMaps(map['pets']).map(_petFromMap).toList(),
      eggs: _listOfMaps(map['eggs']).map(_eggFromMap).toList(),
      checkIns: _listOfMaps(map['checkIns']).map(_checkInFromMap).toList(),
      currentLocation: _coordinatesFromMap(
        _mapOrEmpty(map['currentLocation']),
        fallback: const Coordinates(latitude: 35.1587, longitude: 129.1604),
      ),
      locationVerified: map['locationVerified'] == true,
      locationVerifiedAt: _nullableDateFromValue(map['locationVerifiedAt']),
      activePetId: _stringFromValue(map['activePetId']),
      activeEggId: _stringFromValue(map['activeEggId']),
      lastVisitedCategory: _nullableCategoryFromName(
        _stringFromValue(map['lastVisitedCategory']),
      ),
      dialogueCountToday: _intFromValue(map['dialogueCountToday']) ?? 0,
      dialogueDay: _dateFromValue(map['dialogueDay']),
      careByPetId: _careByPetIdFromMap(map['careByPetId']),
      carePoints: _intFromValue(map['carePoints']) ?? 0,
      dailyCareRewardClaimKey:
          dailyCareRewardClaimKey.isEmpty ? null : dailyCareRewardClaimKey,
      stepSyncDeviceId: _stringFromValue(map['stepSyncDeviceId']),
    );
  }

  final bool onboardingComplete;
  final List<Poi> pois;
  final List<Pet> pets;
  final List<Egg> eggs;
  final List<CheckIn> checkIns;
  final Coordinates currentLocation;
  final bool locationVerified;
  final DateTime? locationVerifiedAt;
  final String activePetId;
  final String activeEggId;
  final PoiCategory? lastVisitedCategory;
  final int dialogueCountToday;
  final DateTime dialogueDay;
  final Map<String, PetCareState> careByPetId;
  final int carePoints;
  final String? dailyCareRewardClaimKey;
  final String stepSyncDeviceId;

  Map<String, dynamic> toMap() {
    return {
      'version': 4,
      'onboardingComplete': onboardingComplete,
      'pois': pois.map(_poiToMap).toList(),
      'pets': pets.map(_petToMap).toList(),
      'eggs': eggs.map(_eggToMap).toList(),
      'checkIns': checkIns.map(_checkInToMap).toList(),
      'currentLocation': _coordinatesToMap(currentLocation),
      'locationVerified': locationVerified,
      'locationVerifiedAt': locationVerifiedAt?.toIso8601String(),
      'activePetId': activePetId,
      'activeEggId': activeEggId,
      'lastVisitedCategory': lastVisitedCategory?.name,
      'dialogueCountToday': dialogueCountToday,
      'dialogueDay': dialogueDay.toIso8601String(),
      'careByPetId': {
        for (final entry in careByPetId.entries)
          entry.key: _careToMap(entry.value),
      },
      'carePoints': carePoints,
      'dailyCareRewardClaimKey': dailyCareRewardClaimKey,
      'stepSyncDeviceId': stepSyncDeviceId,
    };
  }
}

Map<String, dynamic> _careToMap(PetCareState care) {
  return {
    'satiety': care.satiety,
    'cleanliness': care.cleanliness,
    'vitality': care.vitality,
    'happiness': care.happiness,
    'updatedAt': care.updatedAt.toIso8601String(),
    'dailyCountDay': care.dailyCountDay.toIso8601String(),
    'feedCountToday': care.feedCountToday,
    'playCountToday': care.playCountToday,
    'cleanCountToday': care.cleanCountToday,
    'talkCountToday': care.talkCountToday,
    'petCountToday': care.petCountToday,
    'bondedDays': care.bondedDays,
    'lastBondedDay': care.lastBondedDay?.toIso8601String(),
    'wasteCount': care.wasteCount,
    'lastWasteAt': care.lastWasteAt.toIso8601String(),
    'isSleeping': care.isSleeping,
    'sleepStartedAt': care.sleepStartedAt?.toIso8601String(),
    'ailment': care.ailment.name,
    'ailmentUntil': care.ailmentUntil?.toIso8601String(),
    'lastFood': care.lastFood?.name,
    'sameFoodStreak': care.sameFoodStreak,
    'walkStepsToday': care.walkStepsToday,
    'walkDay': care.walkDay.toIso8601String(),
    'adventureScore': care.adventureScore,
    'gourmetScore': care.gourmetScore,
    'knowledgeScore': care.knowledgeScore,
    'affectionScore': care.affectionScore,
    'eleganceScore': care.eleganceScore,
    'memories': care.memories.map(_memoryToMap).toList(),
  };
}

Map<String, dynamic> _memoryToMap(PetMemory memory) {
  return {
    'id': memory.id,
    'title': memory.title,
    'detail': memory.detail,
    'createdAt': memory.createdAt.toIso8601String(),
    'category': memory.category?.name,
  };
}

Map<String, PetCareState> _careByPetIdFromMap(Object? value) {
  final map = _mapFromValue(value);
  final result = <String, PetCareState>{};
  for (final entry in map.entries) {
    final careMap = _mapFromValue(entry.value);
    if (careMap.isEmpty) {
      continue;
    }
    final updatedAt = _dateFromValue(careMap['updatedAt']);
    result[entry.key] = PetCareState(
      satiety: _intFromValue(careMap['satiety']) ?? 72,
      cleanliness: _intFromValue(careMap['cleanliness']) ?? 76,
      vitality: _intFromValue(careMap['vitality']) ?? 74,
      happiness: _intFromValue(careMap['happiness']) ?? 72,
      updatedAt: updatedAt,
      dailyCountDay:
          _nullableDateFromValue(careMap['dailyCountDay']) ?? updatedAt,
      feedCountToday: _intFromValue(careMap['feedCountToday']) ?? 0,
      playCountToday: _intFromValue(careMap['playCountToday']) ?? 0,
      cleanCountToday: _intFromValue(careMap['cleanCountToday']) ?? 0,
      talkCountToday: _intFromValue(careMap['talkCountToday']) ?? 0,
      petCountToday: _intFromValue(careMap['petCountToday']) ?? 0,
      bondedDays: _intFromValue(careMap['bondedDays']) ?? 0,
      lastBondedDay: _nullableDateFromValue(careMap['lastBondedDay']),
      wasteCount: _intFromValue(careMap['wasteCount']) ?? 0,
      lastWasteAt: _nullableDateFromValue(careMap['lastWasteAt']) ?? updatedAt,
      isSleeping: careMap['isSleeping'] == true,
      sleepStartedAt: _nullableDateFromValue(careMap['sleepStartedAt']),
      ailment: _petAilmentFromName(_stringFromValue(careMap['ailment'])),
      ailmentUntil: _nullableDateFromValue(careMap['ailmentUntil']),
      lastFood: _nullablePetFoodFromName(
        _stringFromValue(careMap['lastFood']),
      ),
      sameFoodStreak: _intFromValue(careMap['sameFoodStreak']) ?? 0,
      walkStepsToday: _intFromValue(careMap['walkStepsToday']) ?? 0,
      walkDay: _nullableDateFromValue(careMap['walkDay']) ?? updatedAt,
      adventureScore: _intFromValue(careMap['adventureScore']) ?? 0,
      gourmetScore: _intFromValue(careMap['gourmetScore']) ?? 0,
      knowledgeScore: _intFromValue(careMap['knowledgeScore']) ?? 0,
      affectionScore: _intFromValue(careMap['affectionScore']) ?? 0,
      eleganceScore: _intFromValue(careMap['eleganceScore']) ?? 0,
      memories: _listOfMaps(careMap['memories']).map(_memoryFromMap).toList(),
    );
  }
  return result;
}

PetMemory _memoryFromMap(Map<String, dynamic> map) {
  return PetMemory(
    id: _stringFromValue(map['id']),
    title: _stringFromValue(map['title'], fallback: '함께한 기억'),
    detail: _stringFromValue(map['detail']),
    createdAt: _dateFromValue(map['createdAt']),
    category: _nullableCategoryFromName(_stringFromValue(map['category'])),
  );
}

Map<String, dynamic> _poiToMap(Poi poi) {
  return {
    'id': poi.id,
    'tourApiContentId': poi.tourApiContentId,
    'title': poi.title,
    'regionId': poi.regionId,
    'category': poi.category.name,
    'coordinates': _coordinatesToMap(poi.coordinates),
    'shortDescription': poi.shortDescription,
  };
}

Poi _poiFromMap(Map<String, dynamic> map) {
  return Poi(
    id: _stringFromValue(map['id']),
    tourApiContentId: _stringFromValue(map['tourApiContentId']),
    title: _stringFromValue(map['title'], fallback: '장소'),
    regionId: _stringFromValue(map['regionId'], fallback: 'korea'),
    category: _categoryFromName(_stringFromValue(map['category'])),
    coordinates: _coordinatesFromMap(_mapOrEmpty(map['coordinates'])),
    shortDescription: _stringFromValue(map['shortDescription']),
  );
}

Map<String, dynamic> _petToMap(Pet pet) {
  return {
    'id': pet.id,
    'templateId': pet.templateId,
    'name': pet.name,
    'stage': pet.stage.name,
    'level': pet.level,
    'stats': _statsToMap(pet.stats),
    'originRegionId': pet.originRegionId,
    'hatchedAt': pet.hatchedAt.toIso8601String(),
    'lastInteractedAt': pet.lastInteractedAt?.toIso8601String(),
    'originEggId': pet.originEggId,
    'reunionCount': pet.reunionCount,
  };
}

Pet _petFromMap(Map<String, dynamic> map) {
  return Pet(
    id: _stringFromValue(map['id']),
    templateId: _stringFromValue(map['templateId'], fallback: 'wave-naru'),
    name: _stringFromValue(map['name'], fallback: '마실펫'),
    stage: _petStageFromName(_stringFromValue(map['stage'])),
    level: _intFromValue(map['level']) ?? 1,
    stats: _statsFromMap(_mapOrEmpty(map['stats'])),
    originRegionId: _stringFromValue(map['originRegionId'], fallback: 'korea'),
    hatchedAt: _dateFromValue(map['hatchedAt']),
    lastInteractedAt: _nullableDateFromValue(map['lastInteractedAt']),
    originEggId: _nullableStringFromValue(map['originEggId']),
    reunionCount: _intFromValue(map['reunionCount']) ?? 0,
  );
}

Map<String, dynamic> _eggToMap(Egg egg) {
  return {
    'id': egg.id,
    'templateId': egg.templateId,
    'originRegionId': egg.originRegionId,
    'progress': egg.progress,
    'requiredSteps': egg.requiredSteps,
    'status': egg.status.name,
    'createdAt': egg.createdAt.toIso8601String(),
    'originPoiId': egg.originPoiId,
    'finderPetId': egg.finderPetId,
    'incubationBondXp': egg.incubationBondXp,
    'imprints': egg.imprints.map((category) => category.name).toList(),
  };
}

Egg _eggFromMap(Map<String, dynamic> map) {
  return Egg(
    id: _stringFromValue(map['id']),
    templateId: _stringFromValue(map['templateId'], fallback: 'wave-naru'),
    originRegionId: _stringFromValue(map['originRegionId'], fallback: 'korea'),
    progress: _intFromValue(map['progress']) ?? 0,
    requiredSteps: _intFromValue(map['requiredSteps']) ?? 3500,
    status: _eggStatusFromName(_stringFromValue(map['status'])),
    createdAt: _dateFromValue(map['createdAt']),
    originPoiId: _nullableStringFromValue(map['originPoiId']),
    finderPetId: _nullableStringFromValue(map['finderPetId']),
    incubationBondXp: _intFromValue(map['incubationBondXp']) ?? 0,
    imprints: _listOfStrings(map['imprints'])
        .map(_categoryFromName)
        .toList(growable: false),
  );
}

Map<String, dynamic> _checkInToMap(CheckIn checkIn) {
  return {
    'id': checkIn.id,
    'poiId': checkIn.poiId,
    'regionId': checkIn.regionId,
    'category': checkIn.category.name,
    'createdAt': checkIn.createdAt.toIso8601String(),
    'distanceMeters': checkIn.distanceMeters,
    'rewardApplied': checkIn.rewardApplied,
    'reward': checkIn.reward == null ? null : _rewardToMap(checkIn.reward!),
    'companionPetId': checkIn.companionPetId,
    'creditedEggId': checkIn.creditedEggId,
  };
}

CheckIn _checkInFromMap(Map<String, dynamic> map) {
  return CheckIn(
    id: _stringFromValue(map['id']),
    poiId: _stringFromValue(map['poiId']),
    regionId: _stringFromValue(map['regionId'], fallback: 'korea'),
    category: _categoryFromName(_stringFromValue(map['category'])),
    createdAt: _dateFromValue(map['createdAt']),
    distanceMeters: _doubleFromValue(map['distanceMeters']) ?? 0,
    rewardApplied: map['rewardApplied'] == true,
    reward: _rewardFromMap(map['reward']),
    companionPetId: _nullableStringFromValue(map['companionPetId']),
    creditedEggId: _nullableStringFromValue(map['creditedEggId']),
  );
}

Map<String, dynamic> _rewardToMap(CheckInReward reward) {
  return {
    'stats': _statsToMap(reward.stats),
    'eggProgress': reward.eggProgress,
  };
}

CheckInReward? _rewardFromMap(Object? value) {
  final map = _mapFromValue(value);
  if (map.isEmpty) {
    return null;
  }
  return CheckInReward(
    stats: _statsFromMap(_mapOrEmpty(map['stats'])),
    eggProgress: _intFromValue(map['eggProgress']) ?? 0,
  );
}

Map<String, dynamic> _statsToMap(GrowthStats stats) {
  return {
    'exp': stats.exp,
    'mood': stats.mood,
    'knowledge': stats.knowledge,
    'affinity': stats.affinity,
  };
}

GrowthStats _statsFromMap(Map<String, dynamic> map) {
  return GrowthStats(
    exp: _intFromValue(map['exp']) ?? 0,
    mood: _intFromValue(map['mood']) ?? 0,
    knowledge: _intFromValue(map['knowledge']) ?? 0,
    affinity: _intFromValue(map['affinity']) ?? 0,
  );
}

Map<String, dynamic> _coordinatesToMap(Coordinates coordinates) {
  return {
    'latitude': coordinates.latitude,
    'longitude': coordinates.longitude,
  };
}

Coordinates _coordinatesFromMap(
  Map<String, dynamic> map, {
  Coordinates fallback =
      const Coordinates(latitude: 35.1587, longitude: 129.1604),
}) {
  final latitude = _doubleFromValue(map['latitude']);
  final longitude = _doubleFromValue(map['longitude']);
  if (latitude == null || longitude == null) {
    return fallback;
  }
  return Coordinates(
    latitude: latitude,
    longitude: longitude,
  );
}

PetStage _petStageFromName(String? name) {
  return PetStage.values.firstWhere(
    (stage) => stage.name == name,
    orElse: () => PetStage.baby,
  );
}

EggStatus _eggStatusFromName(String? name) {
  return EggStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => EggStatus.incubating,
  );
}

PoiCategory _categoryFromName(String? name) {
  return PoiCategory.values.firstWhere(
    (category) => category.name == name,
    orElse: () => PoiCategory.other,
  );
}

PoiCategory? _nullableCategoryFromName(String? name) {
  if (name == null || name.isEmpty) {
    return null;
  }
  return _categoryFromName(name);
}

PetAilment _petAilmentFromName(String? name) {
  return PetAilment.values.firstWhere(
    (value) => value.name == name,
    orElse: () => PetAilment.none,
  );
}

PetFood? _nullablePetFoodFromName(String? name) {
  if (name == null || name.isEmpty) {
    return null;
  }
  for (final value in PetFood.values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

DateTime _dateFromValue(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

DateTime? _nullableDateFromValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

List<Map<String, dynamic>> _listOfMaps(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<Map>().map(_mapFromValue).toList();
}

List<String> _listOfStrings(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList(growable: false);
}

Map<String, dynamic> _mapOrEmpty(Object? value) {
  return _mapFromValue(value);
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
  final string = _stringFromValue(value);
  return string.isEmpty ? null : string;
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
