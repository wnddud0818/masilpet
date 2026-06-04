import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masilpet/src/app.dart';
import 'package:masilpet/src/screens/dex_screen.dart';
import 'package:masilpet/src/screens/home_shell.dart';
import 'package:masilpet/src/screens/house_screen.dart';
import 'package:masilpet/src/screens/map_screen.dart';
import 'package:masilpet/src/screens/onboarding_screen.dart';
import 'package:masilpet/src/screens/pet_screen.dart';
import 'package:masilpet/src/screens/profile_screen.dart';
import 'package:masilpet/src/models.dart';
import 'package:masilpet/src/services.dart';
import 'package:masilpet/src/state.dart';
import 'package:masilpet/src/widgets/metric_grid.dart';
import 'package:masilpet/src/widgets/pet_play_field.dart';

class _EmptyPetController extends MasilPetController {
  _EmptyPetController()
      : super(
          firebaseReady: false,
          firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
          locationService: const DeviceLocationService(),
          backend: null,
          userRepository: null,
          localProgressRepository: null,
        ) {
    state = state.copyWith(
      pets: const [],
      activePetId: '',
    );
  }
}

void main() {
  testWidgets('MasilPet app starts with local progress fallback',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MasilPetApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MasilPetApp), findsOneWidget);
    expect(find.textContaining('Firebase Web 설정값'), findsOneWidget);
  });

  testWidgets('profile release diagnostics fit on phone width',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('앱 버전'), findsOneWidget);
    expect(find.text('local-dev'), findsOneWidget);
    expect(find.text('빌드 채널'), findsOneWidget);
    expect(find.text('local'), findsOneWidget);
    expect(find.text('빌드 시각'), findsOneWidget);
    expect(find.text('local build'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile quick actions adapt on narrow phones',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('빠른 작업'), findsOneWidget);
    expect(find.text('현재 위치 사용'), findsOneWidget);
    expect(find.text('해운대 지도 보기'), findsOneWidget);
    expect(find.text('새로고침'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile readiness links missing check-in to map',
      (WidgetTester tester) async {
    final controller = MasilPetController(
      firebaseReady: false,
      firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      localProgressRepository: null,
    )..setTab(4);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    final checkInAction = find.widgetWithText(TextButton, '지도에서 체크인하기');
    expect(find.text('탐험 준비 상태'), findsOneWidget);
    expect(checkInAction, findsOneWidget);
    expect(tester.widget<TextButton>(checkInAction).onPressed, isNotNull);

    await tester.tap(checkInAction);
    await tester.pump();

    expect(controller.state.selectedTab, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile screen pairs diagnostics and actions on desktop width',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    final readinessTopLeft =
        tester.getTopLeft(find.byIcon(Icons.rocket_launch_outlined));
    final locationActionTopLeft =
        tester.getTopLeft(find.byIcon(Icons.my_location));
    expect(locationActionTopLeft.dx, greaterThan(readinessTopLeft.dx));
    expect(
        (locationActionTopLeft.dy - readinessTopLeft.dy).abs(), lessThan(160));
    expect(tester.takeException(), isNull);
  });

  testWidgets('metric summaries wrap on narrow phones',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: MetricGrid(
                  items: [
                    MetricGridItem(
                      icon: Icons.check_circle_outline,
                      label: '체크인 가능',
                      value: '3곳',
                    ),
                    MetricGridItem(
                      icon: Icons.flag_outlined,
                      label: '오늘 체크인',
                      value: '1회',
                    ),
                    MetricGridItem(
                      icon: Icons.near_me_outlined,
                      label: '가장 가까운 곳',
                      value: '120m',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('체크인 가능'), findsOneWidget);
    expect(find.text('오늘 체크인'), findsOneWidget);
    expect(find.text('가장 가까운 곳'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('가장 가까운 곳')).dy,
      greaterThan(tester.getTopLeft(find.text('체크인 가능')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shell keeps bottom navigation on phone width',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shell uses navigation rail on desktop width',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pump();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(find.byType(NavigationBar), findsNothing);
    expect(rail.extended, isTrue);
    expect(rail.destinations, hasLength(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('map screen pairs map and POI list on desktop width',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MapScreen())),
      ),
    );
    await tester.pump();

    final mapTopLeft = tester.getTopLeft(find.byType(FlutterMap));
    final poiTitleTopLeft = tester.getTopLeft(find.text('가까운 POI'));
    expect(poiTitleTopLeft.dx, greaterThan(mapTopLeft.dx));
    expect((poiTitleTopLeft.dy - mapTopLeft.dy).abs(), lessThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('map screen offers location confirmation when check-in is locked',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MapScreen())),
      ),
    );
    await tester.pump();

    final briefingAction = find.widgetWithText(OutlinedButton, '현재 위치 확인');
    expect(briefingAction, findsOneWidget);
    expect(tester.widget<OutlinedButton>(briefingAction).onPressed, isNotNull);
    expect(find.widgetWithText(FilledButton, '현재 위치 확인'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'map screen lets users refresh location when outside check-in range',
      (WidgetTester tester) async {
    final controller = MasilPetController(
      firebaseReady: false,
      firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      localProgressRepository: null,
    );
    controller.state = controller.state.copyWith(
      currentLocation:
          const Coordinates(latitude: 35.1796, longitude: 129.0756),
      locationVerified: true,
      locationVerifiedAt: DateTime.now(),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MapScreen())),
      ),
    );
    await tester.pump();

    final refreshAction = find.widgetWithText(FilledButton, '현재 위치 다시 확인');
    expect(refreshAction, findsWidgets);
    final firstRefreshButton =
        tester.widgetList<FilledButton>(refreshAction).first;
    expect(firstRefreshButton.onPressed, isNotNull);
    expect(find.widgetWithText(FilledButton, '150m 안에서 가능'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map screen empty POI state offers location refresh',
      (WidgetTester tester) async {
    final controller = MasilPetController(
      firebaseReady: false,
      firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      localProgressRepository: null,
    );
    controller.state = controller.state.copyWith(pois: const []);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MapScreen())),
      ),
    );
    await tester.pump();

    final emptyAction = find.widgetWithText(OutlinedButton, '현재 위치 다시 확인');
    expect(find.text('근처 POI가 없습니다'), findsOneWidget);
    expect(emptyAction, findsOneWidget);
    expect(tester.widget<OutlinedButton>(emptyAction).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet screen pairs play field and care details on desktop width',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: PetScreen())),
      ),
    );
    await tester.pump();

    final fieldTopLeft = tester.getTopLeft(find.byType(PetPlayField));
    final routineTopLeft = tester.getTopLeft(find.text('오늘의 돌봄 루틴'));
    expect(routineTopLeft.dx, greaterThan(fieldTopLeft.dx));
    expect((routineTopLeft.dy - fieldTopLeft.dy).abs(), lessThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet stage goal links growth to map exploration',
      (WidgetTester tester) async {
    final controller = MasilPetController(
      firebaseReady: false,
      firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      localProgressRepository: null,
    )..setTab(1);
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: PetScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('성장 단계'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '지도에서 성장 보상 얻기'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '지도에서 성장 보상 얻기'));
    await tester.pump();

    expect(controller.state.selectedTab, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet screen disables talk action after daily limit',
      (WidgetTester tester) async {
    final controller = MasilPetController(
      firebaseReady: false,
      firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      localProgressRepository: null,
    );
    controller.state = controller.state.copyWith(
      dialogueCountToday: 5,
      dialogueDay: DateTime.now(),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: PetScreen())),
      ),
    );
    await tester.pump();

    final doneTalkAction = find.widgetWithText(FilledButton, '대화 완료');
    expect(find.text('대화 가능'), findsOneWidget);
    expect(find.text('0회'), findsOneWidget);
    expect(doneTalkAction, findsOneWidget);
    expect(tester.widget<FilledButton>(doneTalkAction).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet screen hides care actions when no active pet is available',
      (WidgetTester tester) async {
    final controller = _EmptyPetController();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: PetScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('아직 함께할 마실펫이 없습니다'), findsOneWidget);
    expect(find.textContaining('하우스에서 알 상태를 확인'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '하우스에서 알 보기'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '대화'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '먹이주기'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '하우스에서 알 보기'));
    await tester.pump();

    expect(controller.state.selectedTab, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('house screen pairs pets and eggs on desktop width',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: HouseScreen())),
      ),
    );
    await tester.pump();

    final petsTopLeft = tester.getTopLeft(find.text('보유 마실펫'));
    final eggsTopLeft = tester.getTopLeft(find.text('알'));
    expect(eggsTopLeft.dx, greaterThan(petsTopLeft.dx));
    expect((eggsTopLeft.dy - petsTopLeft.dy).abs(), lessThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('house screen makes representative pet selection explicit',
      (WidgetTester tester) async {
    final controller = MasilPetController(
      firebaseReady: false,
      firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      localProgressRepository: null,
    );
    final firstPet = controller.state.pets.first;
    final secondTemplate = controller.state.templates[1];
    final secondPet = Pet(
      id: 'pet-test-${secondTemplate.id}',
      templateId: secondTemplate.id,
      name: secondTemplate.name,
      stage: PetStage.baby,
      level: 1,
      stats: const GrowthStats(
        exp: 10,
        mood: 12,
        knowledge: 4,
        affinity: 7,
      ),
      originRegionId: secondTemplate.regionId,
      hatchedAt: DateTime(2026, 1, 1),
      lastInteractedAt: null,
    );
    controller.state = controller.state.copyWith(
      pets: [firstPet, secondPet],
      activePetId: firstPet.id,
    );

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: HouseScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('대표'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '대표 설정'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '대표 설정'));
    await tester.pump();

    expect(controller.state.activePetId, secondPet.id);
    expect(find.text('대표'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('house screen labels locked eggs as needing more steps',
      (WidgetTester tester) async {
    final controller = MasilPetController(
      firebaseReady: false,
      firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      localProgressRepository: null,
    )..setTab(2);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: HouseScreen())),
      ),
    );
    await tester.pump();

    expect(find.widgetWithText(OutlinedButton, '걸음 필요'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '부화'), findsNothing);
    expect(find.widgetWithText(TextButton, '지도에서 체크인하기'), findsOneWidget);
    expect(find.textContaining('걸음 남음'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '지도에서 체크인하기'));
    await tester.pump();

    expect(controller.state.selectedTab, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'dex screen pairs collection and TourAPI mapping on desktop width',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DexScreen())),
      ),
    );
    await tester.pump();

    final collectionTopLeft = tester.getTopLeft(find.text('수집한 마실펫'));
    final mappingTopLeft = tester.getTopLeft(find.text('TourAPI 카테고리 매핑'));
    expect(mappingTopLeft.dx, greaterThan(collectionTopLeft.dx));
    expect((mappingTopLeft.dy - collectionTopLeft.dy).abs(), lessThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dex screen marks undiscovered pets as exploration goals',
      (WidgetTester tester) async {
    final controller = MasilPetController(
      firebaseReady: false,
      firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      localProgressRepository: null,
    )..setTab(3);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DexScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('탐험 필요'), findsWidgets);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, '지도에서 탐험하기'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '지도에서 탐험하기'));
    await tester.pump();

    expect(controller.state.selectedTab, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dex screen empty TourAPI mapping links back to map',
      (WidgetTester tester) async {
    final controller = MasilPetController(
      firebaseReady: false,
      firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      localProgressRepository: null,
    )..setTab(3);
    controller.state = controller.state.copyWith(pois: const []);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith(
            (ref) => controller,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DexScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('TourAPI 장소 데이터가 없습니다'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '지도에서 다시 조회'), findsOneWidget);

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, '지도에서 다시 조회'),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, '지도에서 다시 조회'));
    await tester.pump();

    expect(controller.state.selectedTab, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding primary action stays visible on phone width',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump();

    final startButton =
        find.widgetWithIcon(FilledButton, Icons.play_arrow_rounded);
    expect(startButton, findsOneWidget);
    expect(tester.getRect(startButton).bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding pairs story and play field on desktop width',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump();

    final titleTopLeft = tester.getTopLeft(find.text('MasilPet'));
    final fieldTopLeft = tester.getTopLeft(find.byType(PetPlayField));
    final startButton =
        find.widgetWithIcon(FilledButton, Icons.play_arrow_rounded);
    expect(fieldTopLeft.dx, greaterThan(titleTopLeft.dx));
    expect((fieldTopLeft.dy - titleTopLeft.dy).abs(), lessThan(80));
    expect(tester.getRect(startButton).width, lessThanOrEqualTo(430));
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection screens expose clear sections on phone width',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: HouseScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('보유 마실펫'), findsOneWidget);
    expect(find.text('알'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DexScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('수집한 마실펫'), findsOneWidget);
    expect(find.text('TourAPI 카테고리 매핑'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile reset action requires confirmation',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    final resetAction = find.widgetWithText(OutlinedButton, '진행도 초기화');
    await tester.ensureVisible(resetAction);
    await tester.pumpAndSettle();
    await tester.tap(resetAction);
    await tester.pumpAndSettle();

    expect(find.text('진행도 초기화'), findsWidgets);
    expect(find.textContaining('되돌릴 수 없습니다'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '초기화'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.textContaining('되돌릴 수 없습니다'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
