import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models.dart';
import 'seed_data.dart';

class GrowthEngine {
  const GrowthEngine();

  static const grownLevelRequirement = 3;
  static const evolvedLevelRequirement = 5;
  static const evolvedKnowledgeRequirement = 50;
  static const evolvedAffinityRequirement = 100;

  CheckInReward rewardFor(PoiCategory category) {
    switch (category) {
      case PoiCategory.food:
        return const CheckInReward(
          stats: GrowthStats(exp: 18, mood: 16, knowledge: 1, affinity: 5),
          eggProgress: 620,
        );
      case PoiCategory.festival:
        return const CheckInReward(
          stats: GrowthStats(exp: 24, mood: 22, knowledge: 3, affinity: 8),
          eggProgress: 820,
        );
      case PoiCategory.culture:
        return const CheckInReward(
          stats: GrowthStats(exp: 20, mood: 5, knowledge: 18, affinity: 6),
          eggProgress: 700,
        );
      case PoiCategory.history:
        return const CheckInReward(
          stats: GrowthStats(exp: 22, mood: 4, knowledge: 22, affinity: 8),
          eggProgress: 760,
        );
      case PoiCategory.nature:
        return const CheckInReward(
          stats: GrowthStats(exp: 18, mood: 8, knowledge: 4, affinity: 12),
          eggProgress: 680,
        );
      case PoiCategory.shopping:
        return const CheckInReward(
          stats: GrowthStats(exp: 16, mood: 10, knowledge: 4, affinity: 6),
          eggProgress: 600,
        );
      case PoiCategory.other:
        return const CheckInReward(
          stats: GrowthStats(exp: 14, mood: 8, knowledge: 4, affinity: 5),
          eggProgress: 540,
        );
    }
  }

  int levelFor(GrowthStats stats) {
    return math.max(1, (stats.exp ~/ 100) + 1);
  }

  PetStage stageFor({
    required int level,
    required GrowthStats stats,
    required PetStage currentStage,
  }) {
    if (level >= evolvedLevelRequirement &&
        stats.affinity >= evolvedAffinityRequirement &&
        stats.knowledge >= evolvedKnowledgeRequirement) {
      return PetStage.evolved;
    }
    if (level >= grownLevelRequirement) {
      return PetStage.grown;
    }
    return currentStage;
  }

  Egg progressEgg(Egg egg, int stepDelta) {
    if (egg.status == EggStatus.hatched) {
      return egg;
    }

    final nextProgress = egg.progress + (stepDelta < 0 ? 0 : stepDelta);
    if (nextProgress >= egg.requiredSteps) {
      return egg.copyWith(
        progress: egg.requiredSteps,
        status: EggStatus.hatchable,
      );
    }

    return egg.copyWith(progress: nextProgress);
  }
}

class CareEngine {
  const CareEngine();

  static const maxDecayDuration = Duration(hours: 24);
  static const satietyDecayInterval = Duration(hours: 2);
  static const cleanlinessDecayInterval = Duration(hours: 3);
  static const vitalityDecayInterval = Duration(hours: 4);
  static const wasteInterval = Duration(hours: 8);

  PetCareState resolve(
    PetCareState care,
    DateTime now, {
    bool stayingHome = false,
  }) {
    final elapsed = now.difference(care.updatedAt);
    final elapsedMinutes = elapsed.isNegative
        ? 0
        : math.min(elapsed.inMinutes, maxDecayDuration.inMinutes);
    final homeFactor = stayingHome ? 4 : 1;
    final sameCountDay = isSameLocalDay(care.dailyCountDay, now);
    final sameWalkDay = isSameLocalDay(care.walkDay, now);
    final resolvedAt = now.isBefore(care.updatedAt) ? care.updatedAt : now;
    final sleepDuration = care.sleepStartedAt == null
        ? Duration.zero
        : now.difference(care.sleepStartedAt!);
    final wokeNaturally =
        care.isSleeping && sleepDuration >= const Duration(hours: 8);
    final sleeping = care.isSleeping && !wokeNaturally;
    final wasteElapsed = now.difference(care.lastWasteAt);
    final generatedWaste = stayingHome || wasteElapsed.isNegative
        ? 0
        : math.min(3, wasteElapsed.inMinutes ~/ wasteInterval.inMinutes);
    final sleepRecovery = care.isSleeping
        ? math.min(24, elapsedMinutes ~/ const Duration(minutes: 30).inMinutes)
        : 0;
    var ailment = care.ailment;
    DateTime? ailmentUntil = care.ailmentUntil;
    if (ailmentUntil != null && !now.isBefore(ailmentUntil)) {
      ailment = PetAilment.none;
      ailmentUntil = null;
    }
    final nextWaste = math.min(3, care.wasteCount + generatedWaste);
    final nextVitality = care.vitality -
        (care.isSleeping
            ? 0
            : elapsedMinutes ~/
                (vitalityDecayInterval.inMinutes * homeFactor)) +
        sleepRecovery;
    if (!stayingHome && ailment == PetAilment.none && nextWaste >= 2) {
      ailment = PetAilment.itchy;
      ailmentUntil = now.add(const Duration(hours: 2));
    } else if (!stayingHome &&
        ailment == PetAilment.none &&
        nextVitality <= 15) {
      ailment = PetAilment.exhausted;
      ailmentUntil = now.add(const Duration(hours: 2));
    }

    final resolvedSatiety = care.satiety -
        (elapsedMinutes ~/ (satietyDecayInterval.inMinutes * homeFactor));
    final resolvedCleanliness = care.cleanliness -
        (elapsedMinutes ~/ (cleanlinessDecayInterval.inMinutes * homeFactor));
    final resolvedHappiness = care.happiness -
        (elapsedMinutes ~/ (const Duration(hours: 4).inMinutes * homeFactor));
    return care.copyWith(
      satiety: stayingHome ? math.max(55, resolvedSatiety) : resolvedSatiety,
      cleanliness:
          stayingHome ? math.max(55, resolvedCleanliness) : resolvedCleanliness,
      vitality: stayingHome ? math.max(55, nextVitality) : nextVitality,
      happiness:
          stayingHome ? math.max(55, resolvedHappiness) : resolvedHappiness,
      wasteCount: nextWaste,
      // 집에서 쉬는 동안에는 배설물이 생기지 않으므로 기준 시각도 함께 밀어준다.
      // 그러지 않으면 쉬는 내내 시간이 빚처럼 쌓였다가, 돌봄 액션이
      // 보호 없이 다시 resolve 하는 순간 한꺼번에 터진다.
      lastWasteAt: generatedWaste > 0 || stayingHome ? now : care.lastWasteAt,
      ailment: ailment,
      ailmentUntil: ailmentUntil,
      clearAilmentUntil: ailmentUntil == null,
      updatedAt: resolvedAt,
      dailyCountDay: sameCountDay ? care.dailyCountDay : now,
      feedCountToday: sameCountDay ? care.feedCountToday : 0,
      playCountToday: sameCountDay ? care.playCountToday : 0,
      cleanCountToday: sameCountDay ? care.cleanCountToday : 0,
      talkCountToday: sameCountDay ? care.talkCountToday : 0,
      petCountToday: sameCountDay ? care.petCountToday : 0,
      walkDay: sameWalkDay ? care.walkDay : now,
      walkStepsToday: sameWalkDay ? care.walkStepsToday : 0,
      isSleeping: sleeping,
      clearSleepStartedAt: wokeNaturally,
    );
  }

  PetPersonality personalityFor(PetTemplate template) {
    return PetPersonality.values[_stableIndex(
      '${template.id}:${template.basePersonality}',
      PetPersonality.values.length,
    )];
  }

  PetFood favoriteFoodFor(PetTemplate template) {
    return PetFood.values[_stableIndex(template.id, PetFood.values.length)];
  }

  PetFood dislikedFoodFor(PetTemplate template) {
    final favorite = favoriteFoodFor(template);
    return PetFood.values[
        (favorite.index + 2 + _stableIndex(template.assetKey, 2)) %
            PetFood.values.length];
  }

  PetTouch preferredTouchFor(PetTemplate template) {
    return PetTouch
        .values[_stableIndex(template.assetKey, PetTouch.values.length)];
  }

  PetNeed requestFor(PetCareState care, DateTime now) {
    final current = resolve(care, now);
    if (current.isSleeping) {
      return PetNeed.sleeping;
    }
    if (current.ailment != PetAilment.none) {
      return PetNeed.sick;
    }
    if (current.wasteCount > 0) {
      return PetNeed.potty;
    }
    if (current.satiety < 42) {
      return PetNeed.hungry;
    }
    if (current.cleanliness < 42) {
      return PetNeed.dirty;
    }
    if (current.vitality < 38) {
      return PetNeed.tired;
    }
    if (current.happiness < 45) {
      return PetNeed.bored;
    }
    if (now.hour >= 22 || now.hour < 7) {
      return PetNeed.tired;
    }
    if (current.walkStepsToday < 500 && now.hour >= 9 && now.hour < 20) {
      return PetNeed.wantsWalk;
    }
    return PetNeed.content;
  }

  PetCareState afterFeed(
    PetCareState care,
    DateTime now, {
    PetFood food = PetFood.homeMeal,
    PetFood? favoriteFood,
    PetFood? dislikedFood,
  }) {
    final current = resolve(care, now);
    final repeated = current.lastFood == food ? current.sameFoodStreak + 1 : 1;
    final isFavorite = food == favoriteFood;
    final isDisliked = food == dislikedFood;
    final overfed = current.satiety >= 90 || repeated >= 3;
    final gainsWaste = (current.feedCountToday + 1).isEven;
    return _markBonded(
        current.copyWith(
          satiety: current.satiety +
              (isFavorite
                  ? 34
                  : isDisliked
                      ? 20
                      : 28),
          vitality: current.vitality + 3,
          happiness: current.happiness +
              (isFavorite
                  ? 12
                  : isDisliked
                      ? 1
                      : 5),
          updatedAt: now,
          dailyCountDay: now,
          feedCountToday: current.feedCountToday + 1,
          wasteCount: current.wasteCount + (gainsWaste ? 1 : 0),
          lastFood: food,
          sameFoodStreak: repeated,
          gourmetScore: current.gourmetScore + (isFavorite ? 3 : 1),
          ailment: overfed ? PetAilment.tummyAche : current.ailment,
          ailmentUntil: overfed
              ? now.add(const Duration(hours: 2))
              : current.ailmentUntil,
          isSleeping: false,
          clearSleepStartedAt: true,
          memories: _withMemory(
            current.memories,
            PetMemory(
              id: 'food-${now.microsecondsSinceEpoch}',
              title: '${food.label}을 먹은 날',
              detail: isFavorite
                  ? '가장 좋아하는 음식이라 꼬리가 쉴 새 없이 흔들렸어요.'
                  : isDisliked
                      ? '조금 망설였지만 남김없이 먹었어요.'
                      : '새로운 맛을 차분히 기억해 두었어요.',
              createdAt: now,
              category: PoiCategory.food,
            ),
          ),
        ),
        now);
  }

  PetCareState afterPlay(PetCareState care, DateTime now) {
    final current = resolve(care, now);
    return _markBonded(
        current.copyWith(
          satiety: current.satiety - 2,
          cleanliness: current.cleanliness - 3,
          vitality: current.vitality + 18,
          happiness: current.happiness + 22,
          updatedAt: now,
          dailyCountDay: now,
          playCountToday: current.playCountToday + 1,
          affectionScore: current.affectionScore + 1,
          isSleeping: false,
          clearSleepStartedAt: true,
        ),
        now);
  }

  PetCareState afterClean(PetCareState care, DateTime now) {
    final current = resolve(care, now);
    return _markBonded(
        current.copyWith(
          cleanliness: current.cleanliness + 32,
          vitality: current.vitality + 2,
          happiness: current.happiness + 4,
          updatedAt: now,
          dailyCountDay: now,
          cleanCountToday: current.cleanCountToday + 1,
          wasteCount: 0,
          lastWasteAt: now,
          eleganceScore: current.eleganceScore + 2,
          ailment: current.ailment == PetAilment.itchy
              ? PetAilment.none
              : current.ailment,
          clearAilmentUntil: current.ailment == PetAilment.itchy,
        ),
        now);
  }

  PetCareState afterSleep(PetCareState care, DateTime now) {
    final current = resolve(care, now);
    return _markBonded(
        current.copyWith(
          satiety: current.satiety - 1,
          vitality: current.vitality + 34,
          happiness: current.happiness + 3,
          updatedAt: now,
          isSleeping: true,
          sleepStartedAt: now,
          ailment: current.ailment == PetAilment.exhausted
              ? PetAilment.none
              : current.ailment,
          clearAilmentUntil: current.ailment == PetAilment.exhausted,
        ),
        now);
  }

  PetCareState afterWake(PetCareState care, DateTime now) {
    final current = resolve(care, now);
    return _markBonded(
        current.copyWith(
          isSleeping: false,
          clearSleepStartedAt: true,
          vitality: current.vitality + 4,
          happiness: current.happiness + 2,
          updatedAt: now,
        ),
        now);
  }

  PetCareState afterTalk(PetCareState care, DateTime now) {
    final current = resolve(care, now);
    return _markBonded(
        current.copyWith(
          vitality: current.vitality + 6,
          happiness: current.happiness + 8,
          affectionScore: current.affectionScore + 2,
          talkCountToday: current.talkCountToday + 1,
          isSleeping: false,
          clearSleepStartedAt: true,
          updatedAt: now,
        ),
        now);
  }

  PetCareState afterTouch(
    PetCareState care,
    DateTime now, {
    required PetTouch touch,
    required PetTouch preferredTouch,
  }) {
    final current = resolve(care, now);
    final preferred = touch == preferredTouch;
    return _markBonded(
        current.copyWith(
          happiness: current.happiness +
              (preferred
                  ? 12
                  : touch == PetTouch.tail
                      ? 1
                      : 6),
          vitality: current.vitality + (touch == PetTouch.hug ? 4 : 1),
          petCountToday: current.petCountToday + 1,
          affectionScore: current.affectionScore + (preferred ? 3 : 1),
          isSleeping: false,
          clearSleepStartedAt: true,
          updatedAt: now,
        ),
        now);
  }

  PetCareState afterWasteClean(PetCareState care, DateTime now) {
    final current = resolve(care, now);
    return _markBonded(
        current.copyWith(
          wasteCount: 0,
          cleanliness: current.cleanliness + 18,
          happiness: current.happiness + 5,
          lastWasteAt: now,
          ailment: current.ailment == PetAilment.itchy
              ? PetAilment.none
              : current.ailment,
          clearAilmentUntil: current.ailment == PetAilment.itchy,
          eleganceScore: current.eleganceScore + 1,
          updatedAt: now,
        ),
        now);
  }

  PetCareState afterWalk(
    PetCareState care,
    DateTime now, {
    required int steps,
  }) {
    final current = resolve(care, now);
    final normalizedSteps = math.max(0, steps);
    final strenuous = normalizedSteps >= 5000;
    return _markBonded(
        current.copyWith(
          satiety: current.satiety - math.min(12, normalizedSteps ~/ 700),
          cleanliness:
              current.cleanliness - math.min(10, normalizedSteps ~/ 900),
          vitality: current.vitality +
              (strenuous ? -8 : math.min(8, normalizedSteps ~/ 500)),
          happiness: current.happiness + math.min(16, normalizedSteps ~/ 350),
          walkStepsToday: current.walkStepsToday + normalizedSteps,
          walkDay: now,
          adventureScore:
              current.adventureScore + math.max(1, normalizedSteps ~/ 500),
          ailment: strenuous && current.vitality < 35
              ? PetAilment.exhausted
              : current.ailment,
          ailmentUntil: strenuous && current.vitality < 35
              ? now.add(const Duration(hours: 2))
              : current.ailmentUntil,
          isSleeping: false,
          clearSleepStartedAt: true,
          updatedAt: now,
          memories: normalizedSteps < 1000
              ? current.memories
              : _withMemory(
                  current.memories,
                  PetMemory(
                    id: 'walk-${now.microsecondsSinceEpoch}',
                    title: '$normalizedSteps걸음을 함께 걸은 날',
                    detail: strenuous
                        ? '실컷 걷고 돌아와 포근한 낮잠을 기다리고 있어요.'
                        : '발걸음마다 새로운 냄새와 소리를 기억했어요.',
                    createdAt: now,
                  ),
                ),
        ),
        now);
  }

  PetCareState afterCheckIn(
    PetCareState care,
    DateTime now, {
    required Poi poi,
    required bool firstVisit,
  }) {
    final current = resolve(care, now);
    final isKnowledge = poi.category == PoiCategory.culture ||
        poi.category == PoiCategory.history;
    final isFood = poi.category == PoiCategory.food;
    // TourAPI 대분류에서 온 장소 성향만큼 해당 성향이 더 자란다.
    final tendencyBonus = firstVisit ? 4 : 2;
    int bonusFor(PoiTendency tendency) =>
        poi.tendency == tendency ? tendencyBonus : 0;
    // 반려동물 동반 가능 장소는 함께 간 경험이라 교감이 크게 오른다.
    final petFriendlyBonus = poi.isPetFriendly ? (firstVisit ? 5 : 3) : 0;

    return _markBonded(
        current.copyWith(
          happiness: current.happiness + (firstVisit ? 10 : 5),
          vitality: current.vitality + 3,
          adventureScore: current.adventureScore +
              (firstVisit ? 4 : 2) +
              bonusFor(PoiTendency.explorer),
          knowledgeScore: current.knowledgeScore +
              (isKnowledge ? 4 : 1) +
              bonusFor(PoiTendency.scholar),
          gourmetScore: current.gourmetScore +
              (isFood ? 3 : 0) +
              bonusFor(PoiTendency.gourmet),
          affectionScore: current.affectionScore +
              bonusFor(PoiTendency.affectionate) +
              petFriendlyBonus,
          eleganceScore: current.eleganceScore + bonusFor(PoiTendency.elegant),
          updatedAt: now,
          memories: _withMemory(
            current.memories,
            PetMemory(
              id: 'checkin-${poi.id}-${now.microsecondsSinceEpoch}',
              title:
                  firstVisit ? '${poi.title}에 처음 간 날' : '${poi.title}에 다시 간 날',
              detail: _checkInMemoryDetail(poi),
              createdAt: now,
              category: poi.category,
            ),
          ),
        ),
        now);
  }

  PetCareState _markBonded(PetCareState care, DateTime now) {
    final bondedToday =
        care.lastBondedDay != null && isSameLocalDay(care.lastBondedDay!, now);
    return care.copyWith(
      bondedDays: care.bondedDays + (bondedToday ? 0 : 1),
      lastBondedDay: now,
    );
  }

  /// 관광공사 상세 정보가 있으면 수첩에 실제 내용을 남긴다.
  String _checkInMemoryDetail(Poi poi) {
    final menu = poi.signatureMenu?.trim();
    if (menu != null && menu.isNotEmpty) {
      return '$menu 냄새를 맡고 수첩에 적어 뒀어요.';
    }
    if (poi.isPetFriendly) {
      return '함께 들어갈 수 있는 곳이라 더 오래 머물렀어요.';
    }
    final address = poi.address?.trim();
    if (address != null && address.isNotEmpty) {
      return '$address의 풍경을 수첩에 남겼어요.';
    }
    return '${poi.category.label} 장소의 냄새와 풍경을 수첩에 남겼어요.';
  }

  List<PetMemory> _withMemory(
    List<PetMemory> current,
    PetMemory memory,
  ) {
    return [memory, ...current].take(24).toList(growable: false);
  }

  int _stableIndex(String value, int length) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7FFFFFFF;
    }
    return hash % length;
  }

  String localDayKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class StaticDialogueService {
  const StaticDialogueService();

  DialogueLine lineFor({
    required PetTemplate template,
    required PoiCategory? lastCategory,
    int variantSeed = 0,
  }) {
    final trigger = lastCategory?.name ?? 'default';
    return lineForTrigger(
      template: template,
      trigger: trigger,
      variantSeed: variantSeed,
    );
  }

  DialogueLine lineForConversation({
    required PetTemplate template,
    required Pet pet,
    required PetCareState care,
    required PoiCategory? lastCategory,
    required DateTime now,
    required int interactionIndex,
  }) {
    final needTrigger = _careNeedTrigger(care, threshold: 45);
    if (needTrigger != null) {
      return lineForTrigger(
        template: template,
        trigger: needTrigger,
        variantSeed: interactionIndex,
      );
    }

    final timeTrigger = _timeTrigger(now);
    final visitTrigger = lastCategory?.name;
    final cycle = interactionIndex % 5;
    final trigger = switch (cycle) {
      0 => visitTrigger ?? 'default',
      1 => timeTrigger,
      2 => 'default',
      3 => pet.stats.affinity >= 60 ? 'close' : visitTrigger ?? 'default',
      _ => pet.stage == PetStage.evolved ? 'evolved' : timeTrigger,
    };

    return lineForTrigger(
      template: template,
      trigger: trigger,
      variantSeed: now.day + interactionIndex,
    );
  }

  DialogueLine lineForAmbient({
    required PetTemplate template,
    required PetCareState? care,
    required DateTime now,
    int variantSeed = 0,
  }) {
    final needTrigger = care == null
        ? null
        : _careNeedTrigger(
            care,
            threshold: 55,
          );
    return lineForTrigger(
      template: template,
      trigger: needTrigger ?? _timeTrigger(now),
      variantSeed: now.day + variantSeed,
    );
  }

  DialogueLine lineForAction({
    required PetTemplate template,
    required String trigger,
    int variantSeed = 0,
  }) {
    return lineForTrigger(
      template: template,
      trigger: trigger,
      variantSeed: variantSeed,
    );
  }

  DialogueLine lineForTrigger({
    required PetTemplate template,
    required String trigger,
    int variantSeed = 0,
  }) {
    final matching = starterDialogueSeed
        .where(
          (line) => line.templateId == template.id && line.trigger == trigger,
        )
        .toList(growable: false);
    final fallback = matching.isNotEmpty
        ? matching
        : starterDialogueSeed
            .where(
              (line) =>
                  line.templateId == template.id && line.trigger == 'default',
            )
            .toList(growable: false);
    if (fallback.isEmpty) {
      throw StateError('${template.id} 캐릭터의 기본 대사가 없어요.');
    }
    final normalizedSeed = variantSeed < 0 ? -variantSeed : variantSeed;
    return fallback[normalizedSeed % fallback.length];
  }

  bool isDialogueText({
    required String templateId,
    required String text,
  }) {
    return starterDialogueSeed.any(
      (line) => line.templateId == templateId && line.text == text,
    );
  }

  String? _careNeedTrigger(PetCareState care, {required int threshold}) {
    final minimum = math.min(
      care.satiety,
      math.min(care.cleanliness, care.vitality),
    );
    if (minimum >= threshold) {
      return null;
    }
    if (minimum == care.satiety) {
      return 'hungry';
    }
    if (minimum == care.cleanliness) {
      return 'dirty';
    }
    return 'tired';
  }

  String _timeTrigger(DateTime now) {
    if (now.hour < 11) {
      return 'morning';
    }
    if (now.hour < 18) {
      return 'afternoon';
    }
    return 'evening';
  }
}

class StepTrackingUnavailableException implements Exception {
  const StepTrackingUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DeviceStepService {
  const DeviceStepService();

  bool get isSupported {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// iOS에서 첫 걸음 이벤트를 기다려 실제 접근 가능 여부를 확인하는 시간.
  static const motionProbeTimeout = Duration(seconds: 5);

  Future<Stream<int>> openStepCountStream() async {
    if (!isSupported) {
      throw const StepTrackingUnavailableException(
        '이 기기에서는 자동 걸음 측정을 지원하지 않아요.',
      );
    }

    // Permission.activityRecognition은 Android 10+ 전용이다. iOS에서는 항상
    // granted로 떨어지므로, 권한 여부를 센서 응답으로 직접 확인한다.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final permission = await Permission.activityRecognition.request();
      if (!permission.isGranted) {
        throw const StepTrackingUnavailableException(
          '걸음 수를 연결하려면 동작 및 피트니스 권한이 필요해요.',
        );
      }
    }

    final stream = Pedometer.stepCountStream.map((event) => event.steps);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await stream.first.timeout(motionProbeTimeout);
      } on TimeoutException {
        // 아직 걸음 이벤트가 없을 뿐 접근은 허용된 상태라 그대로 진행한다.
      } on Object {
        throw const StepTrackingUnavailableException(
          '걸음 수를 연결하려면 동작 및 피트니스 권한이 필요해요.',
        );
      }
    }
    return stream;
  }
}

class LocationUnavailableException implements Exception {
  const LocationUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DeviceLocationService {
  const DeviceLocationService();

  Future<Coordinates> readCurrentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationUnavailableException('위치 서비스가 꺼져 있어요.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationUnavailableException('위치 권한이 거부됐어요.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationUnavailableException('앱 설정에서 위치 권한을 허용해야 해요.');
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      throw const LocationUnavailableException('위치를 가져오지 못했어요.');
    }
    return Coordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}

bool isSameLocalDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
