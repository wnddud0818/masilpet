import 'dart:math' as math;

const checkInRadiusMeters = 150.0;
const dailyCheckInLimit = 20;
const dailyCareRoutineTarget = 4;
const dailyCareRewardPoints = 30;
const dailyFeedCareLimit = 3;
const maxStoredEggs = 5;
const dailyPetTalkLimit = 5;

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

enum PetBondLevel {
  unfamiliar,
  walkingCompanion,
  bestFriend,
  kindredSpirit,
}

extension PetBondLevelLabel on PetBondLevel {
  String get label => switch (this) {
        PetBondLevel.unfamiliar => '낯선 사이',
        PetBondLevel.walkingCompanion => '산책 동료',
        PetBondLevel.bestFriend => '단짝',
        PetBondLevel.kindredSpirit => '마음이 통한 사이',
      };
}

enum EggRevealStage {
  quiet,
  stirring,
  silhouette,
  personalityHint,
  ready,
}

extension EggRevealStageLabel on EggRevealStage {
  String get label => switch (this) {
        EggRevealStage.quiet => '아직 조용하지만 따뜻한 기운이 느껴져요.',
        EggRevealStage.stirring => '알 안에서 작은 박자가 들리기 시작했어요.',
        EggRevealStage.silhouette => '빛에 비추면 작은 실루엣이 보여요.',
        EggRevealStage.personalityHint => '곧 만날 친구의 성격이 조금씩 느껴져요.',
        EggRevealStage.ready => '안에서 힘찬 인사가 들려요. 이제 만날 수 있어요!',
      };
}

enum PetFood {
  homeMeal,
  fishSnack,
  fruit,
  vegetable,
  regionalTreat,
}

extension PetFoodLabel on PetFood {
  String get label => switch (this) {
        PetFood.homeMeal => '따뜻한 집밥',
        PetFood.fishSnack => '바삭 생선 간식',
        PetFood.fruit => '제철 과일',
        PetFood.vegetable => '아삭 채소',
        PetFood.regionalTreat => '지역 특산 간식',
      };

  String get shortLabel => switch (this) {
        PetFood.homeMeal => '집밥',
        PetFood.fishSnack => '생선',
        PetFood.fruit => '과일',
        PetFood.vegetable => '채소',
        PetFood.regionalTreat => '특산 간식',
      };
}

enum PetTouch {
  head,
  cheek,
  paw,
  tail,
  hug,
}

extension PetTouchLabel on PetTouch {
  String get label => switch (this) {
        PetTouch.head => '머리 쓰다듬기',
        PetTouch.cheek => '볼 문지르기',
        PetTouch.paw => '발 인사',
        PetTouch.tail => '꼬리 톡',
        PetTouch.hug => '꼭 안아주기',
      };
}

enum PetPersonality {
  foodie,
  tidy,
  sleepy,
  curious,
  shy,
  affectionate,
}

extension PetPersonalityLabel on PetPersonality {
  String get label => switch (this) {
        PetPersonality.foodie => '먹보',
        PetPersonality.tidy => '깔끔이',
        PetPersonality.sleepy => '잠꾸러기',
        PetPersonality.curious => '호기심쟁이',
        PetPersonality.shy => '수줍음쟁이',
        PetPersonality.affectionate => '애교쟁이',
      };

  String get description => switch (this) {
        PetPersonality.foodie => '새로운 먹을거리를 가장 먼저 찾아요.',
        PetPersonality.tidy => '깨끗한 방과 목욕 시간을 좋아해요.',
        PetPersonality.sleepy => '포근하게 쉬면 활력을 빨리 되찾아요.',
        PetPersonality.curious => '처음 가는 장소와 긴 산책을 좋아해요.',
        PetPersonality.shy => '낯선 곳에서는 천천히 마음을 열어요.',
        PetPersonality.affectionate => '쓰다듬기와 대화로 금세 행복해져요.',
      };
}

enum PetAilment {
  none,
  tummyAche,
  itchy,
  exhausted,
}

extension PetAilmentLabel on PetAilment {
  String get label => switch (this) {
        PetAilment.none => '건강해요',
        PetAilment.tummyAche => '배가 더부룩해요',
        PetAilment.itchy => '몸이 간지러워요',
        PetAilment.exhausted => '많이 지쳤어요',
      };
}

enum PetGrowthTendency {
  balanced,
  explorer,
  gourmet,
  scholar,
  affectionate,
  elegant,
}

extension PetGrowthTendencyLabel on PetGrowthTendency {
  String get label => switch (this) {
        PetGrowthTendency.balanced => '차분한 동행형',
        PetGrowthTendency.explorer => '용감한 탐험가형',
        PetGrowthTendency.gourmet => '행복한 미식가형',
        PetGrowthTendency.scholar => '호기심 많은 학자형',
        PetGrowthTendency.affectionate => '다정한 애교형',
        PetGrowthTendency.elegant => '반짝이는 우아형',
      };
}

enum PetNeed {
  content,
  hungry,
  dirty,
  tired,
  bored,
  potty,
  sick,
  sleeping,
  wantsWalk,
}

extension PetNeedLabel on PetNeed {
  String get title => switch (this) {
        PetNeed.content => '지금은 아주 편안해요',
        PetNeed.hungry => '밥그릇을 자꾸 쳐다봐요',
        PetNeed.dirty => '몸을 털며 씻고 싶어 해요',
        PetNeed.tired => '포근한 자리를 찾고 있어요',
        PetNeed.bored => '장난감을 물고 기다려요',
        PetNeed.potty => '주변을 말끔히 치워 주세요',
        PetNeed.sick => '오늘은 조금 살펴봐 주세요',
        PetNeed.sleeping => '지금 꿈꾸고 있어요',
        PetNeed.wantsWalk => '현관 앞에서 산책을 기다려요',
      };

  String get actionLabel => switch (this) {
        PetNeed.hungry => '밥 주기',
        PetNeed.dirty => '씻기기',
        PetNeed.tired => '재우기',
        PetNeed.bored => '놀아주기',
        PetNeed.potty => '치워주기',
        PetNeed.sick => '돌봐주기',
        PetNeed.sleeping => '깨우기',
        PetNeed.wantsWalk => '산책 나가기',
        PetNeed.content => '쓰다듬기',
      };
}

class PetMemory {
  const PetMemory({
    required this.id,
    required this.title,
    required this.detail,
    required this.createdAt,
    this.category,
  });

  final String id;
  final String title;
  final String detail;
  final DateTime createdAt;
  final PoiCategory? category;
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

class PetCareState {
  PetCareState({
    int satiety = 72,
    int cleanliness = 76,
    int vitality = 74,
    int happiness = 72,
    required this.updatedAt,
    DateTime? dailyCountDay,
    int feedCountToday = 0,
    int playCountToday = 0,
    int cleanCountToday = 0,
    int talkCountToday = 0,
    int petCountToday = 0,
    int bondedDays = 0,
    this.lastBondedDay,
    int wasteCount = 0,
    DateTime? lastWasteAt,
    this.isSleeping = false,
    this.sleepStartedAt,
    this.ailment = PetAilment.none,
    this.ailmentUntil,
    this.lastFood,
    int sameFoodStreak = 0,
    int walkStepsToday = 0,
    DateTime? walkDay,
    int adventureScore = 0,
    int gourmetScore = 0,
    int knowledgeScore = 0,
    int affectionScore = 0,
    int eleganceScore = 0,
    List<PetMemory> memories = const [],
  })  : satiety = _boundedCareValue(satiety),
        cleanliness = _boundedCareValue(cleanliness),
        vitality = _boundedCareValue(vitality),
        happiness = _boundedCareValue(happiness),
        dailyCountDay = dailyCountDay ?? updatedAt,
        feedCountToday = math.max(0, feedCountToday),
        playCountToday = math.max(0, playCountToday),
        cleanCountToday = math.max(0, cleanCountToday),
        talkCountToday = math.max(0, talkCountToday),
        petCountToday = math.max(0, petCountToday),
        bondedDays = math.max(0, bondedDays),
        wasteCount = wasteCount.clamp(0, 3).toInt(),
        lastWasteAt = lastWasteAt ?? updatedAt,
        sameFoodStreak = math.max(0, sameFoodStreak),
        walkStepsToday = math.max(0, walkStepsToday),
        walkDay = walkDay ?? updatedAt,
        adventureScore = math.max(0, adventureScore),
        gourmetScore = math.max(0, gourmetScore),
        knowledgeScore = math.max(0, knowledgeScore),
        affectionScore = math.max(0, affectionScore),
        eleganceScore = math.max(0, eleganceScore),
        memories = List.unmodifiable(memories.take(24));

  factory PetCareState.initial(DateTime now) {
    return PetCareState(updatedAt: now, dailyCountDay: now);
  }

  final int satiety;
  final int cleanliness;
  final int vitality;
  final int happiness;
  final DateTime updatedAt;
  final DateTime dailyCountDay;
  final int feedCountToday;
  final int playCountToday;
  final int cleanCountToday;
  final int talkCountToday;
  final int petCountToday;
  final int bondedDays;
  final DateTime? lastBondedDay;
  final int wasteCount;
  final DateTime lastWasteAt;
  final bool isSleeping;
  final DateTime? sleepStartedAt;
  final PetAilment ailment;
  final DateTime? ailmentUntil;
  final PetFood? lastFood;
  final int sameFoodStreak;
  final int walkStepsToday;
  final DateTime walkDay;
  final int adventureScore;
  final int gourmetScore;
  final int knowledgeScore;
  final int affectionScore;
  final int eleganceScore;
  final List<PetMemory> memories;

  double get overallRatio {
    return (satiety + cleanliness + vitality + happiness) / 400;
  }

  PetGrowthTendency get growthTendency {
    final scores = <PetGrowthTendency, int>{
      PetGrowthTendency.explorer: adventureScore,
      PetGrowthTendency.gourmet: gourmetScore,
      PetGrowthTendency.scholar: knowledgeScore,
      PetGrowthTendency.affectionate: affectionScore,
      PetGrowthTendency.elegant: eleganceScore,
    };
    final best = scores.entries.reduce(
      (left, right) => right.value > left.value ? right : left,
    );
    return best.value < 5 ? PetGrowthTendency.balanced : best.key;
  }

  String get conditionLabel {
    if (isSleeping) {
      return '꿈꾸는 중';
    }
    if (ailment != PetAilment.none) {
      return ailment.label;
    }
    if (overallRatio >= 0.82 && wasteCount == 0) {
      return '반짝반짝 건강해요';
    }
    return '평온해요';
  }

  PetCareState copyWith({
    int? satiety,
    int? cleanliness,
    int? vitality,
    int? happiness,
    DateTime? updatedAt,
    DateTime? dailyCountDay,
    int? feedCountToday,
    int? playCountToday,
    int? cleanCountToday,
    int? talkCountToday,
    int? petCountToday,
    int? bondedDays,
    DateTime? lastBondedDay,
    bool clearLastBondedDay = false,
    int? wasteCount,
    DateTime? lastWasteAt,
    bool? isSleeping,
    DateTime? sleepStartedAt,
    bool clearSleepStartedAt = false,
    PetAilment? ailment,
    DateTime? ailmentUntil,
    bool clearAilmentUntil = false,
    PetFood? lastFood,
    int? sameFoodStreak,
    int? walkStepsToday,
    DateTime? walkDay,
    int? adventureScore,
    int? gourmetScore,
    int? knowledgeScore,
    int? affectionScore,
    int? eleganceScore,
    List<PetMemory>? memories,
  }) {
    return PetCareState(
      satiety: satiety ?? this.satiety,
      cleanliness: cleanliness ?? this.cleanliness,
      vitality: vitality ?? this.vitality,
      happiness: happiness ?? this.happiness,
      updatedAt: updatedAt ?? this.updatedAt,
      dailyCountDay: dailyCountDay ?? this.dailyCountDay,
      feedCountToday: feedCountToday ?? this.feedCountToday,
      playCountToday: playCountToday ?? this.playCountToday,
      cleanCountToday: cleanCountToday ?? this.cleanCountToday,
      talkCountToday: talkCountToday ?? this.talkCountToday,
      petCountToday: petCountToday ?? this.petCountToday,
      bondedDays: bondedDays ?? this.bondedDays,
      lastBondedDay:
          clearLastBondedDay ? null : lastBondedDay ?? this.lastBondedDay,
      wasteCount: wasteCount ?? this.wasteCount,
      lastWasteAt: lastWasteAt ?? this.lastWasteAt,
      isSleeping: isSleeping ?? this.isSleeping,
      sleepStartedAt:
          clearSleepStartedAt ? null : sleepStartedAt ?? this.sleepStartedAt,
      ailment: ailment ?? this.ailment,
      ailmentUntil:
          clearAilmentUntil ? null : ailmentUntil ?? this.ailmentUntil,
      lastFood: lastFood ?? this.lastFood,
      sameFoodStreak: sameFoodStreak ?? this.sameFoodStreak,
      walkStepsToday: walkStepsToday ?? this.walkStepsToday,
      walkDay: walkDay ?? this.walkDay,
      adventureScore: adventureScore ?? this.adventureScore,
      gourmetScore: gourmetScore ?? this.gourmetScore,
      knowledgeScore: knowledgeScore ?? this.knowledgeScore,
      affectionScore: affectionScore ?? this.affectionScore,
      eleganceScore: eleganceScore ?? this.eleganceScore,
      memories: memories ?? this.memories,
    );
  }
}

class DailyCareRoutineProgress {
  const DailyCareRoutineProgress({
    required this.fed,
    required this.played,
    required this.cleaned,
    required this.talked,
    required this.checkedIn,
  });

  final bool fed;
  final bool played;
  final bool cleaned;
  final bool talked;
  final bool checkedIn;

  int get completedCount {
    return [fed, played, cleaned, talked, checkedIn]
        .where((completed) => completed)
        .length;
  }

  int get targetCount => dailyCareRoutineTarget;

  int get remainingCount {
    return (targetCount - completedCount).clamp(0, targetCount).toInt();
  }

  bool get isComplete => completedCount >= targetCount;
}

int _boundedCareValue(int value) {
  return value.clamp(0, 100).toInt();
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

/// Whether a word ends in a consonant — the fork every Korean particle takes.
bool endsWithFinalConsonant(String word) {
  if (word.isEmpty) {
    return false;
  }
  final code = word.codeUnitAt(word.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) {
    return false;
  }
  return (code - 0xAC00) % 28 != 0;
}

/// Picks the particle that fits the name: 해랑은 / 누비는, 해랑이 / 누비가.
/// Non-Hangul endings take the vowel form, which reads least wrong.
String particleFor(String word, String afterConsonant, String afterVowel) {
  return endsWithFinalConsonant(word) ? afterConsonant : afterVowel;
}

/// How a pet is addressed out loud. Korean adds 이 when the name ends in a
/// consonant (해랑 → 해랑이) and leaves it off when it ends in a vowel (누비).
String petCallName(String name) {
  return endsWithFinalConsonant(name) ? '$name이' : name;
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
    this.originEggId,
    this.reunionCount = 0,
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
  final String? originEggId;
  final int reunionCount;

  PetBondLevel get bondLevel {
    if (stats.affinity >= 100) {
      return PetBondLevel.kindredSpirit;
    }
    if (stats.affinity >= 60) {
      return PetBondLevel.bestFriend;
    }
    if (stats.affinity >= 20) {
      return PetBondLevel.walkingCompanion;
    }
    return PetBondLevel.unfamiliar;
  }

  Pet copyWith({
    String? name,
    PetStage? stage,
    int? level,
    GrowthStats? stats,
    DateTime? lastInteractedAt,
    String? originEggId,
    int? reunionCount,
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
      originEggId: originEggId ?? this.originEggId,
      reunionCount: reunionCount ?? this.reunionCount,
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
    this.originPoiId,
    this.finderPetId,
    this.incubationBondXp = 0,
    this.imprints = const [],
  });

  final String id;
  final String templateId;
  final String originRegionId;
  final int progress;
  final int requiredSteps;
  final EggStatus status;
  final DateTime createdAt;
  final String? originPoiId;
  final String? finderPetId;
  final int incubationBondXp;
  final List<PoiCategory> imprints;

  double get progressRatio {
    if (requiredSteps == 0) {
      return 1;
    }
    return (progress / requiredSteps).clamp(0.0, 1.0).toDouble();
  }

  EggRevealStage get revealStage {
    if (status == EggStatus.hatchable || progressRatio >= 1) {
      return EggRevealStage.ready;
    }
    if (progressRatio >= 0.75) {
      return EggRevealStage.personalityHint;
    }
    if (progressRatio >= 0.5) {
      return EggRevealStage.silhouette;
    }
    if (progressRatio >= 0.25) {
      return EggRevealStage.stirring;
    }
    return EggRevealStage.quiet;
  }

  Egg copyWith({
    int? progress,
    EggStatus? status,
    int? incubationBondXp,
    List<PoiCategory>? imprints,
  }) {
    return Egg(
      id: id,
      templateId: templateId,
      originRegionId: originRegionId,
      progress: progress ?? this.progress,
      requiredSteps: requiredSteps,
      status: status ?? this.status,
      createdAt: createdAt,
      originPoiId: originPoiId,
      finderPetId: finderPetId,
      incubationBondXp: incubationBondXp ?? this.incubationBondXp,
      imprints: imprints ?? this.imprints,
    );
  }
}

class HatchOutcome {
  const HatchOutcome({
    required this.petId,
    required this.reunion,
  });

  final String petId;
  final bool reunion;
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
    this.reward,
    this.companionPetId,
    this.creditedEggId,
  });

  final String id;
  final String poiId;
  final String regionId;
  final PoiCategory category;
  final DateTime createdAt;
  final double distanceMeters;
  final bool rewardApplied;
  final CheckInReward? reward;
  final String? companionPetId;
  final String? creditedEggId;
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
