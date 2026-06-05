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
import 'package:masilpet/src/seed_data.dart';
import 'package:masilpet/src/services.dart';
import 'package:masilpet/src/state.dart';
import 'package:masilpet/src/widgets/metric_grid.dart';
import 'package:masilpet/src/widgets/pet_play_field.dart';
import 'package:masilpet/src/widgets/status_banner.dart';

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

  testWidgets('profile explains data and map provenance',
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

    await tester.ensureVisible(find.text('데이터·지도 출처'));
    await tester.pump();

    expect(find.text('데이터·지도 출처'), findsOneWidget);
    expect(find.text('TourAPI 지역 장소'), findsOneWidget);
    expect(find.text('OpenStreetMap 지도'), findsOneWidget);
    expect(find.text('Firebase Functions 검증'), findsOneWidget);
    expect(
      find.text('150m 체크인, 중복 방지, 보상 지급을 서버에서 처리합니다.'),
      findsOneWidget,
    );
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

  testWidgets('profile visit journal links an empty record to map',
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

    final journalAction = find.widgetWithText(OutlinedButton, '지도에서 체크인하기');
    expect(find.text('방문 기록'), findsOneWidget);
    expect(find.textContaining('아직 기록된 체크인'), findsOneWidget);
    expect(journalAction, findsOneWidget);

    await tester.ensureVisible(journalAction);
    await tester.pump();
    await tester.tap(journalAction);
    await tester.pump();

    expect(controller.state.selectedTab, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile visit journal shows recent check-in detail',
      (WidgetTester tester) async {
    final controller = MasilPetController(
      firebaseReady: false,
      firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      localProgressRepository: null,
    )..setTab(4);
    controller.state = controller.state.copyWith(
      checkIns: [
        CheckIn(
          id: 'checkin-visit-journal',
          poiId: busanPoiSeed.first.id,
          regionId: busanPoiSeed.first.regionId,
          category: busanPoiSeed.first.category,
          createdAt: DateTime.now(),
          distanceMeters: 12,
          rewardApplied: true,
          reward: const CheckInReward(
            stats: GrowthStats(exp: 33, mood: 4, knowledge: 5, affinity: 6),
            eggProgress: 77,
          ),
        ),
      ],
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
        child: const MaterialApp(
          home: Scaffold(
            body: ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('방문 기록'), findsOneWidget);
    expect(find.text('1회'), findsWidgets);
    expect(find.text(busanPoiSeed.first.title), findsOneWidget);
    expect(find.text(busanPoiSeed.first.category.label), findsOneWidget);
    expect(find.textContaining('12m · 보상 적용'), findsOneWidget);
    expect(find.textContaining('12m'), findsOneWidget);
    expect(find.textContaining('보상 적용'), findsOneWidget);
    expect(find.text('EXP +33'), findsOneWidget);
    expect(find.text('기분 +4'), findsOneWidget);
    expect(find.text('지식 +5'), findsOneWidget);
    expect(find.text('친밀도 +6'), findsOneWidget);
    expect(find.text('알 +77'), findsOneWidget);
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

  testWidgets('status banner shows full detailed reward on phone width',
      (WidgetTester tester) async {
    final controller = MasilPetController(
      firebaseReady: false,
      firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      localProgressRepository: null,
    );
    const message =
        '해운대 해수욕장 체크인 완료: EXP +18 · 기분 +8 · 지식 +4 · 친밀도 +12 · 알 +680';
    controller.state = controller.state.copyWith(statusMessage: message);
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: StatusBanner(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(find.text(message));
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
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

  testWidgets('map poi cards show full growth reward breakdown',
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
      pois: [busanPoiSeed.first],
    );
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
        child: const MaterialApp(home: Scaffold(body: MapScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('해운대 해수욕장'), findsOneWidget);
    expect(find.text('EXP +18'), findsOneWidget);
    expect(find.text('기분 +8'), findsOneWidget);
    expect(find.text('지식 +4'), findsOneWidget);
    expect(find.text('친밀도 +12'), findsOneWidget);
    expect(find.text('알 +680'), findsWidgets);
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

  testWidgets('map screen shows a daily walking route guide',
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

    expect(find.text('오늘의 산책 루트'), findsOneWidget);
    expect(find.text('위치 확인'), findsOneWidget);
    expect(find.text('첫 체크인'), findsOneWidget);
    expect(find.text('마실펫 교감'), findsOneWidget);
    expect(find.text('알 부화 준비'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '현재 위치 확인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map route guide explains the recommended place',
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

    expect(find.text('오늘 새 카테고리'), findsOneWidget);
    expect(find.text('알 +680'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map route guide checks in the in-range recommendation',
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
      pois: [busanPoiSeed.first],
      currentLocation: busanPoiSeed.first.coordinates,
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

    final checkInAction = find.widgetWithText(TextButton, '추천 장소 체크인하기');
    expect(find.text('지금 체크인 가능'), findsOneWidget);
    expect(checkInAction, findsOneWidget);

    await tester.ensureVisible(checkInAction);
    await tester.pump();
    await tester.tap(checkInAction);
    await tester.pump();

    expect(controller.state.todayCheckInCount, 1);
    expect(controller.state.todayCheckIns.single.poiId, busanPoiSeed.first.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map route guide marks completed recommendations as visited',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final controller = MasilPetController(
      firebaseReady: false,
      firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      localProgressRepository: null,
    );
    controller.state = controller.state.copyWith(
      pois: [busanPoiSeed.first],
      currentLocation: busanPoiSeed.first.coordinates,
      locationVerified: true,
      locationVerifiedAt: now,
      checkIns: [
        CheckIn(
          id: 'checkin-complete',
          poiId: busanPoiSeed.first.id,
          regionId: busanPoiSeed.first.regionId,
          category: busanPoiSeed.first.category,
          createdAt: now,
          distanceMeters: 12,
          rewardApplied: true,
        ),
      ],
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

    expect(find.text('오늘 방문 완료'), findsOneWidget);
    expect(find.textContaining('오늘 방문 가능한 POI를 모두 기록'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map route guide links completed check-in to pet care',
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
      currentLocation: busanPoiSeed.first.coordinates,
      locationVerified: true,
      locationVerifiedAt: DateTime.now(),
      checkIns: [
        CheckIn(
          id: 'checkin-test',
          poiId: busanPoiSeed.first.id,
          regionId: busanPoiSeed.first.regionId,
          category: busanPoiSeed.first.category,
          createdAt: DateTime.now(),
          distanceMeters: 10,
          rewardApplied: true,
        ),
      ],
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

    final petCareAction = find.widgetWithText(TextButton, '마실펫과 대화하기');
    expect(find.text('오늘의 산책 루트'), findsOneWidget);
    expect(petCareAction, findsOneWidget);

    await tester.ensureVisible(petCareAction);
    await tester.pump();
    await tester.tap(petCareAction);
    await tester.pump();

    expect(controller.state.selectedTab, 1);
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
    expect(find.text('도감 수집률'), findsOneWidget);
    expect(eggsTopLeft.dx, greaterThan(petsTopLeft.dx));
    expect((eggsTopLeft.dy - petsTopLeft.dy).abs(), lessThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('house care plan links daily actions to map and pet care',
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

    final mapAction = find.widgetWithText(FilledButton, '지도에서 걸음 모으기');
    final petAction = find.widgetWithText(OutlinedButton, '마실펫 돌보기');
    expect(find.text('오늘의 하우스 플랜'), findsOneWidget);
    expect(find.text('대표 펫'), findsOneWidget);
    expect(find.text('집중 부화 알'), findsOneWidget);
    expect(find.text('다음 외출'), findsOneWidget);
    expect(find.textContaining('일반'), findsWidgets);
    expect(find.textContaining('common'), findsNothing);
    expect(mapAction, findsOneWidget);
    expect(petAction, findsOneWidget);

    await tester.ensureVisible(petAction);
    await tester.pump();
    await tester.tap(petAction);
    await tester.pump();

    expect(controller.state.selectedTab, 1);

    await tester.tap(mapAction);
    await tester.pump();

    expect(controller.state.selectedTab, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('house care plan hatches a ready egg from the summary card',
      (WidgetTester tester) async {
    final controller = MasilPetController(
      firebaseReady: false,
      firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      localProgressRepository: null,
    )..setTab(2);
    final egg = controller.state.eggs.first;
    controller.state = controller.state.copyWith(
      eggs: [
        egg.copyWith(
          progress: egg.requiredSteps,
          status: EggStatus.hatchable,
        ),
      ],
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

    final hatchAction = find.widgetWithText(FilledButton, '지금 부화하기');
    expect(find.textContaining('하우스에서 바로 부화'), findsOneWidget);
    expect(hatchAction, findsOneWidget);

    await tester.ensureVisible(hatchAction);
    await tester.pump();
    await tester.tap(hatchAction);
    await tester.pump();

    expect(controller.state.eggs, isEmpty);
    expect(
      controller.state.pets.where((pet) => pet.templateId == egg.templateId),
      isNotEmpty,
    );
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

    final representativeAction = find.widgetWithText(OutlinedButton, '대표 설정');
    expect(find.text('대표'), findsOneWidget);
    expect(representativeAction, findsOneWidget);

    await tester.ensureVisible(representativeAction);
    await tester.pump();
    await tester.tap(representativeAction);
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

    final checkInAction = find.widgetWithText(TextButton, '지도에서 체크인하기');
    expect(find.widgetWithText(OutlinedButton, '걸음 필요'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '부화'), findsNothing);
    expect(checkInAction, findsOneWidget);
    expect(find.textContaining('걸음 남음'), findsWidgets);
    expect(find.textContaining('자갈치시장 · 음식 보상 알 +620'), findsOneWidget);
    expect(find.textContaining('부화 진행도'), findsOneWidget);

    await tester.ensureVisible(checkInAction);
    await tester.pump();
    await tester.tap(checkInAction);
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
    expect(find.text('다음 발견 후보'), findsOneWidget);
    expect(find.textContaining('항구마루 · 음식 카테고리'), findsOneWidget);
    expect(find.textContaining('자갈치시장 · 음식'), findsOneWidget);
    expect(find.text('알 +620'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '지도에서 탐험하기'), findsOneWidget);

    final categoryAction = find.widgetWithText(OutlinedButton, '지도에서 음식 장소 찾기');
    expect(categoryAction, findsOneWidget);

    await tester.ensureVisible(categoryAction);
    await tester.pump();
    await tester.tap(categoryAction);
    await tester.pump();

    expect(controller.state.selectedTab, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dex screen shows a regional passport and links to map',
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

    final nextStampAction = find.widgetWithText(TextButton, '다음 스탬프 찾기');
    expect(find.text('부산 탐험 여권'), findsOneWidget);
    expect(find.text('파도나루'), findsWidgets);
    expect(find.text('일반'), findsWidgets);
    expect(find.textContaining('common'), findsNothing);
    expect(find.text('스탬프 대기'), findsWidgets);
    expect(nextStampAction, findsOneWidget);

    await tester.ensureVisible(nextStampAction);
    await tester.pump();
    await tester.tap(nextStampAction);
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
    expect(find.text('기기 내 진행 모드'), findsOneWidget);
    expect(find.textContaining('Firebase Web 설정값'), findsOneWidget);
    expect(find.byIcon(Icons.storage_outlined), findsOneWidget);
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

  testWidgets('reset progress returns to a visible onboarding story',
      (WidgetTester tester) async {
    final controller = MasilPetController(
      firebaseReady: false,
      firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
      locationService: const DeviceLocationService(),
      backend: null,
      userRepository: null,
      localProgressRepository: null,
    )..completeOnboarding();
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
        child: const MasilPetApp(),
      ),
    );
    await tester.pump();

    await controller.resetProgress();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final startButton =
        find.widgetWithIcon(FilledButton, Icons.play_arrow_rounded);
    expect(find.text('MasilPet'), findsOneWidget);
    expect(find.text('TourAPI 기반 지역 탐험'), findsOneWidget);
    expect(startButton, findsOneWidget);
    expect(
      tester.getTopLeft(find.text('MasilPet')).dy,
      lessThan(tester.getTopLeft(startButton).dy),
    );
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
