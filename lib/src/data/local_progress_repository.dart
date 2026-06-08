import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(snapshot.toMap()));
  }

  @override
  Future<void> clearProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
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
    required this.lastVisitedCategory,
    required this.dialogueCountToday,
    required this.dialogueDay,
  });

  factory LocalProgressSnapshot.fromMap(Map<String, dynamic> map) {
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
      lastVisitedCategory: _nullableCategoryFromName(
        _stringFromValue(map['lastVisitedCategory']),
      ),
      dialogueCountToday: _intFromValue(map['dialogueCountToday']) ?? 0,
      dialogueDay: _dateFromValue(map['dialogueDay']),
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
  final PoiCategory? lastVisitedCategory;
  final int dialogueCountToday;
  final DateTime dialogueDay;

  Map<String, dynamic> toMap() {
    return {
      'version': 1,
      'onboardingComplete': onboardingComplete,
      'pois': pois.map(_poiToMap).toList(),
      'pets': pets.map(_petToMap).toList(),
      'eggs': eggs.map(_eggToMap).toList(),
      'checkIns': checkIns.map(_checkInToMap).toList(),
      'currentLocation': _coordinatesToMap(currentLocation),
      'locationVerified': locationVerified,
      'locationVerifiedAt': locationVerifiedAt?.toIso8601String(),
      'activePetId': activePetId,
      'lastVisitedCategory': lastVisitedCategory?.name,
      'dialogueCountToday': dialogueCountToday,
      'dialogueDay': dialogueDay.toIso8601String(),
    };
  }
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
