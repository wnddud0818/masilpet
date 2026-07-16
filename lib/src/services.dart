import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

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

  PetCareState resolve(PetCareState care, DateTime now) {
    final elapsed = now.difference(care.updatedAt);
    final elapsedMinutes = elapsed.isNegative
        ? 0
        : math.min(elapsed.inMinutes, maxDecayDuration.inMinutes);
    final sameCountDay = isSameLocalDay(care.dailyCountDay, now);
    final resolvedAt = now.isBefore(care.updatedAt) ? care.updatedAt : now;

    return care.copyWith(
      satiety:
          care.satiety - (elapsedMinutes ~/ satietyDecayInterval.inMinutes),
      cleanliness: care.cleanliness -
          (elapsedMinutes ~/ cleanlinessDecayInterval.inMinutes),
      vitality:
          care.vitality - (elapsedMinutes ~/ vitalityDecayInterval.inMinutes),
      updatedAt: resolvedAt,
      dailyCountDay: sameCountDay ? care.dailyCountDay : now,
      feedCountToday: sameCountDay ? care.feedCountToday : 0,
      playCountToday: sameCountDay ? care.playCountToday : 0,
      cleanCountToday: sameCountDay ? care.cleanCountToday : 0,
    );
  }

  PetCareState afterFeed(PetCareState care, DateTime now) {
    final current = resolve(care, now);
    return current.copyWith(
      satiety: current.satiety + 28,
      vitality: current.vitality + 3,
      updatedAt: now,
      dailyCountDay: now,
      feedCountToday: current.feedCountToday + 1,
    );
  }

  PetCareState afterPlay(PetCareState care, DateTime now) {
    final current = resolve(care, now);
    return current.copyWith(
      satiety: current.satiety - 2,
      cleanliness: current.cleanliness - 3,
      vitality: current.vitality + 18,
      updatedAt: now,
      dailyCountDay: now,
      playCountToday: current.playCountToday + 1,
    );
  }

  PetCareState afterClean(PetCareState care, DateTime now) {
    final current = resolve(care, now);
    return current.copyWith(
      cleanliness: current.cleanliness + 32,
      vitality: current.vitality + 2,
      updatedAt: now,
      dailyCountDay: now,
      cleanCountToday: current.cleanCountToday + 1,
    );
  }

  PetCareState afterSleep(PetCareState care, DateTime now) {
    final current = resolve(care, now);
    return current.copyWith(
      satiety: current.satiety - 1,
      vitality: current.vitality + 34,
      updatedAt: now,
    );
  }

  PetCareState afterTalk(PetCareState care, DateTime now) {
    final current = resolve(care, now);
    return current.copyWith(
      vitality: current.vitality + 6,
      updatedAt: now,
    );
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
      throw StateError('${template.id} 캐릭터의 기본 대사가 없습니다.');
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
      throw const LocationUnavailableException('위치 서비스가 꺼져 있습니다.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationUnavailableException('위치 권한이 거부되었습니다.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationUnavailableException('앱 설정에서 위치 권한을 허용해야 합니다.');
    }

    final position = await Geolocator.getCurrentPosition();
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
