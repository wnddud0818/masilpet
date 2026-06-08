import 'dart:async';

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
    backend:
        ref.watch(firebaseReadyProvider) ? FirebaseMasilPetBackend() : null,
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
      FirebaseStartupIssue.none => '온라인 연결 전: 기기 내 진행으로 시작합니다.',
      FirebaseStartupIssue.missingWebConfiguration =>
        'Firebase Web 설정값이 없어 기기 내 진행으로 시작합니다.',
      FirebaseStartupIssue.initializationFailed =>
        'Firebase 연결에 실패해 기기 내 진행으로 시작합니다.',
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
    required this.currentLocation,
    required this.locationVerified,
    required this.locationVerifiedAt,
    required this.activePetId,
    required this.selectedTab,
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
    final starterTemplate = starterPetTemplates.first;
    return MasilPetState(
      firebaseReady: firebaseReady,
      firebaseStartupIssue: firebaseStartupIssue,
      onboardingComplete: false,
      region: koreaRegion,
      pois: starterPoiSeed,
      templates: starterPetTemplates,
      pets: [
        Pet(
          id: 'pet-starter-wave-naru',
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
      currentLocation: starterPoiSeed.first.coordinates,
      locationVerified: false,
      locationVerifiedAt: null,
      activePetId: 'pet-starter-wave-naru',
      selectedTab: 0,
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
  final Coordinates currentLocation;
  final bool locationVerified;
  final DateTime? locationVerifiedAt;
  final String activePetId;
  final int selectedTab;
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
    Coordinates? currentLocation,
    bool? locationVerified,
    DateTime? locationVerifiedAt,
    bool clearLocationVerifiedAt = false,
    String? activePetId,
    int? selectedTab,
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
      currentLocation: currentLocation ?? this.currentLocation,
      locationVerified: locationVerified ?? this.locationVerified,
      locationVerifiedAt: clearLocationVerifiedAt
          ? null
          : locationVerifiedAt ?? this.locationVerifiedAt,
      activePetId: activePetId ?? this.activePetId,
      selectedTab: selectedTab ?? this.selectedTab,
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

class MasilPetController extends StateNotifier<MasilPetState> {
  MasilPetController({
    required bool firebaseReady,
    FirebaseStartupIssue firebaseStartupIssue = FirebaseStartupIssue.none,
    required DeviceLocationService locationService,
    required MasilPetBackend? backend,
    required FirestoreUserRepository? userRepository,
    LocalProgressRepository? localProgressRepository,
  })  : _locationService = locationService,
        _backend = backend,
        _userRepository = userRepository,
        _localProgressRepository = localProgressRepository,
        super(MasilPetState.initial(
          firebaseReady: firebaseReady,
          firebaseStartupIssue: firebaseStartupIssue,
        )) {
    Future.microtask(() async {
      await _safeBootstrapLocalSession();
      if (firebaseReady) {
        await _bootstrapOnlineSession();
      }
    });
  }

  final DeviceLocationService _locationService;
  final MasilPetBackend? _backend;
  final FirestoreUserRepository? _userRepository;
  final LocalProgressRepository? _localProgressRepository;
  final GrowthEngine _growthEngine = const GrowthEngine();
  final StaticDialogueService _dialogueService = const StaticDialogueService();

  Future<void> _safeBootstrapLocalSession() async {
    try {
      await _bootstrapLocalSession();
    } on Object {
      state = state.copyWith(
        statusMessage: state.firebaseReady
            ? '저장된 진행도를 불러오지 못했습니다. 온라인 동기화를 준비합니다.'
            : '저장된 진행도를 불러오지 못했습니다. 새 진행으로 시작합니다.',
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

    final now = DateTime.now();
    final dialogueCountToday = isSameLocalDay(snapshot.dialogueDay, now)
        ? snapshot.dialogueCountToday
        : 0;

    state = state.copyWith(
      onboardingComplete: snapshot.onboardingComplete,
      pois: snapshot.pois.isEmpty ? state.pois : snapshot.pois,
      pets: snapshot.pets.isEmpty ? state.pets : snapshot.pets,
      eggs: snapshot.eggs,
      checkIns: snapshot.checkIns,
      currentLocation: snapshot.currentLocation,
      locationVerified: snapshot.locationVerified,
      locationVerifiedAt: snapshot.locationVerifiedAt,
      activePetId: snapshot.activePetId.isEmpty
          ? state.activePetId
          : snapshot.activePetId,
      lastVisitedCategory: snapshot.lastVisitedCategory,
      clearLastVisitedCategory: snapshot.lastVisitedCategory == null,
      dialogueCountToday: dialogueCountToday,
      dialogueDay: dialogueCountToday == 0 ? now : snapshot.dialogueDay,
      statusMessage: state.firebaseReady
          ? '저장된 진행도를 불러왔습니다. 온라인 동기화를 준비합니다.'
          : '저장된 진행도를 불러왔습니다.',
    );
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
      currentLocation: state.currentLocation,
      locationVerified: state.locationVerified,
      locationVerifiedAt: state.locationVerifiedAt,
      activePetId: state.activePetId,
      lastVisitedCategory: state.lastVisitedCategory,
      dialogueCountToday: state.dialogueCountToday,
      dialogueDay: state.dialogueDay,
    );
  }

  Future<void> _bootstrapOnlineSession() async {
    final backend = _backend;
    final repository = _userRepository;
    if (backend == null || repository == null) {
      return;
    }

    state = state.copyWith(
      isBusy: true,
      statusMessage: '계정과 진행도를 동기화하는 중입니다.',
    );

    try {
      await backend.ensureUserBootstrap();
      await refreshRemoteProgress(silent: true);
      state = state.copyWith(
        isBusy: false,
        statusMessage: '계정과 진행도를 동기화했습니다.',
      );
    } on Object {
      state = state.copyWith(
        isBusy: false,
        statusMessage: '온라인 동기화에 실패했습니다. 현재 기기의 진행으로 계속합니다.',
      );
    }
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(
      onboardingComplete: true,
      statusMessage: '마실펫 탐험을 시작합니다.',
      fieldActivity: PetFieldActivity.walking,
      bumpFieldActivity: true,
    );
    final saved = await _saveLocalProgress();
    if (!saved) {
      state = state.copyWith(
        statusMessage: '기기 내 진행을 저장하지 못했습니다. 현재 세션에서는 계속 이용할 수 있습니다.',
      );
    }
  }

  void setTab(int tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void selectPet(String petId) {
    state = state.copyWith(
      activePetId: petId,
      statusMessage: '대표 마실펫을 변경했습니다.',
    );
    _persistLocalProgress();
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
          ? '전국 기본 체험 위치로 이동했습니다. 추천 장소 체크인을 바로 진행할 수 있습니다.'
          : '전국 기본 장소 지도로 이동했습니다. 체크인은 현재 위치 확인 후 가능합니다.',
      fieldActivity: PetFieldActivity.walking,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
  }

  Future<void> useDeviceLocation() async {
    state = state.copyWith(
      selectedTab: 0,
      isBusy: true,
      statusMessage: '현재 위치를 확인하는 중입니다.',
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
            remotePois.isEmpty ? '현재 위치를 반영했습니다.' : '현재 위치와 주변 장소를 반영했습니다.',
        fieldActivity: PetFieldActivity.walking,
        bumpFieldActivity: true,
      );
      _persistLocalProgress();
    } on LocationUnavailableException catch (error) {
      state = state.copyWith(isBusy: false, statusMessage: error.message);
    } on Object {
      state = state.copyWith(isBusy: false, statusMessage: '위치를 가져오지 못했습니다.');
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
      shortDescription:
          '현재 위치에서 ${remote.distanceMeters.round()}m 거리의 ${remote.category.label} 장소입니다.',
    );
  }

  Future<void> ensureRemoteUserBootstrap() async {
    final backend = _backend;
    if (backend == null) {
      state = state.copyWith(statusMessage: '온라인 연결 후 계정 상태를 확인할 수 있습니다.');
      return;
    }

    state =
        state.copyWith(isBusy: true, statusMessage: '서버 사용자 데이터를 확인하는 중입니다.');
    try {
      await backend.ensureUserBootstrap();
      await refreshRemoteProgress(silent: true);
      state = state.copyWith(
        isBusy: false,
        statusMessage: '서버 사용자 데이터가 준비되었습니다.',
      );
    } on Object {
      state = state.copyWith(
        isBusy: false,
        statusMessage: '서버 사용자 초기화에 실패했습니다.',
      );
    }
  }

  Future<void> refreshRemoteProgress({bool silent = false}) async {
    final repository = _userRepository;
    if (repository == null) {
      if (!silent) {
        state = state.copyWith(statusMessage: '온라인 연결 후 진행도를 불러올 수 있습니다.');
      }
      return;
    }

    if (!silent) {
      state = state.copyWith(isBusy: true, statusMessage: '서버 진행도를 불러오는 중입니다.');
    }

    try {
      final progress = await repository.loadProgress();
      if (progress == null) {
        state = state.copyWith(
          isBusy: false,
          statusMessage: silent ? state.statusMessage : '서버 사용자 데이터가 아직 없습니다.',
        );
        return;
      }

      state = state.copyWith(
        pets: progress.pets.isEmpty ? state.pets : progress.pets,
        eggs: progress.eggs,
        checkIns: progress.checkIns,
        activePetId: progress.activePetId.isEmpty
            ? state.activePetId
            : progress.activePetId,
        isBusy: false,
        statusMessage: silent ? state.statusMessage : '서버 진행도를 불러왔습니다.',
      );
      _persistLocalProgress();
    } on Object {
      state = state.copyWith(
        isBusy: false,
        statusMessage: silent ? state.statusMessage : '서버 진행도 불러오기에 실패했습니다.',
      );
    }
  }

  Future<void> resetProgress() async {
    state = state.copyWith(
      isBusy: true,
      statusMessage: '진행도를 초기화하는 중입니다.',
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
            ? '서버와 기기 내 진행도 초기화에 실패했습니다. 잠시 후 다시 시도하세요.'
            : '기기 내 진행도 초기화에 실패했습니다. 잠시 후 다시 시도하세요.',
      );
      return;
    }

    state = MasilPetState.initial(
      firebaseReady: state.firebaseReady,
      firebaseStartupIssue: state.firebaseStartupIssue,
    ).copyWith(
      statusMessage: remoteDeleteFailed
          ? '서버 진행도 삭제에 실패했습니다. 기기 내 진행은 초기화했습니다.'
          : _backend == null
              ? '기기 내 진행을 초기화했습니다.'
              : '기기와 서버 진행도를 초기화했습니다.',
    );
  }

  Future<void> attemptCheckIn(Poi poi) async {
    final now = DateTime.now();
    final distance = state.currentLocation.distanceTo(poi.coordinates);

    if (!state.hasFreshVerifiedLocation) {
      state = state.copyWith(
        statusMessage: '현재 위치를 다시 확인해야 체크인할 수 있습니다.',
        fieldActivity: PetFieldActivity.walking,
        bumpFieldActivity: true,
      );
      return;
    }

    if (state.remainingDailyCheckIns == 0) {
      state = state.copyWith(
        statusMessage:
            '오늘 가능한 체크인 $dailyCheckInLimit회를 모두 사용했습니다. 내일 다시 이어갈 수 있습니다.',
        fieldActivity: PetFieldActivity.walking,
        bumpFieldActivity: true,
      );
      return;
    }

    if (distance > checkInRadiusMeters) {
      state = state.copyWith(
        statusMessage:
            '${poi.title}까지 ${distance.round()}m 떨어져 있습니다. 150m 안에서 체크인할 수 있습니다.',
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
      state = state.copyWith(statusMessage: '오늘은 이미 ${poi.title}에 체크인했습니다.');
      return;
    }

    final backend = _backend;
    if (backend != null) {
      state = state.copyWith(
        isBusy: true,
        statusMessage: '${poi.title} 서버 체크인을 확인하는 중입니다.',
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
          statusMessage: '서버 체크인에 실패했습니다. 지역 데이터 준비 후 다시 시도하세요.',
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
      messagePrefix: '${poi.title} 체크인 완료',
    );
  }

  Future<void> _handleRemoteCheckInFailure(
    Poi poi,
    MasilPetBackendException error,
  ) async {
    var message = '서버 체크인에 실패했습니다. 잠시 후 다시 시도하세요.';

    if (error.code == 'already-exists') {
      await refreshRemoteProgress(silent: true);
      message = '오늘은 이미 ${poi.title}에 체크인했습니다.';
    } else if (error.code == 'not-found') {
      message = '지역 장소 데이터가 아직 준비되지 않았습니다. 잠시 후 다시 시도하세요.';
    } else if (error.code == 'unauthenticated') {
      message = '온라인 인증이 필요합니다. 앱을 새로고침한 뒤 다시 시도하세요.';
    } else if (error.code == 'failed-precondition') {
      final serverDistance = _distanceMetersFromErrorDetails(error.details);
      if (serverDistance != null) {
        message =
            '서버 기준 ${serverDistance.round()}m 떨어져 있습니다. 150m 안에서 체크인할 수 있습니다.';
      } else if ((error.message ?? '').contains('Daily check-in limit')) {
        message = '오늘 가능한 서버 체크인 횟수를 모두 사용했습니다.';
      } else {
        message = '서버 체크인 조건을 만족하지 못했습니다. 위치와 방문 기록을 확인하세요.';
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
    required String messagePrefix,
  }) {
    final updatedPets = _applyCheckInRewardToPet(
      rewardStats: rewardStats,
      remotePetUpdate: remotePetUpdate,
      interactedAt: now,
    );
    final remotePetId = remotePetUpdate?.id;
    final nextActivePetId =
        remotePetId != null && updatedPets.any((pet) => pet.id == remotePetId)
            ? remotePetId
            : state.activePetId;
    final progressedEggs = state.eggs.map((egg) {
      return _growthEngine.progressEgg(egg, eggProgress);
    }).toList();
    final eggs = _maybeDropEgg(progressedEggs, poi, now);
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
        eggProgress: eggProgress,
      ),
    );

    state = state.copyWith(
      pets: updatedPets,
      eggs: eggs,
      checkIns: [checkIn, ...state.checkIns],
      activePetId: nextActivePetId,
      lastVisitedCategory: poi.category,
      isBusy: false,
      statusMessage: '$messagePrefix: ${CheckInReward(
        stats: rewardStats,
        eggProgress: eggProgress,
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

  Future<void> addStepProgress(int stepDelta) async {
    final backend = _backend;
    var appliedStepDelta = stepDelta;
    if (backend != null) {
      state = state.copyWith(
        isBusy: true,
        statusMessage: '$stepDelta 걸음을 서버에 반영하는 중입니다.',
        fieldActivity: PetFieldActivity.walking,
        bumpFieldActivity: true,
      );
      try {
        final result = await backend.applyStepProgress(stepDelta);
        appliedStepDelta = result.appliedStepDelta;
      } on MasilPetBackendException catch (error) {
        state = state.copyWith(
          isBusy: false,
          statusMessage: _messageForRemoteStepFailure(error),
        );
        return;
      } on Object {
        state = state.copyWith(
          isBusy: false,
          statusMessage: '서버 걸음 수 반영에 실패했습니다. 기기 내 진행 상태는 유지합니다.',
        );
        return;
      }
    }

    if (appliedStepDelta <= 0) {
      state = state.copyWith(
        isBusy: false,
        statusMessage: '오늘 반영할 수 있는 걸음 수를 모두 사용했습니다.',
      );
      return;
    }

    final eggs = state.eggs
        .map((egg) => _growthEngine.progressEgg(egg, appliedStepDelta))
        .toList();
    final hatchableCount =
        eggs.where((egg) => egg.status == EggStatus.hatchable).length;
    state = state.copyWith(
      eggs: eggs,
      isBusy: false,
      statusMessage: hatchableCount > 0
          ? '부화 가능한 알이 있습니다.'
          : '알 부화 진행도에 $appliedStepDelta 걸음을 반영했습니다.',
      fieldActivity: PetFieldActivity.walking,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
  }

  Future<void> hatchEgg(String eggId) async {
    final egg = state.eggs.where((item) => item.id == eggId).firstOrNull;
    if (egg == null || egg.status != EggStatus.hatchable) {
      state = state.copyWith(statusMessage: '아직 부화할 수 없는 알입니다.');
      return;
    }

    final template = templateFor(egg.templateId);
    final now = DateTime.now();
    final backend = _backend;
    var petId = 'pet-${template.id}-${now.microsecondsSinceEpoch}';

    if (backend != null) {
      state = state.copyWith(
          isBusy: true, statusMessage: '${template.name}의 알을 서버에서 부화하는 중입니다.');
      try {
        petId = await backend.hatchEgg(eggId);
      } on MasilPetBackendException catch (error) {
        state = state.copyWith(
          isBusy: false,
          statusMessage: _messageForRemoteHatchFailure(error),
          fieldActivity: PetFieldActivity.jumping,
          bumpFieldActivity: true,
        );
        return;
      } on Object {
        state = state.copyWith(
          isBusy: false,
          statusMessage: '서버 부화에 실패했습니다. 알 상태를 다시 확인하세요.',
        );
        return;
      }
    }

    final pet = Pet(
      id: petId,
      templateId: template.id,
      name: template.name,
      stage: PetStage.baby,
      level: 1,
      stats: const GrowthStats(exp: 10, mood: 15, knowledge: 5, affinity: 10),
      originRegionId: egg.originRegionId,
      hatchedAt: now,
      lastInteractedAt: null,
    );

    state = state.copyWith(
      pets: [...state.pets, pet],
      eggs: state.eggs.where((item) => item.id != eggId).toList(),
      activePetId: pet.id,
      isBusy: false,
      statusMessage: '${template.name}이 부화했습니다.',
      fieldActivity: PetFieldActivity.jumping,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
  }

  Future<void> talkWithActivePet() async {
    final now = DateTime.now();
    final resetCount =
        isSameLocalDay(state.dialogueDay, now) ? state.dialogueCountToday : 0;
    if (resetCount >= 5) {
      state = state.copyWith(
        dialogueCountToday: resetCount,
        dialogueDay: now,
        statusMessage: '오늘의 대화 횟수를 모두 사용했습니다.',
      );
      return;
    }

    final activePet = state.activePet;
    if (activePet == null) {
      state = state.copyWith(statusMessage: '대화할 마실펫이 없습니다.');
      return;
    }

    final template = templateFor(activePet.templateId);
    final line = _dialogueService.lineFor(
      template: template,
      lastCategory: state.lastVisitedCategory,
    );
    var rewardStats =
        const GrowthStats(exp: 2, mood: 4, knowledge: 0, affinity: 1);
    RemotePetUpdate? remotePetUpdate;
    final backend = _backend;

    if (backend != null) {
      state = state.copyWith(
        isBusy: true,
        statusMessage: '${activePet.name}과의 대화를 서버에 반영하는 중입니다.',
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
          statusMessage: '서버 대화 반영에 실패했습니다.',
        );
        return;
      }
    }

    state = state.copyWith(
      pets: _replacePet(
        _petAfterInteraction(
          activePet: activePet,
          rewardStats: rewardStats,
          remotePetUpdate: remotePetUpdate,
          interactedAt: now,
        ),
      ),
      dialogueCountToday: resetCount + 1,
      dialogueDay: now,
      isBusy: false,
      statusMessage: line.text,
      fieldActivity: PetFieldActivity.greeting,
      bumpFieldActivity: true,
    );
    _persistLocalProgress();
  }

  Future<void> feedActivePet() async {
    final activePet = state.activePet;
    if (activePet == null) {
      state = state.copyWith(statusMessage: '먹이를 줄 마실펫이 없습니다.');
      return;
    }

    final now = DateTime.now();
    var rewardStats =
        const GrowthStats(exp: 3, mood: 8, knowledge: 0, affinity: 2);
    RemotePetUpdate? remotePetUpdate;
    final backend = _backend;

    if (backend != null) {
      state = state.copyWith(
        isBusy: true,
        statusMessage: '${activePet.name} 먹이주기를 서버에 반영하는 중입니다.',
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
          statusMessage: '서버 먹이주기 반영에 실패했습니다.',
        );
        return;
      }
    }

    final updated = _petAfterInteraction(
      activePet: activePet,
      rewardStats: rewardStats,
      remotePetUpdate: remotePetUpdate,
      interactedAt: now,
    );

    state = state.copyWith(
      pets: _replacePet(updated),
      isBusy: false,
      statusMessage: '${activePet.name}의 기분이 좋아졌습니다.',
      fieldActivity: PetFieldActivity.eating,
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

  PetTemplate templateFor(String templateId) {
    return state.templates.firstWhere((template) => template.id == templateId);
  }

  List<Pet> _replacePet(Pet updated) {
    return state.pets
        .map((pet) => pet.id == updated.id ? updated : pet)
        .toList();
  }

  List<Egg> _maybeDropEgg(List<Egg> currentEggs, Poi poi, DateTime now) {
    final hasOpenEgg =
        currentEggs.any((egg) => egg.status != EggStatus.hatched);
    if (hasOpenEgg) {
      return currentEggs;
    }

    final firstCheckInToday = state.todayCheckInCount == 0;
    final rareCategory = poi.category == PoiCategory.history ||
        poi.category == PoiCategory.festival;
    if (!firstCheckInToday && !rareCategory) {
      return currentEggs;
    }

    final template = _templateForCategory(poi.category);
    return [
      ...currentEggs,
      Egg(
        id: 'egg-${template.id}-${now.microsecondsSinceEpoch}',
        templateId: template.id,
        originRegionId: poi.regionId,
        progress: 0,
        requiredSteps: 3500,
        status: EggStatus.incubating,
        createdAt: now,
      ),
    ];
  }

  PetTemplate _templateForCategory(PoiCategory category) {
    return state.templates.firstWhere(
      (template) => template.primaryCategory == category,
      orElse: () => state.templates.first,
    );
  }

  String _messageForRemoteStepFailure(MasilPetBackendException error) {
    if (error.code == 'unauthenticated') {
      return '온라인 인증이 필요합니다. 앱을 새로고침한 뒤 다시 시도하세요.';
    }

    if (error.code == 'invalid-argument') {
      final message = error.message ?? '';
      if (message.contains('or less')) {
        return '한 번에 반영할 수 있는 걸음 수를 넘었습니다. 잠시 후 다시 시도하세요.';
      }
      return '걸음 수가 올바르지 않습니다. 잠시 후 다시 시도하세요.';
    }

    if (error.code == 'failed-precondition' &&
        (error.message ?? '').contains('Daily step progress limit')) {
      return '오늘 서버에 반영할 수 있는 걸음 수를 모두 사용했습니다.';
    }

    return '서버 걸음 수 반영에 실패했습니다. 잠시 후 다시 시도하세요.';
  }

  String _messageForRemoteHatchFailure(MasilPetBackendException error) {
    if (error.code == 'unauthenticated') {
      return '온라인 인증이 필요합니다. 앱을 새로고침한 뒤 다시 시도하세요.';
    }

    if (error.code == 'not-found') {
      return '서버에서 알 정보를 찾을 수 없습니다. 진행도를 새로고침한 뒤 다시 시도하세요.';
    }

    if (error.code == 'failed-precondition') {
      final message = error.message ?? '';
      if (message.contains('not hatchable')) {
        return '아직 서버 기준으로 부화할 수 없는 알입니다. 걸음 진행도를 확인하세요.';
      }
      if (message.contains('Pet template')) {
        return '펫 도감 데이터가 아직 준비되지 않았습니다. 잠시 후 다시 시도하세요.';
      }
      return '서버 부화 조건을 만족하지 못했습니다. 알 상태를 다시 확인하세요.';
    }

    return '서버 부화에 실패했습니다. 잠시 후 다시 시도하세요.';
  }

  String _messageForRemotePetInteractionFailure(
    MasilPetBackendException error,
    String actionLabel,
  ) {
    if (error.code == 'unauthenticated') {
      return '온라인 인증이 필요합니다. 앱을 새로고침한 뒤 다시 시도하세요.';
    }

    if (error.code == 'not-found') {
      return '서버에서 이 마실펫을 찾을 수 없습니다. 진행도를 새로고침한 뒤 다시 시도하세요.';
    }

    if (error.code == 'invalid-argument') {
      return '$actionLabel 요청이 올바르지 않습니다. 앱을 새로고침한 뒤 다시 시도하세요.';
    }

    return '서버 $actionLabel 반영에 실패했습니다. 잠시 후 다시 시도하세요.';
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
