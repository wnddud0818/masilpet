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
import 'package:masilpet/src/state.dart';
import 'package:masilpet/src/widgets/metric_grid.dart';
import 'package:masilpet/src/widgets/pet_play_field.dart';

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

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '진행도 초기화'));
    await tester.pumpAndSettle();

    expect(find.text('진행도 초기화'), findsWidgets);
    expect(find.textContaining('되돌릴 수 없습니다'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '초기화'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.textContaining('되돌릴 수 없습니다'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
