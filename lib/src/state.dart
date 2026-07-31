import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/local_progress_repository.dart';
import 'data/masilpet_backend.dart';
import 'data/firestore_user_repository.dart';
import 'models.dart';
import 'seed_data.dart';
import 'services.dart';

final firebaseReadyProvider = Provider<bool>((ref) => false);

final firebaseStartupIssueProvider =
    Provider<FirebaseStartupIssue>((ref) => FirebaseStartupIssue.none);

const locationVerificationTtl = Duration(minutes: 15);

final masilPetControllerProvider =
    StateNotifierProvider<MasilPetController, MasilPetState>((ref) {
  return MasilPetController(
    firebaseReady: ref.watch(firebaseReadyProvider),
    firebaseStartupIssue: ref.watch(firebaseStartupIssueProvider),
    backend: ref.watch(firebaseReadyProvider) ? createMasilPetBackend() : null,
    userRepository:
        ref.watch(firebaseReadyProvider) ? FirestoreUserRepository() : null,
    localProgressRepository: const SharedPreferencesLocalProgressRepository(),
    locationService: const DeviceLocationService(),
  );
});

enum FirebaseStartupIssue {
  none,
  missingWebConfiguration,
  initializationFailed,
}

extension FirebaseStartupIssueLabel on FirebaseStartupIssue {
  String get fallbackMessage {
    return switch (this) {
      FirebaseStartupIssue.none => '온라인 연결 전이에요. 기기 내 진행으로 시작해요.',
      FirebaseStartupIssue.missingWebConfiguration =>
        'Firebase 앱 설정값이 없어 기기 내 진행으로 시작해요.',
      FirebaseStartupIssue.initializationFailed =>
        'Firebase 연결에 실패해 기기 내 진행으로 시작해요.',
    };
  }

  String get profileLabel {
    return switch (this) {
      FirebaseStartupIssue.none => '기기 내 진행',
      FirebaseStartupIssue.missingWebConfiguration => '기기 내 진행 (설정 필요)',
      FirebaseStartupIssue.initializationFailed => '기기 내 진행 (연결 실패)',
    };
  }
}

class MasilPetState {
  const MasilPetState({
    required this.firebaseReady,
    required this.firebaseStartupIssue,
    required this.onboardingComplete,
    required this.region,
    required this.pois,
    required this.templates,
    required this.pets,
    required this.eggs,
    required this.checkIns,
    this.careByPetId = const {},
    this.carePoints = 0,
    this.dailyCareRewardClaimKey,
    this.stepTrackingSupported = false,
    this.stepTrackingActive = false,
    this.deviceStepsWaiting = 0,
    required this.currentLocation,
    required this.locationVerified,
    required this.locationVerifiedAt,
    required this.activePetId,
    this.activeEggId = '',
    required this.selectedTab,
    required this.mapCategoryFocus,
    required this.statusMessage,
    required this.fieldActivity,
    required this.fieldActivityNonce,
    required this.lastVisitedCategory,
    required this.dialogueCountToday,
    required this.dialogueDay,
    required this.isBusy,
  });

  factory MasilPetState.initial({
    required bool firebaseReady,
    FirebaseStartupIssue firebaseStartupIssue = FirebaseStartupIssue.none,
  }) {
    final now = DateTime.now();
    final starterTemplate = starterCompanionTemplate();
    return MasilPetState(
      firebaseReady: firebaseReady,
      firebaseStartupIssue: firebaseStartupIssue,
      onboardingComplete: false,
      region: koreaRegion,
      pois: starterPoiSeed,
      templates: starterPetTemplates,
      pets: [
        Pet(
          id: starterCompanionPetId,
          templateId: starterTemplate.id,
          name: starterTemplate.name,
          stage: PetStage.baby,
          level: 1,
          stats:
              const GrowthStats(exp: 20, mood: 20, knowledge: 5, affinity: 8),
          originRegionId: starterTemplate.regionId,
          hatchedAt: now,
          lastInteractedAt: null,
        ),
      ],
      eggs: [
        Egg(
          id: 'egg-harbor-maru',
          templateId: 'harbor-maru',
          originRegionId: starterTemplate.regionId,
          progress: 1200,
          requiredSteps: 3500,
          status: EggStatus.incubating,
          createdAt: now,
        ),
      ],
      checkIns: const [],
      careByPetId: {
        starterCompanionPetId: PetCareState.initial(now),
      },
      carePoints: 0,
      dailyCareRewardClaimKey: null,
      currentLocation: starterPoiSeed.first.coordinates,
      locationVerified: false,
      locationVerifiedAt: null,
      activePetId: starterCompanionPetId,
      activeEggId: 'egg-harbor-maru',
      selectedTab: 1,
      mapCategoryFocus: null,
      statusMessage: firebaseReady
          ? 'Firebase 연결 준비 완료'
          : firebaseStartupIssue.fallbackMessage,
      fieldActivity: PetFieldActivity.idle,
      fieldActivityNonce: 0,
      lastVisitedCategory: null,
      dialogueCountToday: 0,
      dialogueDay: now,
      isBusy: false,
    );
  }

  final bool firebaseReady;
  final FirebaseStartupIssue firebaseStartupIssue;
  final bool onboardingComplete;
  final Region region;
  final List<Poi> pois;
  final List<PetTemplate> templates;
  final List<Pet> pets;
  final List<Egg> eggs;
  final List<CheckIn> checkIns;
  final Map<String, PetCareState> careByPetId;
  final int carePoints;
  final String? dailyCareRewardClaimKey;
  final bool stepTrackingSupported;
  final bool stepTrackingActive;
  final int deviceStepsWaiting;
  final Coordinates currentLocation;
  final bool locationVerified;
  final DateTime? locationVerifiedAt;
  final String activePetId;
  final String activeEggId;
  final int selectedTab;
  final PoiCategory? mapCategoryFocus;
  final String statusMessage;
  final PetFieldActivity fieldActivity;
  final int fieldActivityNonce;
  final PoiCategory? lastVisitedCategory;
  final int dialogueCountToday;
  final DateTime dialogueDay;
  final bool isBusy;

  Pet? get activePet {
    for (final pet in pets) {
      if (pet.id == activePetId) {
        return pet;
      }
    }
    return pets.isEmpty ? null : pets.first;
  }

  /// 걸음과 체크인은 부화 중인 알에만 쌓인다. 이미 부화 준비를 마친 알이
  /// 골라져 있으면 그동안의 진행도가 통째로 버려지므로, 아직 품고 있는 알을
  /// 먼저 고른다. 정렬 기준은 Functions의 `selectActiveEgg`와 동일하게 맞춰
  /// 서버와 앱이 같은 알을 가리키도록 한다.
  static Egg? selectActiveEgg(List<Egg> eggs, String preferredId) {
    Egg? pick(EggStatus status) {
      final candidates =
          eggs.where((egg) => egg.status == status).toList(growable: false);
      if (candidates.isEmpty) {
        return null;
      }
      final preferred =
          candidates.where((egg) => egg.id == preferredId).firstOrNull;
      if (preferred != null) {
        return preferred;
      }
      candidates.sort((left, right) {
        final leftRemaining = math.max(0, left.requiredSteps - left.progress);
        final rightRemaining =
            math.max(0, right.requiredSteps - right.progress);
        if (leftRemaining != rightRemaining) {
          return leftRemaining.compareTo(rightRemaining);
        }
        return left.id.compareTo(right.id);
      });
      return candidates.first;
    }

    return pick(EggStatus.incubating) ?? pick(EggStatus.hatchable);
  }

  Egg? get activeEgg => selectActiveEgg(eggs, activeEggId) ?? nextEgg;

  Egg? get activeIncubatingEgg {
    final selected = activeEgg;
    return selected?.status == EggStatus.incubating ? selected : null;
  }

  PetCareState? careForPet(String petId, {DateTime? now}) {
    final pet = pets.where((pet) => pet.id == petId).firstOrNull;
    if (pet == null) {
      return null;
    }

    final resolvedAt = now ?? DateTime.now();
    final stored = careByPetId[petId] ?? PetCareState.initial(resolvedAt);
    final age = resolvedAt.difference(pet.hatchedAt);
    final inNewbornGrace = !age.isNegative && age < const Duration(hours: 24);
    return const CareEngine().resolve(
      stored,
      resolvedAt,
      stayingHome: petId != activePetId || inNewbornGrace,
    );
  }

  PetCareState? get activePetCare {
    final pet = activePet;
    return pet == null ? null : careForPet(pet.id);
  }

  DailyCareRoutineProgress dailyCareRoutineAt(DateTime now) {
    var fed = false;
    var played = false;
    var cleaned = false;
    const careEngine = CareEngine();

    for (final pet in pets) {
      final stored = careByPetId[pet.id];
      if (stored == null) {
        continue;
      }
      final care = careEngine.resolve(stored, now);
      fed = fed || care.feedCountToday > 0;
      played = played || care.playCountToday > 0;
      cleaned = cleaned || care.cleanCountToday > 0;
    }

    return DailyCareRoutineProgress(
      fed: fed,
      played: played,
      cleaned: cleaned,
      talked: isSameLocalDay(dialogueDay, now) && dialogueCountToday > 0,
      checkedIn:
          checkIns.any((checkIn) => isSameLocalDay(checkIn.createdAt, now)),
    );
  }

  DailyCareRoutineProgress dailyCareRoutineForPet(
    String petId, {
    DateTime? now,
  }) {
    final resolvedAt = now ?? DateTime.now();
    final care = careForPet(petId, now: resolvedAt);
    final checkedIn = checkIns.any(
      (checkIn) =>
          checkIn.companionPetId == petId &&
          isSameLocalDay(checkIn.createdAt, resolvedAt),
    );
    return DailyCareRoutineProgress(
      fed: care != null && care.feedCountToday > 0,
      played: care != null && care.playCountToday > 0,
      cleaned: care != null && care.cleanCountToday > 0,
      talked: care != null && care.talkCountToday > 0,
      checkedIn: checkedIn,
    );
  }

  DailyCareRoutineProgress get dailyCareRoutine {
    final pet = activePet;
    return pet == null
        ? const DailyCareRoutineProgress(
            fed: false,
            played: false,
            cleaned: false,
            talked: false,
            checkedIn: false,
          )
        : dailyCareRoutineForPet(pet.id);
  }

  int get dailyCareCompletedCount => dailyCareRoutine.completedCount;

  int get dailyCareTargetCount => dailyCareRoutine.targetCount;

  bool get isDailyCareRoutineComplete => dailyCareRoutine.isComplete;

  String get dailyCareRewardClaimKeyForToday {
    return const CareEngine().localDayKey(DateTime.now());
  }

  bool get hasClaimedDailyCareRewardToday {
    return dailyCareRewardClaimKey == dailyCareRewardClaimKeyForToday;
  }

  bool get canClaimDailyCareReward {
    return isDailyCareRoutineComplete && !hasClaimedDailyCareRewardToday;
  }

  List<Poi> get nearbyPois {
    final sorted = [...pois];
    sorted.sort(
      (left, right) => currentLocation
          .distanceTo(left.coordinates)
          .compareTo(currentLocation.distanceTo(right.coordinates)),
    );
    return sorted;
  }

  List<CheckIn> get todayCheckIns {
    final now = DateTime.now();
    return checkIns
        .where((checkIn) => isSameLocalDay(checkIn.createdAt, now))
        .toList(growable: false);
  }

  List<CheckIn> get recentCheckIns {
    final sorted = [...checkIns];
    sorted.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return sorted;
  }

  int get todayCheckInCount => todayCheckIns.length;

  int get currentVisitStreakDays {
    final visitedDays = _visitedLocalDaySet();
    if (visitedDays.isEmpty) {
      return 0;
    }

    final today = _localDayStamp(DateTime.now());
    var cursor = visitedDays.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    if (!visitedDays.contains(cursor)) {
      return 0;
    }

    var streak = 0;
    while (visitedDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int get longestVisitStreakDays {
    final visitedDays = _visitedLocalDaySet().toList()
      ..sort((left, right) => left.compareTo(right));
    if (visitedDays.isEmpty) {
      return 0;
    }

    var longest = 1;
    var current = 1;
    for (var index = 1; index < visitedDays.length; index++) {
      final gap = visitedDays[index].difference(visitedDays[index - 1]).inDays;
      if (gap == 1) {
        current++;
      } else {
        current = 1;
      }
      if (current > longest) {
        longest = current;
      }
    }
    return longest;
  }

  int get remainingDailyCheckIns {
    return (dailyCheckInLimit - todayCheckInCount)
        .clamp(0, dailyCheckInLimit)
        .toInt();
  }

  Set<PoiCategory> get todayVisitedCategories {
    return todayCheckIns.map((checkIn) => checkIn.category).toSet();
  }

  int get todayVisitedCategoryCount => todayVisitedCategories.length;

  int get unvisitedPoiCountToday {
    return pois.where((poi) => !hasCheckedInToday(poi)).length;
  }

  Set<String> get discoveredTemplateIds {
    return pets.map((pet) => pet.templateId).toSet();
  }

  Set<PoiCategory> get undiscoveredCategoryGoals {
    return templates
        .where((template) => !discoveredTemplateIds.contains(template.id))
        .map((template) => template.primaryCategory)
        .toSet();
  }

  double get dexCompletionRatio {
    if (templates.isEmpty) {
      return 0;
    }
    return (discoveredTemplateIds.length / templates.length)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  int get hatchableEggCount {
    return eggs.where((egg) => egg.status == EggStatus.hatchable).length;
  }

  Egg? get nextEgg {
    if (eggs.isEmpty) {
      return null;
    }

    final sorted = [...eggs];
    sorted.sort((left, right) {
      final leftPriority = _eggPriority(left);
      final rightPriority = _eggPriority(right);
      if (leftPriority != rightPriority) {
        return leftPriority.compareTo(rightPriority);
      }

      final leftRemaining =
          (left.requiredSteps - left.progress).clamp(0, left.requiredSteps);
      final rightRemaining =
          (right.requiredSteps - right.progress).clamp(0, right.requiredSteps);
      return leftRemaining.compareTo(rightRemaining);
    });
    return sorted.first;
  }

  int get todayAvailableCheckInCount {
    return nearbyPois.where(canCheckInToday).length;
  }

  Poi? get nearestPoi {
    final sorted = nearbyPois;
    return sorted.isEmpty ? null : sorted.first;
  }

  Poi? get nextRecommendedPoi {
    final route = recommendedRoutePois;
    return route.isEmpty ? null : route.first;
  }

  List<Poi> get recommendedRoutePois {
    final candidates =
        nearbyPois.where((poi) => !hasCheckedInToday(poi)).toList();
    if (candidates.isEmpty) {
      return nearbyPois.take(3).toList(growable: false);
    }

    final categoryGoals = undiscoveredCategoryGoals;
    final visitedCategories = todayVisitedCategories;
    candidates.sort(
      (left, right) => _comparePoiRecommendations(
        left: left,
        right: right,
        categoryGoals: categoryGoals,
        visitedCategories: visitedCategories,
      ),
    );
    return candidates.take(3).toList(growable: false);
  }

  bool get hasFreshVerifiedLocation {
    final verifiedAt = locationVerifiedAt;
    if (!locationVerified || verifiedAt == null) {
      return false;
    }

    final now = DateTime.now();
    if (verifiedAt.isAfter(now.add(const Duration(minutes: 1)))) {
      return false;
    }
    return now.difference(verifiedAt) <= locationVerificationTtl;
  }

  int get launchReadinessScore {
    var score = 0;
    if (firebaseReady) {
      score += 25;
    }
    if (todayCheckInCount > 0) {
      score += 25;
    }
    if (pets.isNotEmpty) {
      score += 25;
    }
    if (eggs.isNotEmpty || pets.length > 1) {
      score += 25;
    }
    return score;
  }

  bool hasCheckedInToday(Poi poi) {
    return todayCheckIns.any((checkIn) => checkIn.poiId == poi.id);
  }

  Set<DateTime> _visitedLocalDaySet() {
    return checkIns.map((checkIn) => _localDayStamp(checkIn.createdAt)).toSet();
  }

  bool canCheckInToday(Poi poi) {
    return hasFreshVerifiedLocation &&
        remainingDailyCheckIns > 0 &&
        currentLocation.distanceTo(poi.coordinates) <= checkInRadiusMeters &&
        !hasCheckedInToday(poi);
  }

  String get firebaseConnectionLabel {
    return firebaseReady ? '온라인 동기화' : firebaseStartupIssue.profileLabel;
  }

  int _eggPriority(Egg egg) {
    return switch (egg.status) {
      EggStatus.hatchable => 0,
      EggStatus.incubating => 1,
      EggStatus.hatched => 2,
    };
  }

  double _poiRecommendationScore(
    Poi poi, {
    required Set<PoiCategory> categoryGoals,
    required Set<PoiCategory> visitedCategories,
  }) {
    var score = currentLocation.distanceTo(poi.coordinates);
    if (hasFreshVerifiedLocation && score <= checkInRadiusMeters) {
      score -= 10000;
    }
    if (categoryGoals.contains(poi.category)) {
      score -= 2200;
    }
    if (!visitedCategories.contains(poi.category)) {
      score -= 900;
    }
    return score;
  }

  int _comparePoiRecommendations({
    required Poi left,
    required Poi right,
    required Set<PoiCategory> categoryGoals,
    required Set<PoiCategory> visitedCategories,
  }) {
    final leftScore = _poiRecommendationScore(
      left,
      categoryGoals: categoryGoals,
      visitedCategories: visitedCategories,
    );
    final rightScore = _poiRecommendationScore(
      right,
      categoryGoals: categoryGoals,
      visitedCategories: visitedCategories,
    );
    final scoreComparison = leftScore.compareTo(rightScore);
    if (scoreComparison != 0) {
      return scoreComparison;
    }

    final distanceComparison = currentLocation
        .distanceTo(left.coordinates)
        .compareTo(currentLocation.distanceTo(right.coordinates));
    if (distanceComparison != 0) {
      return distanceComparison;
    }

    return left.title.compareTo(right.title);
  }

  MasilPetState copyWith({
    bool? firebaseReady,
    FirebaseStartupIssue? firebaseStartupIssue,
    bool? onboardingComplete,
    Region? region,
    List<Poi>? pois,
    List<PetTemplate>? templates,
    List<Pet>? pets,
    List<Egg>? eggs,
    List<CheckIn>? checkIns,
    Map<String, PetCareState>? careByPetId,
    int? carePoints,
    String? dailyCareRewardClaimKey,
    bool clearDailyCareRewardClaimKey = false,
    bool? stepTrackingSupported,
    bool? stepTrackingActive,
    int? deviceStepsWaiting,
    Coordinates? currentLocation,
    bool? locationVerified,
    DateTime? locationVerifiedAt,
    bool clearLocationVerifiedAt = false,
    String? activePetId,
    String? activeEggId,
    int? selectedTab,
    PoiCategory? mapCategoryFocus,
    bool clearMapCategoryFocus = false,
    String? statusMessage,
    PetFieldActivity? fieldActivity,
    bool bumpFieldActivity = false,
    PoiCategory? lastVisitedCategory,
    bool clearLastVisitedCategory = false,
    int? dialogueCountToday,
    DateTime? dialogueDay,
    bool? isBusy,
  }) {
    return MasilPetState(
      firebaseReady: firebaseReady ?? this.firebaseReady,
      firebaseStartupIssue: firebaseStartupIssue ?? this.firebaseStartupIssue,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      region: region ?? this.region,
      pois: pois ?? this.pois,
      templates: templates ?? this.templates,
      pets: pets ?? this.pets,
      eggs: eggs ?? this.eggs,
      checkIns: checkIns ?? this.checkIns,
      careByPetId: careByPetId ?? this.careByPetId,
      carePoints: carePoints ?? this.carePoints,
      dailyCareRewardClaimKey: clearDailyCareRewardClaimKey
          ? null
          : dailyCareRewardClaimKey ?? this.dailyCareRewardClaimKey,
      stepTrackingSupported:
          stepTrackingSupported ?? this.stepTrackingSupported,
      stepTrackingActive: stepTrackingActive ?? this.stepTrackingActive,
      deviceStepsWaiting: deviceStepsWaiting ?? this.deviceStepsWaiting,
      currentLocation: currentLocation ?? this.currentLocation,
      locationVerified: locationVerified ?? this.locationVerified,
      locationVerifiedAt: clearLocationVerifiedAt
          ? null
          : locationVerifiedAt ?? this.locationVerifiedAt,
      activePetId: activePetId ?? this.activePetId,
      activeEggId: activeEggId ?? this.activeEggId,
      selectedTab: selectedTab ?? this.selectedTab,
      mapCategoryFocus: clearMapCategoryFocus
          ? null
          : mapCategoryFocus ?? this.mapCategoryFocus,
      statusMessage: statusMessage ?? this.statusMessage,
      fieldActivity: fieldActivity ?? this.fieldActivity,
      fieldActivityNonce:
          bumpFieldActivity ? fieldActivityNonce + 1 : fieldActivityNonce,
      lastVisitedCategory: clearLastVisitedCategory
          ? null
          : lastVisitedCategory ?? this.lastVisitedCategory,
      dialogueCountToday: dialogueCountToday ?? this.dialogueCountToday,
      dialogueDay: dialogueDay ?? this.dialogueDay,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

DateTime _localDayStamp(DateTime value) {
  return DateTime.utc(value.year, value.month, value.day);
}

String _koreanDayKey(DateTime value) {
  final korean = value.toUtc().add(const Duration(hours: 9));
  return '${korean.year.toString().padLeft(4, '0')}-'
      '${korean.month.toString().padLeft(2, '0')}-'
      '${korean.day.toString().padLeft(2, '0')}';
}

class MasilPetController extends StateNotifier<MasilPetState> {
  MasilPetController({
    required bool firebaseReady,
    FirebaseStartupIssue firebaseStartupIssue = FirebaseStartupIssue.none,
    required DeviceLocationService locationService,
    required MasilPetBackend? backend,
    required FirestoreUserRepository? userRepository,
    LocalProgressRepository? localProgressRepository,
    DeviceStepService stepService = const DeviceStepService(),
  })  : _locationService = locationService,
        _backend = backend,
        _userRepository = userRepository,
        _localProgressRepository = localProgressRepository,
        _stepService = stepService,
        super(MasilPetState.initial(
          firebaseReady: firebaseReady,
          firebaseStartupIssue: firebaseStartupIssue,
        )) {
    state = state.copyWith(stepTrackingSupported: _stepService.isSupported);
    _attachLifecycleListener();
    Future.microtask(() async {
      await _safeBootstrapLocalSession();
      if (firebaseReady) {
        await _bootstrapOnlineSession();
      }
      await _resumeStepTrackingIfEnabled();
    });
  }

  void _attachLifecycleListener() {
    try {
      _lifecycleListener = AppLifecycleListener(onPause: _handleAppPaused);
    } on Object {
      // 위젯 바인딩이 없는 환경(순수 단위 테스트 등)에서는 생명주기 훅 없이 동작한다.
      _lifecycleListener = null;
    }
  }

  final DeviceLocationService _locationService;
  final MasilPetBackend? _backend;
  final FirestoreUserRepository? _userRepository;
  final LocalProgressRepository? _localProgressRepository;
  final DeviceStepService _stepService;
  final GrowthEngine _growthEngine = const GrowthEngine();
  final CareEngine _careEngine = const CareEngine();
  final StaticDialogueService _dialogueService = const StaticDialogueService();
  StreamSubscription<int>? _stepSubscription;
  int? _lastDeviceStepCount;
  bool _isFlushingDeviceSteps = false;
  bool _needsStepBaseline = false;
  String _stepSyncDeviceId = '';
  String? _pendingStepOperationId;
  String? _pendingStepDayKey;
  int? _pendingStepObservedTotal;
  int? _pendingStepWaiting;
  DateTime? _pendingStepObservedAt;
  bool _shouldResumeStepTracking = false;
  AppLifecycleListener? _lifecycleListener;

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    unawaited(_stepSubscription?.cancel());
    super.dispose();
  }

  Future<void> _safeBootstrapLocalSession() async {
    try {
      await _bootstrapLocalSession();
    } on Object {
      state = state.copyWith(
        statusMessage: state.firebaseReady
            ? '저장된 진행도를 불러오지 못했어요. 온라인 동기화를 준비할게요.'
            : '저장된 진행도를 불러오지 못했어요. 새 진행으로 시작할게요.',
      );
    }
  }

  Future<void> _bootstrapLocalSession() async {
    final repository = _localProgressRepository;
    if (repository == null) {
      return;
    }

    final snapshot = await repository.loadProgress();
    if (snapshot == null) {
      return;
    }
    _stepSyncDeviceId = snapshot.stepSyncDeviceId;

    final now = DateTime.now();
    final dialogueCountToday = isSameLocalDay(snapshot.dialogueDay, now)
        ? snapshot.dialogueCountToday
        : 0;
    final restoredPets = _withCanonicalPetNames(
      snapshot.pets.isEmpty ? state.pets : snapshot.pets,
    );
    final restoredCareByPetId = _careForPets(
      pets: restoredPets,
      existing: snapshot.careByPetId,
      now: now,
    );

    state = state.copyWith(
      onboardingComplete: snapshot.onboardingComplete,
      pois: snapshot.pois.isEmpty ? state.pois : snapshot.pois,
      pets: restoredPets,
      eggs: snapshot.eggs,
      checkIns: snapshot.checkIns,
      careByPetId: restoredCareByPetId,
      carePoints: snapshot.carePoints,
      dailyCareRewardClaimKey: snapshot.dailyCareRewardClaimKey,
      clearDailyCareRewardClaimKey: snapshot.dailyCareRewardClaimKey == null,
      currentLocation: snapshot.currentLocation,
      locationVerified: snapshot.locationVerified,
      locationVerifiedAt: snapshot.locationVerifiedAt,
      activePetId: snapshot.activePetId.isEmpty
          ? state.activePetId
          : snapshot.activePetId,
      activeEggId: _validActiveEggId(
        snapshot.activeEggId,
        snapshot.eggs,
      ),
      lastVisitedCategory: snapshot.lastVisitedCategory,
      clearLastVisitedCategory: snapshot.lastVisitedCategory == null,
      dialogueCountToday: dialogueCountToday,
      dialogueDay: dialogueCountToday == 0 ? now : snapshot.dialogueDay,
      // 앱이 꺼져도 아직 서버에 못 보낸 걸음은 그대로 들고 있어야 한다.
      deviceStepsWaiting: snapshot.deviceStepsWaiting,
      statusMessage: state.firebaseReady
          ? '저장된 진행도를 불러왔어요. 온라인 동기화를 준비할게요.'
          : '저장된 진행도를 불러왔어요.',
    );
    _shouldResumeStepTracking = snapshot.stepTrackingActive;
  }

  /// 지난 실행에서 걸음 연결을 켜 둔 사용자라면 조용히 다시 이어 붙인다.
  /// 이미 허용된 권한은 프롬프트 없이 통과하므로 사용자를 방해하지 않는다.
  Future<void> _resumeStepTrackingIfEnabled() async {
    if (!_shouldResumeStepTracking || !_stepService.isSupported) {
      return;
    }
    _shouldResumeStepTracking = false;
    final previousMessage = state.statusMessage;
    try {
      await startStepTracking();
    } on Object {
      // 자동 재연결 실패는 조용히 넘긴다. 사용자가 직접 다시 켤 수 있다.
    }
    if (!state.stepTrackingActive) {
      state = state.copyWith(isBusy: false, statusMessage: previousMessage);
    }
  }

  /// 앱이 백그라운드로 갈 때 모아 둔 걸음을 마지막으로 한 번 보낸다.
  void _handleAppPaused() {
    unawaited(flushDeviceSteps());
    _persistLocalProgress();
  }

  void _persistLocalProgress() {
    unawaited(_saveLocalProgress());
  }

  Future<bool> _saveLocalProgress() async {
    final repository = _localProgressRepository;
    if (repository == null) {
      return true;
    }

    try {
      await repository.saveProgress(_snapshotFromState());
      return true;
    } on Object {
      // Local persistence must not interrupt play.
      return false;
    }
  }

  LocalProgressSnapshot _snapshotFromState() {
    return LocalProgressSnapshot(
      onboardingComplete: state.onboardingComplete,
      pois: state.pois,
      pets: state.pets,
      eggs: state.eggs,
      checkIns: state.checkIns,
      careByPetId: state.careByPetId,
      carePoints: state.carePoints,
      dailyCareRewardClaimKey: state.dailyCareRewardClaimKey,
      currentLocation: state.currentLocation,
      locationVerified: state.locationVerified,
      locationVerifiedAt: state.locationVerifiedAt,
      activePetId: state.activePetId,
      activeEggId: state.activeEggId,
      lastVisitedCategory: state.lastVisitedCategory,
      dialogueCountToday: state.dialogueCountToday,
      dialogueDay: state.dialogueDay,
      stepSyncDeviceId: _ensureStepSyncDeviceId(),
      deviceStepsWaiting: state.deviceStepsWaiting,
      stepTrackingActive: state.stepTrackingActive,
    );
  }

  String _ensureStepSyncDeviceId() {
    if (_stepSyncDeviceId.isNotEmpty) {
      return _stepSyncDeviceId;
    }
    final now = DateTime.now().microsecondsSinceEpoch;
    final entropy = math.Random.secure().nextInt(0x7FFFFFFF);
    _stepSyncDeviceId = 'device-$now-$entropy';
    return _stepSyncDeviceId;
  }

  void _clearPendingStepSync() {
    _pendingStepOperationId = null;
    _pendingStepDayKey = null;
    _pendingStepObservedTotal = null;
    _pendingStepWaiting = null;
    _pendingStepObservedAt = null;
  }

  Future<void> _bootstrapOnlineSession() async {
    final backend = _backend;
    final repository = _userRepository;
    if (backend == null || repository == null) {
      return;
    }

    state = state.copyWith(
      isBusy: true,
      statusMessage: '계정과 진행도를 동기화하는 중이에요.',
    );

    try {
      await backend.ensureUserBootstrap();
      await refreshRemoteProgress(silent: true);
      state = state.copyWith(
        isBusy: false,
        statusMessage: '계정과 진행도를 동기화했어요.',
      );
    } on Object {
      state = state.copyWith(
        isBusy: false,
        statusMessage: '온라인 동기화에 실패했어요. 지금은 이 기기의 진행으로 계속할게요.',
      );
    }
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(
      onboardingComplete: true,
      selectedTab: 1,
      statusMessage: '마실펫 탐험을 시작해요.',
      fieldActivity: PetFieldActivity.walking,
      bumpFieldActivity: true,
    );
    final saved = await _saveLocalProgress();
    if (!saved) {
      state = state.copyWith(
        statusMessage: '기기 내 진행을 저장하지 못했어요. 지금 세션에서는 그대로 이용할 수 있어요.',
      );
    }
  }

  void setTab(int tab, {PoiCategory? mapCategoryFocus}) {
    state = state.copyWith(
      selectedTab: tab,
      mapCategoryFocus: mapCategoryFocus,
    );
  }

  void setMapCategoryFocus(PoiCategory? category) {
    state = state.copyWith(
      mapCategoryFocus: category,
      clearMapCategoryFocus: category == null,
    );
  }

  /// Changes the companion that walks with the user. The switch is applied
  /// locally first so the yard reacts at once, then sent to the server — without
  /// that call the next check-in would snap the companion back to whoever the
  /// server still thinks is active.
  Future<void> selectPet(String petId) async {
    final previousPetId = state.activePetId;
    if (petId == previousPetId) {
      return;
    }
    if (_petById(petId) == null) {
      state = state.copyWith(statusMessage: '함께 걸을 마실펫을 찾을 수 없어요.');
      return;
    }

    final backend = _backend;
    final selectedCare = state.careForPet(petId);
    state = state.copyWith(
      activePetId: petId,
      dialogueCountToday: selectedCare?.talkCountToday ?? 0,
      dialogueDay: DateTime.now(),
      isBusy: backend != null,
      statusMessage: '함께 걷는 마실펫을 바꿨어요.',
    );
    _persistLocalProgress();

    if (backend == null) {
      return;
    }

    try {
      await backend.setActivePet(petId);
      state = state.copyWith(isBusy: false);
    } on MasilPetBackendException catch (error) {
      _revertActivePet(previousPetId, _messageForRemoteActivePetFailure(error));
    } on Object {
      _revertActivePet(
        previousPetId,
        '서버에 동행 마실펫을 반영하지 못했어요. 잠시 후에 다시 시도해 주세요.',
      );
    }
  }

  void _revertActivePet(String previousPetId, String statusMessage) {
    state = state.copyWith(
      activePetId: previousPetId,
      isBusy: false,
      statusMessage: statusMessage,
    );
    _persistLocalProgress();
  }

  Future<void> selectEgg(String eggId) async {
    final egg = state.eggs.where((item) => item.id == eggId).firstOrNull;
    if (egg == null || egg.status != EggStatus.incubating) {
      state = state.copyWith(statusMessage: '품을 알을 찾을 수 없어요.');
      return;
    }
    if (state.activeEggId == eggId) {
      return;
    }

    final previousEggId = state.activeEggId;
    state = state.copyWith(
      activeEggId: eggId,
      isBusy: _backend != null,
      statusMessage: '${templateFor(egg.templateId).name}의 알을 품기 시작했어요.',
    );
    _persistLocalProgress();

    final backend = _backend;
    if (backend == null) {
      return;
    }
    try {
      await backend.setActiveEgg(eggId);
      state = state.copyWith(isBusy: false);
    } on MasilPetBackendException catch (error) {
      state = state.copyWith(
        activeEggId: previousEggId,
        isBusy: false,
        statusMessage: error.code == 'not-found'
            ? '서버에서 이 알을 찾을 수 없어요.'
            : '부화할 알을 바꾸지 못했어요. 잠시 후 다시 시도해 주세요.',
      );
      _persistLocalProgress();
    } on Object {
      state = state.copyWith(
        activeEggId: previousEggId,
        isBusy: false,
        statusMessage: '부화할 알을 바꾸지 못했어요. 잠시 후 다시 시도해 주세요.',
      );
      _persistLocalProgress();
    }
  }

  void useStarterKoreaLocation() {
    final enablesLocalCheckIn = _backend == null;
    final now = DateTime.now();

    state = state.copyWith(
      selectedTab: 0,
      currentLocation: starterPoiSeed.first.coordinates,
      locationVerified: enablesLocalCheckIn,
      locationVerifiedAt: enablesLocalCheckIn ? now : null,
      clearLocationVerifiedAt: !enablesLocalCheckIn,
      pois: starterPoiSeed,
      statusMessage: enablesLocalCheckIn
          ? '전국 기본 체험 위치로 옮겼어요. 추천 장소 체크인을 바로 할 수 있어요.'
          : '전국 기본 장소 지도로 옮겼어요. 체크인은 현재 위치를 확인한 뒤에 할 수 있어요.',
      fieldActivity: PetFieldActivity.walking,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
  }

  Future<void> useDeviceLocation() async {
    state = state.copyWith(
      selectedTab: 0,
      isBusy: true,
      statusMessage: '현재 위치를 확인하는 중이에요.',
      fieldActivity: PetFieldActivity.walking,
      bumpFieldActivity: true,
    );
    try {
      final now = DateTime.now();
      final location = await _locationService.readCurrentLocation();
      final remotePois = await _readRemotePois(location);
      state = state.copyWith(
        currentLocation: location,
        locationVerified: true,
        locationVerifiedAt: now,
        pois: remotePois.isEmpty ? state.pois : remotePois,
        isBusy: false,
        statusMessage:
            remotePois.isEmpty ? '현재 위치를 반영했어요.' : '현재 위치와 주변 장소를 반영했어요.',
        fieldActivity: PetFieldActivity.walking,
        bumpFieldActivity: true,
      );
      _persistLocalProgress();
    } on LocationUnavailableException catch (error) {
      state = state.copyWith(isBusy: false, statusMessage: error.message);
    } on Object {
      state = state.copyWith(isBusy: false, statusMessage: '위치를 가져오지 못했어요.');
    }
  }

  Future<List<Poi>> _readRemotePois(Coordinates location) async {
    final backend = _backend;
    if (backend == null) {
      return const [];
    }

    try {
      final remotePois = await backend.getNearbyPois(location);
      return remotePois.map(_poiFromRemote).toList();
    } on Object {
      return const [];
    }
  }

  Poi _poiFromRemote(RemotePoi remote) {
    return Poi(
      id: remote.id,
      tourApiContentId: remote.tourApiContentId,
      title: remote.title,
      regionId: remote.regionId,
      category: remote.category,
      coordinates: remote.coordinates,
      shortDescription: _remotePoiDescription(remote),
      tendency: remote.tendency,
      address: remote.address,
      imageUrl: remote.imageUrl,
      tel: remote.tel,
      openTime: remote.openTime,
      restDate: remote.restDate,
      signatureMenu: remote.signatureMenu,
      petFriendlyGuide: remote.petFriendlyGuide,
    );
  }

  /// 관광공사 데이터가 있으면 거리 안내 대신 실제 정보를 보여준다.
  String _remotePoiDescription(RemotePoi remote) {
    final distance = '현재 위치에서 ${remote.distanceMeters.round()}m';
    final menu = remote.signatureMenu?.trim();
    if (menu != null && menu.isNotEmpty) {
      return '$distance · 대표 메뉴는 $menu예요.';
    }
    final openTime = remote.openTime?.trim();
    if (openTime != null && openTime.isNotEmpty) {
      return '$distance · 이용 시간 $openTime';
    }
    final address = remote.address?.trim();
    if (address != null && address.isNotEmpty) {
      return '$distance · $address';
    }
    return '$distance 거리에 있는 ${remote.category.label} 장소예요.';
  }

  Future<void> ensureRemoteUserBootstrap() async {
    final backend = _backend;
    if (backend == null) {
      state = state.copyWith(statusMessage: '온라인 연결 후에 계정 상태를 확인할 수 있어요.');
      return;
    }

    state =
        state.copyWith(isBusy: true, statusMessage: '서버 사용자 데이터를 확인하는 중이에요.');
    try {
      await backend.ensureUserBootstrap();
      await refreshRemoteProgress(silent: true);
      state = state.copyWith(
        isBusy: false,
        statusMessage: '서버 사용자 데이터가 준비됐어요.',
      );
    } on Object {
      state = state.copyWith(
        isBusy: false,
        statusMessage: '서버 사용자 초기화에 실패했어요.',
      );
    }
  }

  Future<void> refreshRemoteProgress({bool silent = false}) async {
    final repository = _userRepository;
    if (repository == null) {
      if (!silent) {
        state = state.copyWith(statusMessage: '온라인 연결 후에 진행도를 불러올 수 있어요.');
      }
      return;
    }

    if (!silent) {
      state = state.copyWith(isBusy: true, statusMessage: '서버 진행도를 불러오는 중이에요.');
    }

    try {
      final progress = await repository.loadProgress();
      if (progress == null) {
        state = state.copyWith(
          isBusy: false,
          statusMessage: silent ? state.statusMessage : '서버 사용자 데이터가 아직 없어요.',
        );
        return;
      }

      final remotePets = _withCanonicalPetNames(
        progress.pets.isEmpty ? state.pets : progress.pets,
      );
      state = state.copyWith(
        pets: remotePets,
        eggs: progress.eggs,
        checkIns: progress.checkIns,
        careByPetId: _careForPets(
          pets: remotePets,
          existing: state.careByPetId,
          now: DateTime.now(),
        ),
        activePetId: progress.activePetId.isEmpty
            ? state.activePetId
            : progress.activePetId,
        activeEggId: _validActiveEggId(
          progress.activeEggId,
          progress.eggs,
        ),
        isBusy: false,
        statusMessage: silent ? state.statusMessage : '서버 진행도를 불러왔어요.',
      );
      _persistLocalProgress();
    } on Object {
      state = state.copyWith(
        isBusy: false,
        statusMessage: silent ? state.statusMessage : '서버 진행도를 불러오지 못했어요.',
      );
    }
  }

  Future<void> resetProgress() async {
    state = state.copyWith(
      isBusy: true,
      statusMessage: '진행도를 초기화하는 중이에요.',
    );

    var remoteDeleteFailed = false;
    if (_backend != null) {
      try {
        await _backend.deleteUserProgress();
      } on Object {
        remoteDeleteFailed = true;
      }
    }

    final repository = _localProgressRepository;
    try {
      await repository?.clearProgress();
    } on Object {
      state = state.copyWith(
        isBusy: false,
        statusMessage: remoteDeleteFailed
            ? '서버와 기기 내 진행도를 초기화하지 못했어요. 잠시 후에 다시 시도해 주세요.'
            : '기기 내 진행도를 초기화하지 못했어요. 잠시 후에 다시 시도해 주세요.',
      );
      return;
    }

    state = MasilPetState.initial(
      firebaseReady: state.firebaseReady,
      firebaseStartupIssue: state.firebaseStartupIssue,
    ).copyWith(
      statusMessage: remoteDeleteFailed
          ? '서버 진행도를 지우지 못했어요. 기기 내 진행은 초기화했어요.'
          : _backend == null
              ? '기기 내 진행을 초기화했어요.'
              : '기기와 서버 진행도를 초기화했어요.',
    );
  }

  Future<void> attemptCheckIn(Poi poi) async {
    final now = DateTime.now();
    final distance = state.currentLocation.distanceTo(poi.coordinates);

    if (!state.hasFreshVerifiedLocation) {
      state = state.copyWith(
        statusMessage: '현재 위치를 다시 확인해야 체크인할 수 있어요.',
        fieldActivity: PetFieldActivity.walking,
        bumpFieldActivity: true,
      );
      return;
    }

    if (state.remainingDailyCheckIns == 0) {
      state = state.copyWith(
        statusMessage: '오늘 쓸 수 있는 체크인 $dailyCheckInLimit회를 모두 썼어요. 내일 다시 이어가요.',
        fieldActivity: PetFieldActivity.walking,
        bumpFieldActivity: true,
      );
      return;
    }

    if (distance > checkInRadiusMeters) {
      state = state.copyWith(
        statusMessage:
            '${poi.title}까지 ${distance.round()}m 남았어요. 150m 안에서 체크인할 수 있어요.',
        fieldActivity: PetFieldActivity.walking,
        bumpFieldActivity: true,
      );
      return;
    }

    final alreadyCheckedIn = state.checkIns.any(
      (checkIn) =>
          checkIn.poiId == poi.id && isSameLocalDay(checkIn.createdAt, now),
    );
    if (alreadyCheckedIn) {
      state = state.copyWith(statusMessage: '오늘은 이미 ${poi.title}에 체크인했어요.');
      return;
    }

    final backend = _backend;
    if (backend != null) {
      state = state.copyWith(
        isBusy: true,
        statusMessage: '${poi.title} 서버 체크인을 확인하는 중이에요.',
        fieldActivity: PetFieldActivity.walking,
        bumpFieldActivity: true,
      );
      try {
        final result = await backend.attemptCheckIn(
          poiId: poi.id,
          location: state.currentLocation,
        );
        _applySuccessfulCheckIn(
          poi: poi,
          now: now,
          distance: result.distanceMeters,
          rewardStats: result.reward,
          eggProgress: result.eggProgress ??
              _growthEngine.rewardFor(poi.category).eggProgress,
          remotePetUpdate: result.updatedPet,
          companionPetId: result.companionPetId,
          creditedEggId: result.creditedEggId,
          messagePrefix: '${poi.title} 서버 체크인 완료',
        );
        await refreshRemoteProgress(silent: true);
        return;
      } on MasilPetBackendException catch (error) {
        await _handleRemoteCheckInFailure(poi, error);
        return;
      } on Object {
        state = state.copyWith(
          isBusy: false,
          statusMessage: '서버 체크인에 실패했어요. 지역 데이터가 준비되면 다시 시도해 주세요.',
        );
        return;
      }
    }

    final reward = _growthEngine.rewardFor(poi.category);
    _applySuccessfulCheckIn(
      poi: poi,
      now: now,
      distance: distance,
      rewardStats: reward.stats,
      eggProgress: reward.eggProgress,
      remotePetUpdate: null,
      companionPetId: state.activePet?.id,
      creditedEggId: state.activeIncubatingEgg?.id,
      messagePrefix: '${poi.title} 체크인 완료',
    );
  }

  Future<void> _handleRemoteCheckInFailure(
    Poi poi,
    MasilPetBackendException error,
  ) async {
    var message = '서버 체크인에 실패했어요. 잠시 후에 다시 시도해 주세요.';

    if (error.code == 'already-exists') {
      await refreshRemoteProgress(silent: true);
      message = '오늘은 이미 ${poi.title}에 체크인했어요.';
    } else if (error.code == 'not-found') {
      message = '지역 장소 데이터가 아직 준비되지 않았어요. 잠시 후에 다시 시도해 주세요.';
    } else if (error.code == 'unauthenticated') {
      message = '온라인 인증이 필요해요. 앱을 새로고침한 뒤에 다시 시도해 주세요.';
    } else if (error.code == 'failed-precondition') {
      final serverDistance = _distanceMetersFromErrorDetails(error.details);
      if (serverDistance != null) {
        message =
            '서버 기준으로 ${serverDistance.round()}m 남았어요. 150m 안에서 체크인할 수 있어요.';
      } else if ((error.message ?? '').contains('Daily check-in limit')) {
        message = '오늘 쓸 수 있는 서버 체크인 횟수를 모두 썼어요.';
      } else {
        message = '서버 체크인 조건을 만족하지 못했어요. 위치와 방문 기록을 확인해 주세요.';
      }
    }

    state = state.copyWith(
      isBusy: false,
      statusMessage: message,
      fieldActivity: PetFieldActivity.walking,
      bumpFieldActivity: true,
    );
  }

  double? _distanceMetersFromErrorDetails(Object? details) {
    if (details is! Map) {
      return null;
    }

    final value = details['distanceMeters'];
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  void _applySuccessfulCheckIn({
    required Poi poi,
    required DateTime now,
    required double distance,
    required GrowthStats rewardStats,
    required int eggProgress,
    required RemotePetUpdate? remotePetUpdate,
    required String? companionPetId,
    required String? creditedEggId,
    required String messagePrefix,
  }) {
    final updatedPets = _applyCheckInRewardToPet(
      rewardStats: rewardStats,
      remotePetUpdate: remotePetUpdate,
      interactedAt: now,
    );
    final remotePetId = remotePetUpdate?.id ?? companionPetId;
    final nextActivePetId =
        remotePetId != null && updatedPets.any((pet) => pet.id == remotePetId)
            ? remotePetId
            : state.activePetId;
    final companionCare =
        state.careByPetId[nextActivePetId] ?? PetCareState.initial(now);
    final firstVisit = !companionCare.memories.any(
      (memory) => memory.id.startsWith('checkin-${poi.id}-'),
    );
    final caredAfterVisit = _careEngine.afterCheckIn(
      companionCare,
      now,
      poi: poi,
      firstVisit: firstVisit,
    );
    final targetEggId = creditedEggId ?? state.activeIncubatingEgg?.id;
    var appliedEggProgress = 0;
    final progressedEggs = state.eggs.map((egg) {
      if (egg.id != targetEggId || egg.status != EggStatus.incubating) {
        return egg;
      }
      appliedEggProgress = eggProgress;
      final imprints = <PoiCategory>{
        ...egg.imprints,
        poi.category,
      }.toList(growable: false);
      return _growthEngine.progressEgg(egg, eggProgress).copyWith(
            incubationBondXp: egg.incubationBondXp + (firstVisit ? 2 : 1),
            imprints: imprints,
          );
    }).toList();
    final eggs = _maybeDropEgg(progressedEggs, poi, now);
    final discoveredNewEgg = eggs.length > progressedEggs.length;
    final nextActiveEggId = _validActiveEggId(
      state.activeEggId,
      eggs,
    );
    final checkIn = CheckIn(
      id: 'checkin-${now.microsecondsSinceEpoch}',
      poiId: poi.id,
      regionId: poi.regionId,
      category: poi.category,
      createdAt: now,
      distanceMeters: distance,
      rewardApplied: true,
      reward: CheckInReward(
        stats: rewardStats,
        eggProgress: appliedEggProgress,
      ),
      companionPetId: nextActivePetId,
      creditedEggId: appliedEggProgress > 0 ? targetEggId : null,
    );

    state = state.copyWith(
      pets: updatedPets,
      eggs: eggs,
      checkIns: [checkIn, ...state.checkIns],
      careByPetId: _replaceCare(nextActivePetId, caredAfterVisit),
      activePetId: nextActivePetId,
      activeEggId: nextActiveEggId,
      lastVisitedCategory: poi.category,
      isBusy: false,
      statusMessage: discoveredNewEgg && appliedEggProgress == 0
          ? '$messagePrefix: 새로운 알을 발견했어요!'
          : '$messagePrefix: ${CheckInReward(
              stats: rewardStats,
              eggProgress: appliedEggProgress,
            ).summaryLabel}',
      fieldActivity: PetFieldActivity.jumping,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
  }

  List<Pet> _applyCheckInRewardToPet({
    required GrowthStats rewardStats,
    required RemotePetUpdate? remotePetUpdate,
    required DateTime interactedAt,
  }) {
    final remotePetId = remotePetUpdate?.id;
    final targetPet = remotePetId == null
        ? state.activePet
        : state.pets.where((pet) => pet.id == remotePetId).firstOrNull ??
            state.activePet;
    if (targetPet == null) {
      return state.pets;
    }

    final shouldApplyRemotePatch =
        remotePetId == null || targetPet.id == remotePetId;
    final updated = _petAfterInteraction(
      activePet: targetPet,
      rewardStats: rewardStats,
      remotePetUpdate: shouldApplyRemotePatch ? remotePetUpdate : null,
      interactedAt: interactedAt,
    );

    return _replacePet(updated);
  }

  Future<void> startStepTracking() async {
    if (!_stepService.isSupported) {
      state = state.copyWith(
        stepTrackingSupported: false,
        statusMessage: '이 기기에서는 자동 걸음 측정을 지원하지 않아요.',
      );
      return;
    }
    if (state.stepTrackingActive) {
      await flushDeviceSteps();
      return;
    }
    state = state.copyWith(
      isBusy: true,
      statusMessage: '걸음 센서 권한을 확인하는 중이에요.',
    );
    try {
      final stream = await _stepService.openStepCountStream();
      await _stepSubscription?.cancel();
      _lastDeviceStepCount = null;
      _needsStepBaseline = _backend is CumulativeStepSyncBackend;
      _clearPendingStepSync();
      _stepSubscription = stream.listen(
        _handleDeviceStepCount,
        onError: (Object error, StackTrace stackTrace) {
          state = state.copyWith(
            stepTrackingActive: false,
            isBusy: false,
            statusMessage: '걸음 센서를 읽지 못했어요. 체크인 산책은 그대로 기록돼요.',
          );
        },
      );
      state = state.copyWith(
        stepTrackingActive: true,
        isBusy: false,
        statusMessage: '걸음 수 연결을 시작했어요. 100걸음마다 자동으로 반영해요.',
      );
      // 다음 실행에서 자동으로 다시 이어 붙일 수 있게 연결 상태를 남긴다.
      _persistLocalProgress();
    } on StepTrackingUnavailableException catch (error) {
      state = state.copyWith(
        stepTrackingActive: false,
        isBusy: false,
        statusMessage: error.message,
      );
      _persistLocalProgress();
    } on Object {
      state = state.copyWith(
        stepTrackingActive: false,
        isBusy: false,
        statusMessage: '걸음 수 연결을 시작하지 못했어요.',
      );
      _persistLocalProgress();
    }
  }

  void _handleDeviceStepCount(int totalSteps) {
    final previous = _lastDeviceStepCount;
    _lastDeviceStepCount = totalSteps;
    if (previous == null || totalSteps < previous) {
      if (_backend is CumulativeStepSyncBackend) {
        if (previous != null && totalSteps < previous) {
          _clearPendingStepSync();
        }
        _needsStepBaseline = true;
        unawaited(flushDeviceSteps());
      }
      return;
    }
    if (totalSteps == previous) {
      return;
    }
    final waiting = state.deviceStepsWaiting + totalSteps - previous;
    state = state.copyWith(deviceStepsWaiting: waiting);
    if (waiting >= 100) {
      unawaited(flushDeviceSteps());
    }
  }

  Future<void> flushDeviceSteps() async {
    if (_isFlushingDeviceSteps) {
      return;
    }
    final configuredBackend = _backend;
    final cumulativeBackend = configuredBackend is CumulativeStepSyncBackend
        ? configuredBackend as CumulativeStepSyncBackend
        : null;
    if (cumulativeBackend != null) {
      if (!_needsStepBaseline && state.deviceStepsWaiting <= 0) {
        return;
      }
      _isFlushingDeviceSteps = true;
      try {
        while (_needsStepBaseline || state.deviceStepsWaiting > 0) {
          final synced = await _flushCumulativeDeviceSteps(cumulativeBackend);
          if (!synced) {
            break;
          }
        }
      } finally {
        _isFlushingDeviceSteps = false;
      }
      return;
    }
    if (state.deviceStepsWaiting <= 0) {
      return;
    }
    _isFlushingDeviceSteps = true;
    try {
      while (state.deviceStepsWaiting > 0) {
        final requested = math.min(3000, state.deviceStepsWaiting);
        final applied = await _applyStepProgress(requested);
        if (applied <= 0) {
          break;
        }
        state = state.copyWith(
          deviceStepsWaiting: math.max(0, state.deviceStepsWaiting - applied),
        );
      }
    } finally {
      _isFlushingDeviceSteps = false;
    }
  }

  Future<bool> _flushCumulativeDeviceSteps(
    CumulativeStepSyncBackend backend,
  ) async {
    final observedTotal = _lastDeviceStepCount;
    if (observedTotal == null) {
      return false;
    }
    final now = DateTime.now();
    final dayKey = _koreanDayKey(now);
    if (_pendingStepDayKey != null && _pendingStepDayKey != dayKey) {
      _clearPendingStepSync();
    }
    if (_pendingStepOperationId == null) {
      _pendingStepOperationId =
          'steps-${now.microsecondsSinceEpoch}-${observedTotal.clamp(0, 9999999)}';
      _pendingStepDayKey = dayKey;
      _pendingStepObservedTotal = observedTotal;
      _pendingStepWaiting = state.deviceStepsWaiting;
      _pendingStepObservedAt = now;
    }

    state = state.copyWith(
      isBusy: true,
      statusMessage: _needsStepBaseline
          ? '이 기기의 걸음 기준점을 안전하게 맞추는 중이에요.'
          : '새 걸음을 중복 없이 동기화하는 중이에요.',
      fieldActivity: PetFieldActivity.walking,
      bumpFieldActivity: true,
    );
    try {
      final result = await backend.syncStepsV2(
        operationId: _pendingStepOperationId!,
        deviceId: _ensureStepSyncDeviceId(),
        dayKey: _pendingStepDayKey!,
        observedCumulativeSteps: _pendingStepObservedTotal!,
        observedAt: _pendingStepObservedAt!,
      );
      final consumedWaiting = _pendingStepWaiting ?? 0;
      _clearPendingStepSync();
      _needsStepBaseline = false;
      // 오늘 상한에 걸렸다면 남은 대기 걸음은 오늘 안에 반영될 수 없다. 계속
      // 재시도하며 같은 안내를 반복하지 않도록 대기열을 비우고 멈춘다.
      state = state.copyWith(
        deviceStepsWaiting: result.dailyLimitReached
            ? 0
            : math.max(0, state.deviceStepsWaiting - consumedWaiting),
      );
      if (result.appliedStepDelta > 0) {
        await _applyStepProgress(
          result.appliedStepDelta,
          syncedResult: result,
        );
      } else {
        state = state.copyWith(
          isBusy: false,
          statusMessage: result.counterReset
              ? '기기 걸음 수가 재설정되어 새 기준점부터 다시 기록해요.'
              : result.baselineInitialized
                  ? '걸음 기준점을 맞췄어요. 이제부터 새 걸음만 반영해요.'
                  : result.dailyLimitReached
                      ? '오늘 반영할 수 있는 걸음 수를 모두 썼어요. 내일 다시 이어가요.'
                      : '이미 반영한 걸음이에요. 중복 적립 없이 최신 상태로 맞췄어요.',
        );
        _persistLocalProgress();
      }
      return !result.dailyLimitReached;
    } on MasilPetBackendException catch (error) {
      state = state.copyWith(
        isBusy: false,
        statusMessage: _messageForRemoteStepFailure(error),
      );
      return false;
    } on Object {
      state = state.copyWith(
        isBusy: false,
        statusMessage: '걸음 동기화가 잠시 멈췄어요. 다음 연결 때 같은 기록으로 다시 시도할게요.',
      );
      return false;
    }
  }

  Future<void> addStepProgress(int stepDelta) async {
    await _applyStepProgress(stepDelta);
  }

  Future<int> _applyStepProgress(
    int stepDelta, {
    RemoteStepProgressResult? syncedResult,
  }) async {
    final backend = _backend;
    var appliedStepDelta = stepDelta;
    var resolvedResult = syncedResult;
    if (backend != null && resolvedResult == null) {
      state = state.copyWith(
        isBusy: true,
        statusMessage: '$stepDelta 걸음을 서버에 반영하는 중이에요.',
        fieldActivity: PetFieldActivity.walking,
        bumpFieldActivity: true,
      );
      try {
        resolvedResult = await backend.applyStepProgress(stepDelta);
        appliedStepDelta = resolvedResult.appliedStepDelta;
      } on MasilPetBackendException catch (error) {
        state = state.copyWith(
          isBusy: false,
          statusMessage: _messageForRemoteStepFailure(error),
        );
        return 0;
      } on Object {
        state = state.copyWith(
          isBusy: false,
          statusMessage: '서버에 걸음 수를 반영하지 못했어요. 기기 내 진행 상태는 그대로 남아 있어요.',
        );
        return 0;
      }
    }

    if (appliedStepDelta <= 0) {
      state = state.copyWith(
        isBusy: false,
        statusMessage: '오늘 반영할 수 있는 걸음 수를 모두 썼어요.',
      );
      return 0;
    }

    final creditedEggId = syncedResult == null
        ? state.activeIncubatingEgg?.id
        : syncedResult.creditedEggId;
    final targetEgg = state.eggs
        .where(
          (egg) =>
              egg.id == creditedEggId && egg.status == EggStatus.incubating,
        )
        .firstOrNull;
    final eggs = state.eggs.map((egg) {
      if (egg.id != targetEgg?.id) {
        return egg;
      }
      return _growthEngine.progressEgg(egg, appliedStepDelta).copyWith(
            incubationBondXp:
                egg.incubationBondXp + math.max(1, appliedStepDelta ~/ 500),
          );
    }).toList();
    final hatchableCount =
        eggs.where((egg) => egg.status == EggStatus.hatchable).length;
    final now = DateTime.now();
    final companionPetId = syncedResult?.companionPetId;
    final activePet = companionPetId == null
        ? state.activePet
        : state.pets.where((pet) => pet.id == companionPetId).firstOrNull ??
            state.activePet;
    final currentCare = activePet == null ? null : _careFor(activePet, now);
    final previousMilestones = (currentCare?.walkStepsToday ?? 0) ~/ 500;
    final nextMilestones =
        ((currentCare?.walkStepsToday ?? 0) + appliedStepDelta) ~/ 500;
    final bondReward = math
        .max(
          0,
          math.min(5, nextMilestones) - math.min(5, previousMilestones),
        )
        .toInt();
    final remotePetUpdate = syncedResult?.updatedPet;
    final nextPets = activePet == null
        ? state.pets
        : remotePetUpdate != null
            ? _replacePet(
                _petAfterInteraction(
                  activePet: activePet,
                  rewardStats: const GrowthStats(
                    exp: 0,
                    mood: 0,
                    knowledge: 0,
                    affinity: 0,
                  ),
                  remotePetUpdate: remotePetUpdate,
                  interactedAt: now,
                ),
              )
            : bondReward == 0
                ? state.pets
                : _replacePet(
                    _petAfterInteraction(
                      activePet: activePet,
                      rewardStats: GrowthStats(
                        exp: bondReward,
                        mood: bondReward,
                        knowledge: 0,
                        affinity: bondReward,
                      ),
                      remotePetUpdate: null,
                      interactedAt: now,
                    ),
                  );
    final nextCareByPetId = activePet == null
        ? state.careByPetId
        : _replaceCare(
            activePet.id,
            _careEngine.afterWalk(
              currentCare!,
              now,
              steps: appliedStepDelta,
            ),
          );
    final nextActiveEggId = _validActiveEggId(state.activeEggId, eggs);
    state = state.copyWith(
      pets: nextPets,
      eggs: eggs,
      activeEggId: nextActiveEggId,
      careByPetId: nextCareByPetId,
      isBusy: false,
      statusMessage: targetEgg == null
          ? '함께 $appliedStepDelta걸음을 걸었어요. 품고 있는 알을 선택하면 부화에도 반영돼요.'
          : hatchableCount > 0
              ? '부화할 수 있는 알이 있어요.'
              : '지금 품고 있는 알에 $appliedStepDelta걸음을 반영했어요.',
      fieldActivity: PetFieldActivity.walking,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
    return appliedStepDelta;
  }

  Future<HatchOutcome?> hatchEgg(String eggId) async {
    final egg = state.eggs.where((item) => item.id == eggId).firstOrNull;
    if (egg == null || egg.status != EggStatus.hatchable) {
      state = state.copyWith(statusMessage: '아직 부화할 수 없는 알이에요.');
      return null;
    }

    final template = templateFor(egg.templateId);
    final now = DateTime.now();
    final backend = _backend;
    final previousActivePetId = state.activePetId;
    var petId = 'pet-${template.id}-${now.microsecondsSinceEpoch}';
    RemoteHatchResult? remoteOutcome;

    if (backend != null) {
      state = state.copyWith(
          isBusy: true, statusMessage: '${template.name}의 알을 서버에서 부화하는 중이에요.');
      try {
        final detailedBackend = backend is DetailedHatchBackend
            ? backend as DetailedHatchBackend
            : null;
        if (detailedBackend != null) {
          final outcome = await detailedBackend.hatchEggWithOutcome(eggId);
          remoteOutcome = outcome;
          petId = outcome.petId;
        } else {
          petId = await backend.hatchEgg(eggId);
        }
      } on MasilPetBackendException catch (error) {
        state = state.copyWith(
          isBusy: false,
          statusMessage: _messageForRemoteHatchFailure(error),
          fieldActivity: PetFieldActivity.jumping,
          bumpFieldActivity: true,
        );
        return null;
      } on Object {
        state = state.copyWith(
          isBusy: false,
          statusMessage: '서버 부화에 실패했어요. 알 상태를 다시 확인해 주세요.',
        );
        return null;
      }
    }

    final remainingEggs = state.eggs.where((item) => item.id != eggId).toList();
    final existingPet = state.pets
            .where((pet) => pet.id == petId)
            .firstOrNull ??
        state.pets.where((pet) => pet.templateId == template.id).firstOrNull;
    final isReunion = remoteOutcome?.reunion == true ||
        (backend == null && existingPet != null);
    if (isReunion && existingPet != null) {
      final remotePet = remoteOutcome?.updatedPet;
      final reunited = remotePet == null
          ? _petAfterBond(existingPet, affinity: 5, interactedAt: now)
          : _petAfterInteraction(
              activePet: existingPet,
              rewardStats: const GrowthStats(
                exp: 0,
                mood: 0,
                knowledge: 0,
                affinity: 0,
              ),
              remotePetUpdate: remotePet,
              interactedAt: now,
            );
      final currentCare = _careFor(existingPet, now);
      final bondedAlready = currentCare.lastBondedDay != null &&
          isSameLocalDay(currentCare.lastBondedDay!, now);
      final reunionMemory = PetMemory(
        id: 'reunion-${egg.id}',
        title:
            '${template.name}${particleFor(template.name, '이', '가')} 다시 찾아온 날',
        detail: '같은 인연을 품은 알이 돌아와, 함께 쌓은 유대가 더 깊어졌어요.',
        createdAt: now,
        category: egg.imprints.firstOrNull,
      );
      final reunitedCare = currentCare.copyWith(
        updatedAt: now,
        affectionScore: currentCare.affectionScore + 5,
        bondedDays: currentCare.bondedDays + (bondedAlready ? 0 : 1),
        lastBondedDay: now,
        memories: [reunionMemory, ...currentCare.memories],
      );
      final reunitedWithCount = reunited.copyWith(
        reunionCount:
            remoteOutcome?.reunionCount ?? existingPet.reunionCount + 1,
      );
      state = state.copyWith(
        pets: _replacePet(reunitedWithCount),
        eggs: remainingEggs,
        careByPetId: _replaceCare(existingPet.id, reunitedCare),
        activePetId: previousActivePetId,
        // 부화한 알만 목록에서 빠지므로, 서버와 같이 기존 선택을 그대로 넘긴다.
        activeEggId: _validActiveEggId(state.activeEggId, remainingEggs),
        isBusy: false,
        statusMessage:
            '${template.name}${particleFor(template.name, '이', '가')} '
            '다시 찾아왔어요. 유대가 더 깊어졌어요.',
        fieldActivity: PetFieldActivity.jumping,
        bumpFieldActivity: true,
      );
      _persistLocalProgress();
      return HatchOutcome(petId: existingPet.id, reunion: true);
    }

    final inheritedAffinity = math.max(10, 10 + egg.incubationBondXp);
    final remotePet = remoteOutcome?.updatedPet;
    final initialStats = remotePet?.stats ??
        GrowthStats(
          exp: 10,
          mood: 15,
          knowledge: math.max(5, egg.imprints.length * 2),
          affinity: inheritedAffinity,
        );
    final pet = Pet(
      id: petId,
      templateId: template.id,
      name: template.name,
      stage: remotePet?.stage ?? PetStage.baby,
      level: remotePet?.level ?? 1,
      stats: initialStats,
      originRegionId: egg.originRegionId,
      hatchedAt: now,
      lastInteractedAt: null,
      originEggId: egg.id,
      reunionCount: remoteOutcome?.reunionCount ?? 0,
    );

    final hatchCare = PetCareState(
      updatedAt: now,
      dailyCountDay: now,
      bondedDays: 1,
      lastBondedDay: now,
      affectionScore: inheritedAffinity,
      knowledgeScore: egg.imprints.length * 2,
      adventureScore: egg.incubationBondXp,
      memories: [
        PetMemory(
          id: 'hatch-${egg.id}',
          title:
              '${template.name}${particleFor(template.name, '이', '가')} 태어난 날',
          detail: '알을 품고 함께 걸은 시간과 ${egg.originRegionId}의 추억을 간직하고 있어요.',
          createdAt: now,
          category: egg.imprints.firstOrNull,
        ),
      ],
    );
    state = state.copyWith(
      pets: [...state.pets, pet],
      eggs: remainingEggs,
      careByPetId: {
        ...state.careByPetId,
        pet.id: hatchCare,
      },
      activePetId: previousActivePetId,
      // 부화한 알만 목록에서 빠지므로, 서버와 같이 기존 선택을 그대로 넘긴다.
      activeEggId: _validActiveEggId(state.activeEggId, remainingEggs),
      isBusy: false,
      statusMessage: remoteOutcome?.reunion == true
          ? '${template.name}${particleFor(template.name, '이', '가')} 다시 찾아왔어요.'
          : '${template.name}${particleFor(template.name, '이', '가')} 부화했어요.',
      fieldActivity: PetFieldActivity.jumping,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
    return HatchOutcome(
      petId: pet.id,
      reunion: remoteOutcome?.reunion ?? false,
    );
  }

  Future<void> talkWithActivePet() async {
    final now = DateTime.now();
    final activePet = state.activePet;
    if (activePet == null) {
      state = state.copyWith(statusMessage: '대화할 마실펫이 없어요.');
      return;
    }
    final currentCare = _careFor(activePet, now);
    final legacyTalkCount =
        isSameLocalDay(state.dialogueDay, now) ? state.dialogueCountToday : 0;
    final talkCount = math.max(currentCare.talkCountToday, legacyTalkCount);
    if (talkCount >= dailyPetTalkLimit) {
      state = state.copyWith(
        dialogueCountToday: talkCount,
        dialogueDay: now,
        statusMessage: '오늘의 대화 횟수를 모두 썼어요.',
      );
      return;
    }

    final template = templateFor(activePet.templateId);
    final line = _dialogueService.lineForConversation(
      template: template,
      pet: activePet,
      care: currentCare,
      lastCategory: state.lastVisitedCategory,
      now: now,
      interactionIndex: talkCount,
    );
    var rewardStats =
        const GrowthStats(exp: 2, mood: 4, knowledge: 0, affinity: 1);
    RemotePetUpdate? remotePetUpdate;
    final backend = _backend;

    if (backend != null) {
      state = state.copyWith(
        isBusy: true,
        statusMessage: '${activePet.name}'
            '${particleFor(activePet.name, '과', '와')}의 대화를 '
            '서버에 반영하는 중이에요.',
        fieldActivity: PetFieldActivity.greeting,
        bumpFieldActivity: true,
      );
      try {
        final result = await backend.interactWithPet(
            petId: activePet.id, actionType: 'talk');
        rewardStats = result.reward;
        remotePetUpdate = result.updatedPet;
      } on MasilPetBackendException catch (error) {
        state = state.copyWith(
          isBusy: false,
          statusMessage: _messageForRemotePetInteractionFailure(error, '대화'),
        );
        return;
      } on Object {
        state = state.copyWith(
          isBusy: false,
          statusMessage: '서버에 대화를 반영하지 못했어요.',
        );
        return;
      }
    }

    // 서버 왕복 사이에 걸음 동기화 등이 돌봄 상태를 바꿨을 수 있어 다시 읽는다.
    final talkedPet = _petById(activePet.id) ?? activePet;
    final appliedAt = DateTime.now();
    final careAtApply = _careFor(talkedPet, appliedAt);
    final appliedTalkCount = math.max(
      careAtApply.talkCountToday,
      isSameLocalDay(state.dialogueDay, appliedAt)
          ? state.dialogueCountToday
          : 0,
    );

    state = state.copyWith(
      pets: _replacePet(
        _petAfterInteraction(
          activePet: talkedPet,
          rewardStats: rewardStats,
          remotePetUpdate: remotePetUpdate,
          interactedAt: appliedAt,
        ),
      ),
      careByPetId: _replaceCare(
        talkedPet.id,
        _careEngine.afterTalk(careAtApply, appliedAt),
      ),
      dialogueCountToday: appliedTalkCount + 1,
      dialogueDay: appliedAt,
      isBusy: false,
      statusMessage: line.text,
      fieldActivity: PetFieldActivity.greeting,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
  }

  Future<void> feedActivePet([PetFood? food]) =>
      feedPet(state.activePetId, food: food);

  /// Feeds one specific pet. The yard menu can reach any pet standing outside,
  /// not just the current companion.
  Future<void> feedPet(String petId, {PetFood? food}) async {
    final activePet = _petById(petId);
    if (activePet == null) {
      state = state.copyWith(statusMessage: '먹이를 줄 마실펫이 없어요.');
      return;
    }

    final now = DateTime.now();
    final template = templateFor(activePet.templateId);
    final currentCare = _careFor(activePet, now);
    final selectedFood = food ?? PetFood.homeMeal;
    final favoriteFood = _careEngine.favoriteFoodFor(template);
    final dislikedFood = _careEngine.dislikedFoodFor(template);
    if (currentCare.feedCountToday >= dailyFeedCareLimit) {
      state = state.copyWith(
        statusMessage: '${activePet.name}'
            '${particleFor(activePet.name, '은', '는')} 오늘 충분히 배불러요. '
            '내일 또 챙겨주세요.',
        fieldActivity: PetFieldActivity.greeting,
        bumpFieldActivity: true,
      );
      return;
    }
    var rewardStats =
        const GrowthStats(exp: 3, mood: 8, knowledge: 0, affinity: 2);
    RemotePetUpdate? remotePetUpdate;
    final backend = _backend;

    if (backend != null) {
      state = state.copyWith(
        isBusy: true,
        statusMessage: '${activePet.name} 먹이주기를 서버에 반영하는 중이에요.',
        fieldActivity: PetFieldActivity.eating,
        bumpFieldActivity: true,
      );
      try {
        final result = await backend.interactWithPet(
            petId: activePet.id, actionType: 'feed');
        rewardStats = result.reward;
        remotePetUpdate = result.updatedPet;
      } on MasilPetBackendException catch (error) {
        state = state.copyWith(
          isBusy: false,
          statusMessage: _messageForRemotePetInteractionFailure(error, '먹이주기'),
        );
        return;
      } on Object {
        state = state.copyWith(
          isBusy: false,
          statusMessage: '서버에 먹이주기를 반영하지 못했어요.',
        );
        return;
      }
    }

    // 서버 왕복 사이에 걸음 동기화 등이 돌봄 상태를 바꿨을 수 있어 다시 읽는다.
    final fedPet = _petById(activePet.id) ?? activePet;
    final appliedAt = DateTime.now();
    final careAtApply = _careFor(fedPet, appliedAt);
    final updated = _petAfterInteraction(
      activePet: fedPet,
      rewardStats: rewardStats,
      remotePetUpdate: remotePetUpdate,
      interactedAt: appliedAt,
    );

    state = state.copyWith(
      pets: _replacePet(updated),
      careByPetId: _replaceCare(
        fedPet.id,
        _careEngine.afterFeed(
          careAtApply,
          appliedAt,
          food: selectedFood,
          favoriteFood: favoriteFood,
          dislikedFood: dislikedFood,
        ),
      ),
      isBusy: false,
      statusMessage: selectedFood == favoriteFood
          ? '${activePet.name}${particleFor(activePet.name, '이', '가')} '
              '${selectedFood.label}을 아주 맛있게 먹었어요!'
          : selectedFood == dislikedFood
              ? '${activePet.name}${particleFor(activePet.name, '이', '가')} '
                  '${selectedFood.label} 앞에서 잠깐 망설였어요.'
              : _dialogueService
                  .lineForAction(
                    template: template,
                    trigger: 'fed',
                    variantSeed: currentCare.feedCountToday,
                  )
                  .text,
      fieldActivity: PetFieldActivity.eating,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
  }

  Future<void> playActivePet() => playPet(state.activePetId);

  Future<void> playPet(String petId) async {
    final requestedPet = _petById(petId);
    if (requestedPet == null) {
      state = state.copyWith(statusMessage: '함께 놀 마실펫이 없어요.');
      return;
    }

    final template = templateFor(requestedPet.templateId);
    var rewardStats =
        const GrowthStats(exp: 3, mood: 6, knowledge: 0, affinity: 2);
    RemotePetUpdate? remotePetUpdate;
    final backend = _backend;
    if (backend != null) {
      state = state.copyWith(
        isBusy: true,
        statusMessage: '${requestedPet.name}와의 놀이를 서버에 반영하는 중이에요.',
      );
      try {
        final result = await backend.interactWithPet(
          petId: requestedPet.id,
          actionType: 'play',
        );
        rewardStats = result.reward;
        remotePetUpdate = result.updatedPet;
      } on MasilPetBackendException catch (error) {
        state = state.copyWith(
          isBusy: false,
          statusMessage: _messageForRemotePetInteractionFailure(error, '놀이'),
        );
        return;
      } on Object {
        state =
            state.copyWith(isBusy: false, statusMessage: '서버에 놀이를 반영하지 못했어요.');
        return;
      }
    }
    // 서버 왕복 사이에 걸음 동기화 등이 돌봄 상태를 바꿨을 수 있어 다시 읽는다.
    final activePet = _petById(petId) ?? requestedPet;
    final now = DateTime.now();
    final currentCare = _careFor(activePet, now);
    state = state.copyWith(
      pets: _replacePet(
        _petAfterInteraction(
          activePet: activePet,
          rewardStats: rewardStats,
          remotePetUpdate: remotePetUpdate,
          interactedAt: now,
        ),
      ),
      careByPetId: _replaceCare(
        activePet.id,
        _careEngine.afterPlay(currentCare, now),
      ),
      statusMessage: _dialogueService
          .lineForAction(
            template: template,
            trigger: 'played',
            variantSeed: currentCare.playCountToday,
          )
          .text,
      isBusy: false,
      fieldActivity: PetFieldActivity.jumping,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
  }

  Future<void> cleanActivePet() => cleanPet(state.activePetId);

  Future<void> cleanPet(String petId) async {
    final requestedPet = _petById(petId);
    if (requestedPet == null) {
      state = state.copyWith(statusMessage: '씻겨 줄 마실펫이 없어요.');
      return;
    }

    final template = templateFor(requestedPet.templateId);
    var rewardStats =
        const GrowthStats(exp: 2, mood: 4, knowledge: 0, affinity: 1);
    RemotePetUpdate? remotePetUpdate;
    final backend = _backend;
    if (backend != null) {
      state = state.copyWith(
        isBusy: true,
        statusMessage: '${requestedPet.name} 씻기기를 서버에 반영하는 중이에요.',
      );
      try {
        final result = await backend.interactWithPet(
          petId: requestedPet.id,
          actionType: 'clean',
        );
        rewardStats = result.reward;
        remotePetUpdate = result.updatedPet;
      } on MasilPetBackendException catch (error) {
        state = state.copyWith(
          isBusy: false,
          statusMessage: _messageForRemotePetInteractionFailure(error, '씻기기'),
        );
        return;
      } on Object {
        state = state.copyWith(
          isBusy: false,
          statusMessage: '서버에 씻기기를 반영하지 못했어요.',
        );
        return;
      }
    }
    // 서버 왕복 사이에 걸음 동기화 등이 돌봄 상태를 바꿨을 수 있어 다시 읽는다.
    final activePet = _petById(petId) ?? requestedPet;
    final now = DateTime.now();
    final currentCare = _careFor(activePet, now);
    state = state.copyWith(
      pets: _replacePet(
        _petAfterInteraction(
          activePet: activePet,
          rewardStats: rewardStats,
          remotePetUpdate: remotePetUpdate,
          interactedAt: now,
        ),
      ),
      careByPetId: _replaceCare(
        activePet.id,
        _careEngine.afterClean(currentCare, now),
      ),
      statusMessage: _dialogueService
          .lineForAction(
            template: template,
            trigger: 'cleaned',
            variantSeed: currentCare.cleanCountToday,
          )
          .text,
      isBusy: false,
      fieldActivity: PetFieldActivity.greeting,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
  }

  Future<void> sleepActivePet() async {
    final requestedPet = state.activePet;
    if (requestedPet == null) {
      state = state.copyWith(statusMessage: '재워 줄 마실펫이 없어요.');
      return;
    }

    final template = templateFor(requestedPet.templateId);
    final careBeforeRequest = _careFor(requestedPet, DateTime.now());
    if (careBeforeRequest.isSleeping) {
      final wakeAt = DateTime.now();
      state = state.copyWith(
        careByPetId: _replaceCare(
          requestedPet.id,
          _careEngine.afterWake(_careFor(requestedPet, wakeAt), wakeAt),
        ),
        statusMessage:
            '${requestedPet.name}${particleFor(requestedPet.name, '이', '가')} 눈을 비비며 일어났어요.',
        fieldActivity: PetFieldActivity.greeting,
        bumpFieldActivity: true,
      );
      _persistLocalProgress();
      return;
    }
    var rewardStats =
        const GrowthStats(exp: 1, mood: 2, knowledge: 0, affinity: 1);
    RemotePetUpdate? remotePetUpdate;
    final backend = _backend;
    if (backend != null) {
      state = state.copyWith(
        isBusy: true,
        statusMessage: '${requestedPet.name}의 휴식을 서버에 반영하는 중이에요.',
      );
      try {
        final result = await backend.interactWithPet(
          petId: requestedPet.id,
          actionType: 'sleep',
        );
        rewardStats = result.reward;
        remotePetUpdate = result.updatedPet;
      } on MasilPetBackendException catch (error) {
        state = state.copyWith(
          isBusy: false,
          statusMessage: _messageForRemotePetInteractionFailure(error, '재우기'),
        );
        return;
      } on Object {
        state =
            state.copyWith(isBusy: false, statusMessage: '서버에 휴식을 반영하지 못했어요.');
        return;
      }
    }
    // 서버 왕복 사이에 걸음 동기화 등이 돌봄 상태를 바꿨을 수 있어 다시 읽는다.
    final activePet = _petById(requestedPet.id) ?? requestedPet;
    final now = DateTime.now();
    final currentCare = _careFor(activePet, now);
    state = state.copyWith(
      pets: _replacePet(
        _petAfterInteraction(
          activePet: activePet,
          rewardStats: rewardStats,
          remotePetUpdate: remotePetUpdate,
          interactedAt: now,
        ),
      ),
      careByPetId: _replaceCare(
        activePet.id,
        _careEngine.afterSleep(currentCare, now),
      ),
      statusMessage: _dialogueService
          .lineForAction(
            template: template,
            trigger: 'resting',
          )
          .text,
      isBusy: false,
      fieldActivity: PetFieldActivity.sleeping,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
  }

  Future<void> touchActivePet(PetTouch touch) async {
    final pet = state.activePet;
    if (pet == null) {
      state = state.copyWith(statusMessage: '쓰다듬어 줄 마실펫이 없어요.');
      return;
    }
    final template = templateFor(pet.templateId);
    final preferred = _careEngine.preferredTouchFor(template);
    final reaction = touch == preferred
        ? '${pet.name}${particleFor(pet.name, '이', '가')} 가장 좋아하는 '
            '${touch.label}에 몸을 기대 왔어요.'
        : touch == PetTouch.tail
            ? '${pet.name}${particleFor(pet.name, '이', '가')} 꼬리를 살짝 감추고 쳐다봐요.'
            : '${pet.name}${particleFor(pet.name, '이', '가')} ${touch.label}에 기분 좋게 웃어요.';
    var rewardStats =
        const GrowthStats(exp: 1, mood: 3, knowledge: 0, affinity: 1);
    RemotePetUpdate? remotePetUpdate;
    final backend = _backend;
    if (backend != null) {
      state = state.copyWith(
        isBusy: true,
        statusMessage: '${pet.name}와의 교감을 서버에 반영하는 중이에요.',
      );
      try {
        final result = await backend.interactWithPet(
          petId: pet.id,
          actionType: 'touch',
        );
        rewardStats = result.reward;
        remotePetUpdate = result.updatedPet;
      } on MasilPetBackendException catch (error) {
        state = state.copyWith(
          isBusy: false,
          statusMessage: _messageForRemotePetInteractionFailure(error, '쓰다듬기'),
        );
        return;
      } on Object {
        state = state.copyWith(
          isBusy: false,
          statusMessage: '서버에 쓰다듬기를 반영하지 못했어요.',
        );
        return;
      }
    }
    // 서버 왕복 사이에 걸음 동기화 등이 돌봄 상태를 바꿨을 수 있어 다시 읽는다.
    final touchedPet = _petById(pet.id) ?? pet;
    final now = DateTime.now();
    final updated = _careEngine.afterTouch(
      _careFor(touchedPet, now),
      now,
      touch: touch,
      preferredTouch: preferred,
    );
    state = state.copyWith(
      pets: _replacePet(
        _petAfterInteraction(
          activePet: touchedPet,
          rewardStats: rewardStats,
          remotePetUpdate: remotePetUpdate,
          interactedAt: now,
        ),
      ),
      careByPetId: _replaceCare(touchedPet.id, updated),
      statusMessage: reaction,
      isBusy: false,
      fieldActivity: touch == PetTouch.hug
          ? PetFieldActivity.greeting
          : PetFieldActivity.jumping,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
  }

  Future<void> cleanActivePetWaste() async {
    final requestedPet = state.activePet;
    if (requestedPet == null) {
      return;
    }
    if (_careFor(requestedPet, DateTime.now()).wasteCount == 0) {
      state = state.copyWith(statusMessage: '지금은 주변이 깨끗해요.');
      return;
    }
    var rewardStats =
        const GrowthStats(exp: 2, mood: 4, knowledge: 0, affinity: 1);
    RemotePetUpdate? remotePetUpdate;
    final backend = _backend;
    if (backend != null) {
      state = state.copyWith(
        isBusy: true,
        statusMessage: '${requestedPet.name} 주변 청소를 서버에 반영하는 중이에요.',
      );
      try {
        // 목욕('clean')과 구분해야 일일 돌봄 집계와 서버 보상이 섞이지 않는다.
        final result = await backend.interactWithPet(
          petId: requestedPet.id,
          actionType: 'tidy',
        );
        rewardStats = result.reward;
        remotePetUpdate = result.updatedPet;
      } on MasilPetBackendException catch (error) {
        state = state.copyWith(
          isBusy: false,
          statusMessage: _messageForRemotePetInteractionFailure(error, '주변 청소'),
        );
        return;
      } on Object {
        state = state.copyWith(
          isBusy: false,
          statusMessage: '서버에 주변 청소를 반영하지 못했어요.',
        );
        return;
      }
    }
    // 서버 왕복 사이에 걸음 동기화 등이 돌봄 상태를 바꿨을 수 있어 다시 읽는다.
    final pet = _petById(requestedPet.id) ?? requestedPet;
    final now = DateTime.now();
    final current = _careFor(pet, now);
    state = state.copyWith(
      pets: _replacePet(
        _petAfterInteraction(
          activePet: pet,
          rewardStats: rewardStats,
          remotePetUpdate: remotePetUpdate,
          interactedAt: now,
        ),
      ),
      careByPetId: _replaceCare(
        pet.id,
        _careEngine.afterWasteClean(current, now),
      ),
      statusMessage: '${pet.name} 주변을 말끔히 치웠어요. 고맙다는 듯 빙글 돌아요.',
      isBusy: false,
      fieldActivity: PetFieldActivity.greeting,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
  }

  Pet? _petById(String petId) {
    for (final pet in state.pets) {
      if (pet.id == petId) {
        return pet;
      }
    }
    return null;
  }

  Pet? petForId(String petId) => _petById(petId);

  void claimDailyCareReward() {
    final now = DateTime.now();
    final claimKey = _careEngine.localDayKey(now);
    if (state.dailyCareRewardClaimKey == claimKey) {
      state = state.copyWith(statusMessage: '오늘의 돌봄 포인트는 이미 받았어요.');
      return;
    }

    final pet = state.activePet;
    final routine = pet == null
        ? const DailyCareRoutineProgress(
            fed: false,
            played: false,
            cleaned: false,
            talked: false,
            checkedIn: false,
          )
        : state.dailyCareRoutineForPet(pet.id, now: now);
    if (!routine.isComplete) {
      state = state.copyWith(
        statusMessage:
            '오늘의 돌봄 루틴을 ${routine.completedCount}/${routine.targetCount} 완료했어요.',
      );
      return;
    }

    state = state.copyWith(
      carePoints: state.carePoints + dailyCareRewardPoints,
      dailyCareRewardClaimKey: claimKey,
      statusMessage: '오늘의 돌봄 포인트 $dailyCareRewardPoints점을 받았어요.',
      fieldActivity: PetFieldActivity.jumping,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
  }

  Pet _petAfterInteraction({
    required Pet activePet,
    required GrowthStats rewardStats,
    required RemotePetUpdate? remotePetUpdate,
    required DateTime interactedAt,
  }) {
    final stats = remotePetUpdate?.stats ?? activePet.stats.add(rewardStats);
    final level = remotePetUpdate?.level ?? _growthEngine.levelFor(stats);
    final stage = remotePetUpdate?.stage ??
        _growthEngine.stageFor(
          level: level,
          stats: stats,
          currentStage: activePet.stage,
        );

    return activePet.copyWith(
      stats: stats,
      level: level,
      stage: stage,
      lastInteractedAt: interactedAt,
    );
  }

  Pet _petAfterBond(
    Pet pet, {
    required int affinity,
    required DateTime interactedAt,
  }) {
    return _petAfterInteraction(
      activePet: pet,
      rewardStats: GrowthStats(
        exp: affinity,
        mood: affinity,
        knowledge: 0,
        affinity: affinity.clamp(1, 5),
      ),
      remotePetUpdate: null,
      interactedAt: interactedAt,
    );
  }

  PetTemplate templateFor(String templateId) {
    return state.templates.firstWhere((template) => template.id == templateId);
  }

  PetPersonality personalityFor(Pet pet) {
    return _careEngine.personalityFor(templateFor(pet.templateId));
  }

  PetFood favoriteFoodFor(Pet pet) {
    return _careEngine.favoriteFoodFor(templateFor(pet.templateId));
  }

  PetFood dislikedFoodFor(Pet pet) {
    return _careEngine.dislikedFoodFor(templateFor(pet.templateId));
  }

  PetTouch preferredTouchFor(Pet pet) {
    return _careEngine.preferredTouchFor(templateFor(pet.templateId));
  }

  PetNeed currentNeedFor(Pet pet, {DateTime? now}) {
    final resolvedAt = now ?? DateTime.now();
    return _careEngine.requestFor(_careFor(pet, resolvedAt), resolvedAt);
  }

  List<Pet> _withCanonicalPetNames(Iterable<Pet> pets) {
    return pets.map((pet) {
      final matchingTemplates = state.templates.where(
        (template) => template.id == pet.templateId,
      );
      if (matchingTemplates.isEmpty) {
        return pet;
      }
      final canonicalName = matchingTemplates.first.name;
      return pet.name == canonicalName
          ? pet
          : pet.copyWith(name: canonicalName);
    }).toList(growable: false);
  }

  List<Pet> _replacePet(Pet updated) {
    return state.pets
        .map((pet) => pet.id == updated.id ? updated : pet)
        .toList();
  }

  PetCareState _careFor(Pet pet, DateTime now) {
    return state.careForPet(pet.id, now: now) ?? PetCareState.initial(now);
  }

  Map<String, PetCareState> _replaceCare(
    String petId,
    PetCareState updated,
  ) {
    return {
      ...state.careByPetId,
      petId: updated,
    };
  }

  String _validActiveEggId(String requestedId, List<Egg> eggs) {
    return MasilPetState.selectActiveEgg(eggs, requestedId)?.id ?? '';
  }

  Map<String, PetCareState> _careForPets({
    required List<Pet> pets,
    required Map<String, PetCareState> existing,
    required DateTime now,
  }) {
    final result = <String, PetCareState>{...existing};
    for (final pet in pets) {
      result[pet.id] = _careEngine.resolve(
        existing[pet.id] ?? PetCareState.initial(now),
        now,
      );
    }
    return result;
  }

  List<Egg> _maybeDropEgg(List<Egg> currentEggs, Poi poi, DateTime now) {
    if (currentEggs.where((egg) => egg.status != EggStatus.hatched).length >=
        maxStoredEggs) {
      return currentEggs;
    }

    final firstCheckInToday = state.todayCheckInCount == 0;
    final rareCategory = poi.category == PoiCategory.history ||
        poi.category == PoiCategory.festival;
    if (!firstCheckInToday && !rareCategory) {
      return currentEggs;
    }

    final template = _templateForCategory(
      poi.category,
      poi.regionId,
      poi.id,
      excludedTemplateIds: {
        ...state.pets.map((pet) => pet.templateId),
        ...currentEggs.map((egg) => egg.templateId),
      },
    );
    return [
      ...currentEggs,
      Egg(
        id: 'egg-${template.id}-${now.microsecondsSinceEpoch}',
        templateId: template.id,
        originRegionId: poi.regionId,
        originPoiId: poi.id,
        finderPetId: state.activePet?.id,
        progress: 0,
        requiredSteps: 3500,
        status: EggStatus.incubating,
        createdAt: now,
        incubationBondXp: 1,
        imprints: [poi.category],
      ),
    ];
  }

  PetTemplate _templateForCategory(
    PoiCategory category,
    String regionId,
    String poiId, {
    Set<String> excludedTemplateIds = const {},
  }) {
    final availableTemplates = state.templates
        .where((template) => !excludedTemplateIds.contains(template.id))
        .toList(growable: false);
    final candidatePool =
        availableTemplates.isEmpty ? state.templates : availableTemplates;
    final regionalCategoryMatches = candidatePool
        .where(
          (template) =>
              template.regionId == regionId &&
              template.primaryCategory == category,
        )
        .toList(growable: false);
    if (regionalCategoryMatches.isNotEmpty) {
      return regionalCategoryMatches[
          _stableTemplateIndex(poiId, regionalCategoryMatches.length)];
    }

    final regionalMatches = candidatePool
        .where((template) => template.regionId == regionId)
        .toList(growable: false);
    if (regionalMatches.isNotEmpty) {
      return regionalMatches[
          _stableTemplateIndex(poiId, regionalMatches.length)];
    }

    final categoryMatches = candidatePool
        .where((template) => template.primaryCategory == category)
        .toList(growable: false);
    if (categoryMatches.isNotEmpty) {
      return categoryMatches[
          _stableTemplateIndex(poiId, categoryMatches.length)];
    }
    return candidatePool.first;
  }

  int _stableTemplateIndex(String value, int length) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0xFFFFFFFF;
    }
    return hash % length;
  }

  String _messageForRemoteStepFailure(MasilPetBackendException error) {
    if (error.code == 'unauthenticated') {
      return '온라인 인증이 필요해요. 앱을 새로고침한 뒤에 다시 시도해 주세요.';
    }

    if (error.code == 'invalid-argument') {
      final message = error.message ?? '';
      if (message.contains('or less')) {
        return '한 번에 반영할 수 있는 걸음 수를 넘었어요. 잠시 후에 다시 시도해 주세요.';
      }
      return '걸음 수가 올바르지 않아요. 잠시 후에 다시 시도해 주세요.';
    }

    if (error.code == 'failed-precondition' &&
        (error.message ?? '').contains('Daily step progress limit')) {
      return '오늘 서버에 반영할 수 있는 걸음 수를 모두 썼어요.';
    }

    return '서버에 걸음 수를 반영하지 못했어요. 잠시 후에 다시 시도해 주세요.';
  }

  String _messageForRemoteHatchFailure(MasilPetBackendException error) {
    if (error.code == 'unauthenticated') {
      return '온라인 인증이 필요해요. 앱을 새로고침한 뒤에 다시 시도해 주세요.';
    }

    if (error.code == 'not-found') {
      return '서버에서 알 정보를 찾을 수 없어요. 진행도를 새로고침한 뒤에 다시 시도해 주세요.';
    }

    if (error.code == 'failed-precondition') {
      final message = error.message ?? '';
      if (message.contains('not hatchable')) {
        return '서버 기준으로는 아직 부화할 수 없는 알이에요. 걸음 진행도를 확인해 주세요.';
      }
      if (message.contains('Pet template')) {
        return '펫 도감 데이터가 아직 준비되지 않았어요. 잠시 후에 다시 시도해 주세요.';
      }
      return '서버 부화 조건을 만족하지 못했어요. 알 상태를 다시 확인해 주세요.';
    }

    return '서버 부화에 실패했어요. 잠시 후에 다시 시도해 주세요.';
  }

  String _messageForRemotePetInteractionFailure(
    MasilPetBackendException error,
    String actionLabel,
  ) {
    if (error.code == 'unauthenticated') {
      return '온라인 인증이 필요해요. 앱을 새로고침한 뒤에 다시 시도해 주세요.';
    }

    if (error.code == 'not-found') {
      return '서버에서 이 마실펫을 찾을 수 없어요. 진행도를 새로고침한 뒤에 다시 시도해 주세요.';
    }

    if (error.code == 'invalid-argument') {
      return '$actionLabel 요청이 올바르지 않아요. 앱을 새로고침한 뒤에 다시 시도해 주세요.';
    }

    return '서버에 $actionLabel 결과를 반영하지 못했어요. 잠시 후에 다시 시도해 주세요.';
  }

  String _messageForRemoteActivePetFailure(MasilPetBackendException error) {
    if (error.code == 'unauthenticated') {
      return '온라인 인증이 필요해요. 앱을 새로고침한 뒤에 다시 시도해 주세요.';
    }

    if (error.code == 'not-found') {
      return '서버에서 이 마실펫을 찾을 수 없어요. 진행도를 새로고침한 뒤에 다시 시도해 주세요.';
    }

    if (error.code == 'invalid-argument') {
      return '동행 마실펫 변경 요청이 올바르지 않아요. 앱을 새로고침한 뒤에 다시 시도해 주세요.';
    }

    return '서버에 동행 마실펫을 반영하지 못했어요. 잠시 후에 다시 시도해 주세요.';
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
