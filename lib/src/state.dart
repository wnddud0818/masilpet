import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/masilpet_backend.dart';
import 'data/firestore_user_repository.dart';
import 'models.dart';
import 'seed_data.dart';
import 'services.dart';

final firebaseReadyProvider = Provider<bool>((ref) => false);

final masilPetControllerProvider =
    StateNotifierProvider<MasilPetController, MasilPetState>((ref) {
  return MasilPetController(
    firebaseReady: ref.watch(firebaseReadyProvider),
    backend: ref.watch(firebaseReadyProvider) ? FirebaseMasilPetBackend() : null,
    userRepository: ref.watch(firebaseReadyProvider) ? FirestoreUserRepository() : null,
    locationService: const DeviceLocationService(),
  );
});

class MasilPetState {
  const MasilPetState({
    required this.firebaseReady,
    required this.onboardingComplete,
    required this.region,
    required this.pois,
    required this.templates,
    required this.pets,
    required this.eggs,
    required this.checkIns,
    required this.currentLocation,
    required this.activePetId,
    required this.selectedTab,
    required this.statusMessage,
    required this.lastVisitedCategory,
    required this.dialogueCountToday,
    required this.dialogueDay,
    required this.isBusy,
  });

  factory MasilPetState.initial({required bool firebaseReady}) {
    final now = DateTime.now();
    final starterTemplate = busanPetTemplates.first;
    return MasilPetState(
      firebaseReady: firebaseReady,
      onboardingComplete: false,
      region: busanRegion,
      pois: busanPoiSeed,
      templates: busanPetTemplates,
      pets: [
        Pet(
          id: 'pet-starter-wave-naru',
          templateId: starterTemplate.id,
          name: starterTemplate.name,
          stage: PetStage.baby,
          level: 1,
          stats: const GrowthStats(exp: 20, mood: 20, knowledge: 5, affinity: 8),
          originRegionId: starterTemplate.regionId,
          hatchedAt: now,
          lastInteractedAt: null,
        ),
      ],
      eggs: [
        Egg(
          id: 'egg-harbor-maru',
          templateId: 'harbor-maru',
          originRegionId: 'busan',
          progress: 1200,
          requiredSteps: 3500,
          status: EggStatus.incubating,
          createdAt: now,
        ),
      ],
      checkIns: const [],
      currentLocation: busanPoiSeed.first.coordinates,
      activePetId: 'pet-starter-wave-naru',
      selectedTab: 0,
      statusMessage: firebaseReady ? 'Firebase 연결 준비 완료' : 'Firebase 미설정: 데모 모드로 시작합니다.',
      lastVisitedCategory: null,
      dialogueCountToday: 0,
      dialogueDay: now,
      isBusy: false,
    );
  }

  final bool firebaseReady;
  final bool onboardingComplete;
  final Region region;
  final List<Poi> pois;
  final List<PetTemplate> templates;
  final List<Pet> pets;
  final List<Egg> eggs;
  final List<CheckIn> checkIns;
  final Coordinates currentLocation;
  final String activePetId;
  final int selectedTab;
  final String statusMessage;
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

  int get todayCheckInCount {
    final now = DateTime.now();
    return checkIns.where((checkIn) => isSameLocalDay(checkIn.createdAt, now)).length;
  }

  MasilPetState copyWith({
    bool? firebaseReady,
    bool? onboardingComplete,
    Region? region,
    List<Poi>? pois,
    List<PetTemplate>? templates,
    List<Pet>? pets,
    List<Egg>? eggs,
    List<CheckIn>? checkIns,
    Coordinates? currentLocation,
    String? activePetId,
    int? selectedTab,
    String? statusMessage,
    PoiCategory? lastVisitedCategory,
    bool clearLastVisitedCategory = false,
    int? dialogueCountToday,
    DateTime? dialogueDay,
    bool? isBusy,
  }) {
    return MasilPetState(
      firebaseReady: firebaseReady ?? this.firebaseReady,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      region: region ?? this.region,
      pois: pois ?? this.pois,
      templates: templates ?? this.templates,
      pets: pets ?? this.pets,
      eggs: eggs ?? this.eggs,
      checkIns: checkIns ?? this.checkIns,
      currentLocation: currentLocation ?? this.currentLocation,
      activePetId: activePetId ?? this.activePetId,
      selectedTab: selectedTab ?? this.selectedTab,
      statusMessage: statusMessage ?? this.statusMessage,
      lastVisitedCategory:
          clearLastVisitedCategory ? null : lastVisitedCategory ?? this.lastVisitedCategory,
      dialogueCountToday: dialogueCountToday ?? this.dialogueCountToday,
      dialogueDay: dialogueDay ?? this.dialogueDay,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

class MasilPetController extends StateNotifier<MasilPetState> {
  MasilPetController({
    required bool firebaseReady,
    required DeviceLocationService locationService,
    required MasilPetBackend? backend,
    required FirestoreUserRepository? userRepository,
  })  : _locationService = locationService,
        _backend = backend,
        _userRepository = userRepository,
        super(MasilPetState.initial(firebaseReady: firebaseReady));

  final DeviceLocationService _locationService;
  final MasilPetBackend? _backend;
  final FirestoreUserRepository? _userRepository;
  final GrowthEngine _growthEngine = const GrowthEngine();
  final StaticDialogueService _dialogueService = const StaticDialogueService();

  void completeOnboarding() {
    state = state.copyWith(
      onboardingComplete: true,
      statusMessage: '마실펫 탐험을 시작합니다.',
    );
  }

  void setTab(int tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void selectPet(String petId) {
    state = state.copyWith(
      activePetId: petId,
      statusMessage: '대표 마실펫을 변경했습니다.',
    );
  }

  void useDemoBusanLocation() {
    state = state.copyWith(
      currentLocation: busanPoiSeed.first.coordinates,
      statusMessage: '현재 위치를 해운대 데모 지점으로 설정했습니다.',
    );
  }

  Future<void> useDeviceLocation() async {
    state = state.copyWith(isBusy: true, statusMessage: '현재 위치를 확인하는 중입니다.');
    try {
      final location = await _locationService.readCurrentLocation();
      state = state.copyWith(
        currentLocation: location,
        isBusy: false,
        statusMessage: '현재 위치를 반영했습니다.',
      );
    } on LocationUnavailableException catch (error) {
      state = state.copyWith(isBusy: false, statusMessage: error.message);
    } on Object {
      state = state.copyWith(isBusy: false, statusMessage: '위치를 가져오지 못했습니다.');
    }
  }

  Future<void> seedRemoteStarterRegionData() async {
    final backend = _backend;
    if (backend == null) {
      state = state.copyWith(statusMessage: 'Firebase 설정 후 서버 시드를 호출할 수 있습니다.');
      return;
    }

    state = state.copyWith(isBusy: true, statusMessage: '마실펫 첫 지역 서버 데이터를 준비하는 중입니다.');
    try {
      await backend.seedStarterRegionData();
      await backend.ensureUserBootstrap();
      await refreshRemoteProgress(silent: true);
      state = state.copyWith(
        isBusy: false,
        statusMessage: '서버에 마실펫 첫 지역 데이터와 사용자 초기화를 반영했습니다.',
      );
    } on Object {
      state = state.copyWith(
        isBusy: false,
        statusMessage: '서버 데이터 준비에 실패했습니다. Functions 배포와 권한을 확인하세요.',
      );
    }
  }

  Future<void> ensureRemoteUserBootstrap() async {
    final backend = _backend;
    if (backend == null) {
      state = state.copyWith(statusMessage: 'Firebase 설정 후 서버 사용자 초기화를 호출할 수 있습니다.');
      return;
    }

    state = state.copyWith(isBusy: true, statusMessage: '서버 사용자 데이터를 확인하는 중입니다.');
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
        state = state.copyWith(statusMessage: 'Firebase 설정 후 서버 진행도를 불러올 수 있습니다.');
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
        activePetId: progress.activePetId.isEmpty ? state.activePetId : progress.activePetId,
        isBusy: false,
        statusMessage: silent ? state.statusMessage : '서버 진행도를 불러왔습니다.',
      );
    } on Object {
      state = state.copyWith(
        isBusy: false,
        statusMessage: silent ? state.statusMessage : '서버 진행도 불러오기에 실패했습니다.',
      );
    }
  }

  Future<void> attemptCheckIn(Poi poi) async {
    final now = DateTime.now();
    final distance = state.currentLocation.distanceTo(poi.coordinates);

    if (distance > checkInRadiusMeters) {
      state = state.copyWith(
        statusMessage: '${poi.title}까지 ${distance.round()}m 떨어져 있습니다. 150m 안에서 체크인할 수 있습니다.',
      );
      return;
    }

    final alreadyCheckedIn = state.checkIns.any(
      (checkIn) => checkIn.poiId == poi.id && isSameLocalDay(checkIn.createdAt, now),
    );
    if (alreadyCheckedIn) {
      state = state.copyWith(statusMessage: '오늘은 이미 ${poi.title}에 체크인했습니다.');
      return;
    }

    final backend = _backend;
    if (backend != null) {
      state = state.copyWith(isBusy: true, statusMessage: '${poi.title} 서버 체크인을 확인하는 중입니다.');
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
          eggProgress: _growthEngine.rewardFor(poi.category).eggProgress,
          messagePrefix: '${poi.title} 서버 체크인 완료',
        );
        return;
      } on Object {
        state = state.copyWith(
          isBusy: false,
          statusMessage: '서버 체크인에 실패했습니다. 서버 시드 준비 후 다시 시도하세요.',
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
      messagePrefix: '${poi.title} 체크인 완료',
    );
  }

  void _applySuccessfulCheckIn({
    required Poi poi,
    required DateTime now,
    required double distance,
    required GrowthStats rewardStats,
    required int eggProgress,
    required String messagePrefix,
  }) {
    final updatedPets = _applyRewardToActivePet(rewardStats, now);
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
    );

    state = state.copyWith(
      pets: updatedPets,
      eggs: eggs,
      checkIns: [checkIn, ...state.checkIns],
      lastVisitedCategory: poi.category,
      isBusy: false,
      statusMessage: '$messagePrefix: EXP +${rewardStats.exp}, ${poi.category.label} 보상 적용',
    );
  }

  Future<void> addStepProgress(int stepDelta) async {
    final backend = _backend;
    if (backend != null) {
      state = state.copyWith(isBusy: true, statusMessage: '$stepDelta 걸음을 서버에 반영하는 중입니다.');
      try {
        await backend.applyStepProgress(stepDelta);
      } on Object {
        state = state.copyWith(
          isBusy: false,
          statusMessage: '서버 걸음 수 반영에 실패했습니다. 로컬 데모 상태는 유지합니다.',
        );
        return;
      }
    }

    final eggs = state.eggs.map((egg) => _growthEngine.progressEgg(egg, stepDelta)).toList();
    final hatchableCount = eggs.where((egg) => egg.status == EggStatus.hatchable).length;
    state = state.copyWith(
      eggs: eggs,
      isBusy: false,
      statusMessage:
          hatchableCount > 0 ? '부화 가능한 알이 있습니다.' : '알 부화 진행도에 $stepDelta 걸음을 반영했습니다.',
    );
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
      state = state.copyWith(isBusy: true, statusMessage: '${template.name}의 알을 서버에서 부화하는 중입니다.');
      try {
        petId = await backend.hatchEgg(eggId);
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
    );
  }

  Future<void> talkWithActivePet() async {
    final now = DateTime.now();
    final resetCount = isSameLocalDay(state.dialogueDay, now) ? state.dialogueCountToday : 0;
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
    const rewardStats = GrowthStats(exp: 2, mood: 4, knowledge: 0, affinity: 1);
    final backend = _backend;

    if (backend != null) {
      state = state.copyWith(isBusy: true, statusMessage: '${activePet.name}과의 대화를 서버에 반영하는 중입니다.');
      try {
        await backend.interactWithPet(petId: activePet.id, actionType: 'talk');
      } on Object {
        state = state.copyWith(
          isBusy: false,
          statusMessage: '서버 대화 반영에 실패했습니다.',
        );
        return;
      }
    }

    final stats = activePet.stats.add(rewardStats);
    final level = _growthEngine.levelFor(stats);

    state = state.copyWith(
      pets: _replacePet(
        activePet.copyWith(
          stats: stats,
          level: level,
          stage: _growthEngine.stageFor(
            level: level,
            stats: stats,
            currentStage: activePet.stage,
          ),
          lastInteractedAt: now,
        ),
      ),
      dialogueCountToday: resetCount + 1,
      dialogueDay: now,
      isBusy: false,
      statusMessage: line.text,
    );
  }

  Future<void> feedActivePet() async {
    final activePet = state.activePet;
    if (activePet == null) {
      state = state.copyWith(statusMessage: '먹이를 줄 마실펫이 없습니다.');
      return;
    }

    final now = DateTime.now();
    const rewardStats = GrowthStats(exp: 3, mood: 8, knowledge: 0, affinity: 2);
    final backend = _backend;

    if (backend != null) {
      state = state.copyWith(isBusy: true, statusMessage: '${activePet.name} 먹이주기를 서버에 반영하는 중입니다.');
      try {
        await backend.interactWithPet(petId: activePet.id, actionType: 'feed');
      } on Object {
        state = state.copyWith(
          isBusy: false,
          statusMessage: '서버 먹이주기 반영에 실패했습니다.',
        );
        return;
      }
    }

    final stats = activePet.stats.add(rewardStats);
    final level = _growthEngine.levelFor(stats);
    final updated = activePet.copyWith(
      stats: stats,
      level: level,
      stage: _growthEngine.stageFor(
        level: level,
        stats: stats,
        currentStage: activePet.stage,
      ),
      lastInteractedAt: now,
    );

    state = state.copyWith(
      pets: _replacePet(updated),
      isBusy: false,
      statusMessage: '${activePet.name}의 기분이 좋아졌습니다.',
    );
  }

  PetTemplate templateFor(String templateId) {
    return state.templates.firstWhere((template) => template.id == templateId);
  }

  List<Pet> _applyRewardToActivePet(GrowthStats reward, DateTime now) {
    final activePet = state.activePet;
    if (activePet == null) {
      return state.pets;
    }

    final stats = activePet.stats.add(reward);
    final level = _growthEngine.levelFor(stats);
    final stage = _growthEngine.stageFor(
      level: level,
      stats: stats,
      currentStage: activePet.stage,
    );

    return _replacePet(
      activePet.copyWith(
        stats: stats,
        level: level,
        stage: stage,
        lastInteractedAt: now,
      ),
    );
  }

  List<Pet> _replacePet(Pet updated) {
    return state.pets.map((pet) => pet.id == updated.id ? updated : pet).toList();
  }

  List<Egg> _maybeDropEgg(List<Egg> currentEggs, Poi poi, DateTime now) {
    final hasOpenEgg = currentEggs.any((egg) => egg.status != EggStatus.hatched);
    if (hasOpenEgg) {
      return currentEggs;
    }

    final firstCheckInToday = state.todayCheckInCount == 0;
    final rareCategory = poi.category == PoiCategory.history || poi.category == PoiCategory.festival;
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
