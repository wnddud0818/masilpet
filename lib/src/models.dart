import 'dart:math' as math;

const checkInRadiusMeters = 150.0;

enum PoiCategory {
  nature,
  food,
  festival,
  culture,
  history,
  shopping,
  other,
}

extension PoiCategoryLabel on PoiCategory {
  String get label {
    switch (this) {
      case PoiCategory.nature:
        return '자연';
      case PoiCategory.food:
        return '음식';
      case PoiCategory.festival:
        return '축제';
      case PoiCategory.culture:
        return '문화';
      case PoiCategory.history:
        return '역사';
      case PoiCategory.shopping:
        return '시장';
      case PoiCategory.other:
        return '기타';
    }
  }

  String get tourApiHint {
    switch (this) {
      case PoiCategory.nature:
        return '관광지/자연';
      case PoiCategory.food:
        return '음식점';
      case PoiCategory.festival:
        return '축제/공연/행사';
      case PoiCategory.culture:
        return '문화시설';
      case PoiCategory.history:
        return '관광지/문화재';
      case PoiCategory.shopping:
        return '쇼핑';
      case PoiCategory.other:
        return '기타';
    }
  }
}

enum PetStage {
  baby,
  grown,
  evolved,
}

extension PetStageLabel on PetStage {
  String get label {
    switch (this) {
      case PetStage.baby:
        return '새싹';
      case PetStage.grown:
        return '성장';
      case PetStage.evolved:
        return '진화';
    }
  }
}

enum EggStatus {
  incubating,
  hatchable,
  hatched,
}

enum PetFieldActivity {
  idle,
  walking,
  eating,
  greeting,
  jumping,
  sleeping,
}

class Coordinates {
  const Coordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  double distanceTo(Coordinates other) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _radians(latitude);
    final lat2 = _radians(other.latitude);
    final dLat = _radians(other.latitude - latitude);
    final dLng = _radians(other.longitude - longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _radians(double degrees) => degrees * math.pi / 180.0;
}

class Region {
  const Region({
    required this.id,
    required this.name,
    required this.areaCode,
    required this.center,
    required this.pilotEnabled,
  });

  final String id;
  final String name;
  final String areaCode;
  final Coordinates center;
  final bool pilotEnabled;
}

class Poi {
  const Poi({
    required this.id,
    required this.tourApiContentId,
    required this.title,
    required this.regionId,
    required this.category,
    required this.coordinates,
    required this.shortDescription,
  });

  final String id;
  final String tourApiContentId;
  final String title;
  final String regionId;
  final PoiCategory category;
  final Coordinates coordinates;
  final String shortDescription;
}

class GrowthStats {
  const GrowthStats({
    required this.exp,
    required this.mood,
    required this.knowledge,
    required this.affinity,
  });

  const GrowthStats.zero()
      : exp = 0,
        mood = 0,
        knowledge = 0,
        affinity = 0;

  final int exp;
  final int mood;
  final int knowledge;
  final int affinity;

  GrowthStats copyWith({
    int? exp,
    int? mood,
    int? knowledge,
    int? affinity,
  }) {
    return GrowthStats(
      exp: exp ?? this.exp,
      mood: mood ?? this.mood,
      knowledge: knowledge ?? this.knowledge,
      affinity: affinity ?? this.affinity,
    );
  }

  GrowthStats add(GrowthStats other) {
    return GrowthStats(
      exp: exp + other.exp,
      mood: mood + other.mood,
      knowledge: knowledge + other.knowledge,
      affinity: affinity + other.affinity,
    );
  }
}

class PetTemplate {
  const PetTemplate({
    required this.id,
    required this.name,
    required this.regionId,
    required this.rarity,
    required this.primaryCategory,
    required this.basePersonality,
    required this.colorValue,
    required this.initials,
    required this.assetKey,
  });

  final String id;
  final String name;
  final String regionId;
  final String rarity;
  final PoiCategory primaryCategory;
  final String basePersonality;
  final int colorValue;
  final String initials;
  final String assetKey;
}

extension PetTemplateRarityLabel on PetTemplate {
  String get rarityLabel => rarityDisplayLabel(rarity);
}

String rarityDisplayLabel(String rarity) {
  switch (rarity.trim().toLowerCase()) {
    case 'common':
      return '일반';
    case 'rare':
      return '희귀';
    case 'epic':
      return '영웅';
    default:
      return rarity;
  }
}

class Pet {
  const Pet({
    required this.id,
    required this.templateId,
    required this.name,
    required this.stage,
    required this.level,
    required this.stats,
    required this.originRegionId,
    required this.hatchedAt,
    required this.lastInteractedAt,
  });

  final String id;
  final String templateId;
  final String name;
  final PetStage stage;
  final int level;
  final GrowthStats stats;
  final String originRegionId;
  final DateTime hatchedAt;
  final DateTime? lastInteractedAt;

  Pet copyWith({
    String? name,
    PetStage? stage,
    int? level,
    GrowthStats? stats,
    DateTime? lastInteractedAt,
  }) {
    return Pet(
      id: id,
      templateId: templateId,
      name: name ?? this.name,
      stage: stage ?? this.stage,
      level: level ?? this.level,
      stats: stats ?? this.stats,
      originRegionId: originRegionId,
      hatchedAt: hatchedAt,
      lastInteractedAt: lastInteractedAt ?? this.lastInteractedAt,
    );
  }
}

class Egg {
  const Egg({
    required this.id,
    required this.templateId,
    required this.originRegionId,
    required this.progress,
    required this.requiredSteps,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String templateId;
  final String originRegionId;
  final int progress;
  final int requiredSteps;
  final EggStatus status;
  final DateTime createdAt;

  double get progressRatio {
    if (requiredSteps == 0) {
      return 1;
    }
    return (progress / requiredSteps).clamp(0.0, 1.0).toDouble();
  }

  Egg copyWith({
    int? progress,
    EggStatus? status,
  }) {
    return Egg(
      id: id,
      templateId: templateId,
      originRegionId: originRegionId,
      progress: progress ?? this.progress,
      requiredSteps: requiredSteps,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

class CheckIn {
  const CheckIn({
    required this.id,
    required this.poiId,
    required this.regionId,
    required this.category,
    required this.createdAt,
    required this.distanceMeters,
    required this.rewardApplied,
  });

  final String id;
  final String poiId;
  final String regionId;
  final PoiCategory category;
  final DateTime createdAt;
  final double distanceMeters;
  final bool rewardApplied;
}

class CheckInReward {
  const CheckInReward({
    required this.stats,
    required this.eggProgress,
  });

  final GrowthStats stats;
  final int eggProgress;
}

extension CheckInRewardSummary on CheckInReward {
  String get summaryLabel {
    return [
      'EXP +${stats.exp}',
      if (stats.mood > 0) '기분 +${stats.mood}',
      if (stats.knowledge > 0) '지식 +${stats.knowledge}',
      if (stats.affinity > 0) '친밀도 +${stats.affinity}',
      '알 +$eggProgress',
    ].join(' · ');
  }
}

class DialogueLine {
  const DialogueLine({
    required this.id,
    required this.templateId,
    required this.trigger,
    required this.text,
  });

  final String id;
  final String templateId;
  final String trigger;
  final String text;
}
