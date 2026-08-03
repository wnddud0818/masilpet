import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masilpet/src/app.dart';
import 'package:masilpet/src/models.dart';
import 'package:masilpet/src/screens/dex_screen.dart';
import 'package:masilpet/src/screens/home_shell.dart';
import 'package:masilpet/src/screens/house_screen.dart';
import 'package:masilpet/src/screens/map_screen.dart';
import 'package:masilpet/src/screens/onboarding_screen.dart';
import 'package:masilpet/src/screens/pet_screen.dart';
import 'package:masilpet/src/screens/profile_screen.dart';
import 'package:masilpet/src/seed_data.dart';
import 'package:masilpet/src/services.dart';
import 'package:masilpet/src/state.dart';
import 'package:masilpet/src/theme.dart';
import 'package:masilpet/src/widgets/metric_grid.dart';
import 'package:masilpet/src/widgets/paper_kit.dart';
import 'package:masilpet/src/widgets/paper_shell.dart';
import 'package:masilpet/src/widgets/pet_detail_sheet.dart';
import 'package:masilpet/src/widgets/pet_play_field.dart';
import 'package:masilpet/src/widgets/status_banner.dart';

/// A controller with no pets, for the empty states.
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

MasilPetController _controller() {
  return MasilPetController(
    firebaseReady: false,
    firebaseStartupIssue: FirebaseStartupIssue.missingWebConfiguration,
    locationService: const DeviceLocationService(),
    backend: null,
    userRepository: null,
    localProgressRepository: null,
  );
}

/// Wraps a screen the way the shell does, minus the shell chrome, so tests can
/// exercise one tab at a time.
Widget _hostScreen(MasilPetController controller, Widget screen) {
  return ProviderScope(
    overrides: [
      masilPetControllerProvider.overrideWith((ref) => controller),
    ],
    child: MaterialApp(
      theme: buildMasilPetTheme(),
      home: Scaffold(body: screen),
    ),
  );
}

void _sizeView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

const _phone = Size(390, 844);
const _narrowPhone = Size(320, 740);
const _desktop = Size(1180, 820);
const _wideShort = Size(900, 360);

/// Both the pet stage and the map pins animate forever, so `pumpAndSettle`
/// would never return. Advance a fixed slice instead.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Matches a widget that annotates its subtree with exactly this label.
Finder _semanticsLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
    description: 'Semantics(label: "$label")',
  );
}

/// A verified visit drops the stamp overlay, which holds for 1.4s.
Future<void> _settleStamp(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
}

/// The clipboard has no platform implementation under `flutter_test`.
void _stubClipboard(WidgetTester tester) {
  final clipboard = <String, Object?>{};
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboard.addAll((call.arguments as Map).cast<String, Object?>());
          return null;
        case 'Clipboard.getData':
          return clipboard;
        default:
          return null;
      }
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
}

/// Verifies a location so in-range check-in paths become reachable.
void _verifyLocationAt(MasilPetController controller, Poi poi) {
  final now = DateTime.now();
  controller.state = controller.state.copyWith(
    currentLocation: poi.coordinates,
    locationVerified: true,
    locationVerifiedAt: now,
  );
}

CheckIn _checkIn({
  required Poi poi,
  DateTime? at,
  double distanceMeters = 12,
  CheckInReward? reward,
}) {
  return CheckIn(
    id: 'checkin-${poi.id}',
    poiId: poi.id,
    regionId: poi.regionId,
    category: poi.category,
    createdAt: at ?? DateTime.now(),
    distanceMeters: distanceMeters,
    rewardApplied: true,
    reward: reward,
  );
}

void main() {
  // ───────────────────────────────────────────────────────── app & onboarding ──

  testWidgets('MasilPet app starts with local progress fallback',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    _sizeView(tester, _phone);

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
    await _settle(tester);

    expect(find.byType(MasilPetApp), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('마실펫'), findsWidgets);
    expect(find.text('걸으면 만나고,\n만나면 자라요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding walks three steps and hands over location',
      (WidgetTester tester) async {
    final controller = _controller();
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const OnboardingScreen()));
    await _settle(tester);

    // Step 1 — meet the companion.
    expect(find.text('안녕! 나 해랑이야.\n여기서 계속 너 기다리고 있었어.'), findsOneWidget);
    await tester.tap(find.text('해랑이 만나기'));
    await _settle(tester);

    // Step 2 — learn the loop.
    expect(find.text('세 걸음이면 충분해'), findsOneWidget);
    expect(find.text('동네를 걷고'), findsOneWidget);
    expect(find.text('주변 150m 안 산책지가 수첩에 떠요'), findsOneWidget);
    expect(find.text('57마리가 전국에서 너를 기다려요'), findsOneWidget);
    await tester.tap(find.text('좋아, 알겠어'));
    await _settle(tester);

    // Step 3 — location, and why progress stays local.
    expect(find.text('어디를 걷는지\n알아야 도장을 찍어'), findsOneWidget);
    expect(
      find.text('Firebase 앱 설정값이 없어 기기 내 진행으로 시작해요.'),
      findsOneWidget,
    );
    expect(find.text('언제든 수첩에서 전체 기록을 지울 수 있어요'), findsOneWidget);

    await tester.tap(find.text('허용하고 시작하기'));
    await _settle(tester);

    expect(controller.state.onboardingComplete, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding primary action stays visible on phone width',
      (WidgetTester tester) async {
    final controller = _controller();
    _sizeView(tester, _narrowPhone);

    await tester.pumpWidget(_hostScreen(controller, const OnboardingScreen()));
    await _settle(tester);

    final cta = find.text('해랑이 만나기');
    expect(cta, findsOneWidget);

    final ctaBottom = tester.getBottomLeft(cta).dy;
    expect(ctaBottom, lessThanOrEqualTo(_narrowPhone.height));
    expect(find.text('건너뛰기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding skip completes immediately',
      (WidgetTester tester) async {
    final controller = _controller();
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const OnboardingScreen()));
    await _settle(tester);

    await tester.tap(find.text('건너뛰기'));
    await _settle(tester);

    expect(controller.state.onboardingComplete, isTrue);
    expect(tester.takeException(), isNull);
  });

  // ─────────────────────────────────────────────────────────────────── shell ──

  testWidgets('home shell keeps the paper tab bar on phone width',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    _sizeView(tester, _phone);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: MaterialApp(
          theme: buildMasilPetTheme(),
          home: const HomeShell(),
        ),
      ),
    );
    await _settle(tester);

    expect(find.byType(PaperTabBar), findsOneWidget);
    expect(find.byType(PaperNavRail), findsNothing);
    for (final label in const ['지도', '하우스', '마실펫', '도감', '기록']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shell uses the side rail on desktop width',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    _sizeView(tester, _desktop);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          firebaseStartupIssueProvider.overrideWithValue(
            FirebaseStartupIssue.missingWebConfiguration,
          ),
        ],
        child: MaterialApp(
          theme: buildMasilPetTheme(),
          home: const HomeShell(),
        ),
      ),
    );
    await _settle(tester);

    expect(find.byType(PaperNavRail), findsOneWidget);
    expect(find.byType(PaperTabBar), findsNothing);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('05'), findsOneWidget);
    expect(find.text('연속 산책'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home shell side rail scrolls its nav items on a wide but short viewport '
    'instead of overflowing',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      _sizeView(tester, _wideShort);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseReadyProvider.overrideWithValue(false),
            firebaseStartupIssueProvider.overrideWithValue(
              FirebaseStartupIssue.missingWebConfiguration,
            ),
          ],
          child: MaterialApp(
            theme: buildMasilPetTheme(),
            home: const HomeShell(),
          ),
        ),
      );
      await _settle(tester);

      expect(find.byType(PaperNavRail), findsOneWidget);
      expect(find.text('연속 산책'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home shell header names the page and the day',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    _sizeView(tester, _phone);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: buildMasilPetTheme(),
          home: const HomeShell(),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('오늘의 산책'), findsOneWidget);
    expect(find.textContaining('대한민국'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shell switches tabs from the tab bar',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    _sizeView(tester, _phone);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: buildMasilPetTheme(),
          home: const HomeShell(),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(PaperTabBar),
        matching: find.text('도감'),
      ),
    );
    await _settle(tester);

    expect(controller.state.selectedTab, 3);
    expect(find.text('전국 도감'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shell surfaces progress badges on the tab bar',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    final poi = starterPoiSeed.first;
    _verifyLocationAt(controller, poi);
    controller.state = controller.state.copyWith(
      checkIns: [_checkIn(poi: poi)],
      dialogueCountToday: 1,
      dialogueDay: DateTime.now(),
    );
    _sizeView(tester, _phone);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: buildMasilPetTheme(),
          home: const HomeShell(),
        ),
      ),
    );
    await _settle(tester);

    final tabBar = find.byType(PaperTabBar);
    // 4 talks left, 1 egg, 56 undiscovered, 1 day streak.
    expect(
      find.descendant(of: tabBar, matching: find.text('4')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tabBar, matching: find.text('56')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  // ─────────────────────────────────────────────────────────── status banner ──

  testWidgets('status banner shows full detailed reward on phone width',
      (WidgetTester tester) async {
    final controller = _controller();
    const message =
        '해운대 해수욕장 체크인 완료: EXP +18 · 기분 +8 · 지식 +4 · 친밀도 +12 · 알 +680';
    controller.state = controller.state.copyWith(statusMessage: message);
    _sizeView(tester, _narrowPhone);

    await tester.pumpWidget(
      _hostScreen(
        controller,
        const Padding(padding: EdgeInsets.all(16), child: StatusBanner()),
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(find.text(message));
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status banner gives success and failure distinct tone labels',
      (WidgetTester tester) async {
    final controller = _controller();
    controller.state = controller.state.copyWith(
      statusMessage: '해운대 해수욕장 체크인 완료: EXP +18 · 알 +680',
    );

    await tester.pumpWidget(
      _hostScreen(
        controller,
        const Padding(padding: EdgeInsets.all(16), child: StatusBanner()),
      ),
    );
    await tester.pump();

    expect(find.text('완료'), findsOneWidget);
    expect(find.text('실패'), findsNothing);

    controller.state = controller.state.copyWith(
      statusMessage: '위치 권한이 거부됐어요.',
    );
    await tester.pump();

    expect(find.text('실패'), findsOneWidget);
    expect(find.text('완료'), findsNothing);

    controller.state = controller.state.copyWith(
      statusMessage: 'Firebase Web 설정값이 없어 기기 내 진행으로 시작해요.',
    );
    await tester.pump();

    expect(find.text('이 기기에 저장'), findsOneWidget);
    expect(find.text('완료'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('metric summaries wrap on narrow phones',
      (WidgetTester tester) async {
    _sizeView(tester, _narrowPhone);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildMasilPetTheme(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: MetricGrid(
              items: [
                MetricGridItem(label: '체크인 가능', value: '3곳'),
                MetricGridItem(label: '오늘 체크인', value: '1회'),
                MetricGridItem(label: '가장 가까운 곳', value: '120m'),
              ],
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

  // ───────────────────────────────────────────────────────────────────── map ──

  testWidgets('map screen frames the live map with paper chrome',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('대한민국 · 산책지 ${starterPoiSeed.length}곳'), findsOneWidget);
    expect(find.text('위치 미확인'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(find.text('주변 산책지'), findsOneWidget);
    expect(find.text('위치 새로고침'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map frame grows on desktop width', (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    _sizeView(tester, _desktop);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    final box = tester.widget<SizedBox>(
      find
          .ancestor(
              of: find.byType(FlutterMap), matching: find.byType(SizedBox))
          .first,
    );
    expect(box.height, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map frame stays compact on phone width',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    final box = tester.widget<SizedBox>(
      find
          .ancestor(
              of: find.byType(FlutterMap), matching: find.byType(SizedBox))
          .first,
    );
    expect(box.height, 250);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'FilterPillRow fades the trailing edge when overflowing and the '
    'leading edge once scrolled',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMasilPetTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                child: FilterPillRow<int>(
                  values: List.generate(10, (index) => index),
                  labelOf: (value) => '지역 $value',
                  selected: 0,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // At rest: only the trailing edge fades, hinting more content follows.
      expect(find.byType(EdgeFade), findsOneWidget);

      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(-80, 0));
      await tester.pump();

      // Mid-scroll: both edges fade.
      expect(find.byType(EdgeFade), findsNWidgets(2));

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-2000, 0),
      );
      await tester.pump();

      // Scrolled to the end: only the leading edge fades.
      expect(find.byType(EdgeFade), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('map screen offers location confirmation when check-in is locked',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    expect(find.text('가장 가까운 산책지'), findsOneWidget);
    expect(find.text('여기에 도장 찍기'), findsNothing);

    final refresh = find.text('현재 위치 확인하기');
    expect(refresh, findsOneWidget);
    await tester.ensureVisible(refresh);
    await tester.pump();
    await tester.tap(refresh);
    await _settle(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('map fallback opens the local check-in route',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    final fallback = find.text('전국 기본 지도 보기');
    expect(fallback, findsOneWidget);

    await tester.ensureVisible(fallback);
    await tester.pump();
    await tester.tap(fallback);
    await _settle(tester);

    expect(controller.state.hasFreshVerifiedLocation, isTrue);
    expect(controller.state.canCheckInToday(starterPoiSeed.first), isTrue);
    expect(controller.state.statusMessage, contains('체험 위치'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('map screen stamps an in-range place from the hero',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    final poi = starterPoiSeed.first;
    _verifyLocationAt(controller, poi);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    expect(find.text(poi.title), findsWidgets);
    expect(find.textContaining('지금 여기 · '), findsOneWidget);

    final stamp = find.text('여기에 도장 찍기');
    expect(stamp, findsOneWidget);
    await tester.ensureVisible(stamp);
    await tester.pump();
    await tester.tap(stamp);
    await _settleStamp(tester);

    expect(controller.state.todayCheckInCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map screen shows the visit stamp after checking in',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    final poi = starterPoiSeed.first;
    _verifyLocationAt(controller, poi);
    controller.state = controller.state.copyWith(
      checkIns: [
        _checkIn(
          poi: poi,
          reward: const CheckInReward(
            stats: GrowthStats(exp: 22, mood: 4, knowledge: 22, affinity: 8),
            eggProgress: 760,
          ),
        ),
      ],
    );
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    expect(find.text('방문 인증 완료'), findsOneWidget);
    expect(find.text('VISITED'), findsOneWidget);
    expect(find.text('인증'), findsOneWidget);
    expect(find.text('EXP +22'), findsOneWidget);
    expect(find.text('기분 +4'), findsOneWidget);
    expect(find.text('지식 +22'), findsOneWidget);
    expect(find.text('친밀도 +8'), findsOneWidget);
    expect(find.text('알 +760걸음'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map poi list filters nearby places by category',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    _verifyLocationAt(controller, starterPoiSeed.first);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    expect(find.text('전체'), findsOneWidget);

    final natureFilter = find.descendant(
      of: find.byType(FilterPillRow<PoiCategory?>),
      matching: find.text(PoiCategory.nature.label),
    );
    expect(natureFilter, findsOneWidget);

    await tester.tap(natureFilter);
    await _settle(tester);

    expect(controller.state.mapCategoryFocus, PoiCategory.nature);

    final visibleTitles = starterPoiSeed
        .where((poi) => poi.category == PoiCategory.nature)
        .map((poi) => poi.title);
    expect(visibleTitles, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map nearby list stamps a place within range',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    final poi = starterPoiSeed.first;
    _verifyLocationAt(controller, poi);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    final stampTags = find.text('도장');
    expect(stampTags, findsWidgets);

    await tester.ensureVisible(stampTags.first);
    await tester.pump();
    await tester.tap(stampTags.first);
    await _settleStamp(tester);

    expect(controller.state.todayCheckInCount, 1);
    expect(controller.state.checkIns.first.poiId, poi.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map nearby list marks a stamped place as complete',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    final poi = starterPoiSeed.first;
    _verifyLocationAt(controller, poi);
    controller.state = controller.state.copyWith(
      checkIns: [_checkIn(poi: poi)],
    );
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    expect(find.text('완료'), findsWidgets);
    expect(find.textContaining('오늘 방문 완료'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map markers expose accessible semantics',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    final stamped = starterPoiSeed.first;
    const candidate = Poi(
      id: 'seoul-marker-candidate',
      tourApiContentId: 'seed-test-marker',
      title: '광화문 산책로',
      regionId: 'seoul',
      category: PoiCategory.culture,
      coordinates: Coordinates(latitude: 37.5801, longitude: 126.9784),
      shortDescription: '지도 마커 접근성 테스트 후보 장소',
    );
    controller.state = controller.state.copyWith(pois: [stamped, candidate]);
    _verifyLocationAt(controller, stamped);
    controller.state = controller.state.copyWith(
      checkIns: [_checkIn(poi: stamped)],
    );
    _sizeView(tester, _desktop);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    expect(_semanticsLabel('현재 위치'), findsOneWidget);
    expect(
      _semanticsLabel(
        '${stamped.title}, ${stamped.category.label}, 오늘 방문 완료',
      ),
      findsOneWidget,
    );
    expect(
      _semanticsLabel('${candidate.title}, ${candidate.category.label}'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('map focus panel surfaces TourAPI content ids when available',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    const poi = Poi(
      id: 'tour-api-poi',
      tourApiContentId: '126508',
      title: '남산서울타워',
      regionId: 'seoul',
      category: PoiCategory.culture,
      coordinates: Coordinates(latitude: 37.5512, longitude: 126.9882),
      shortDescription: '서울 도심 전망과 야경 산책 코스',
    );
    controller.state = controller.state.copyWith(pois: const [poi]);
    _verifyLocationAt(controller, poi);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(FlutterMap),
        matching: find.text(poi.title),
      ),
    );
    await _settle(tester);

    expect(find.text('TourAPI ID 126508'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map focus panel offers a check-in for the tapped pin',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    final poi = starterPoiSeed.first;
    controller.state = controller.state.copyWith(pois: [poi]);
    _verifyLocationAt(controller, poi);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(FlutterMap),
        matching: find.text(poi.title),
      ),
    );
    await _settle(tester);

    expect(find.text('전국 기본 장소'), findsWidgets);

    final closeButton = find.text('닫기');
    expect(closeButton, findsOneWidget);
    await tester.tap(closeButton);
    await _settle(tester);

    expect(find.text('전국 기본 장소'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map screen shows a daily walking course',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    _verifyLocationAt(controller, starterPoiSeed.first);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    expect(find.text('오늘의 산책 코스'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(controller.state.recommendedRoutePois, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map screen reports how fresh the location is',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    _verifyLocationAt(controller, starterPoiSeed.first);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    expect(find.text('위치 확인 방금'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map screen empty POI state offers location refresh',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(0);
    controller.state = controller.state.copyWith(pois: const []);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const MapScreen()));
    await _settle(tester);

    expect(find.text('위치가 필요해요'), findsOneWidget);
    expect(find.text('현재 위치 확인하기'), findsOneWidget);
    expect(find.text('전국 기본 지도 보기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ───────────────────────────────────────────────────────────────────── pet ──

  testWidgets('pet stage shows the companion and what it says',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(1);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const PetScreen()));
    await _settle(tester);

    expect(find.text('해랑'), findsWidgets);
    expect(find.byType(SpeechBubble), findsOneWidget);
    expect(find.text('쓰다듬기 · 오늘 5번 남음'), findsOneWidget);
    expect(find.text('오늘 해준 것'), findsOneWidget);
    expect(find.text('지금의 마음'), findsOneWidget);
    expect(find.text('오늘의 산책'), findsOneWidget);
    expect(find.text('배부름'), findsOneWidget);
    expect(find.text('청결'), findsOneWidget);
    expect(find.text('활력'), findsOneWidget);
    expect(find.text('행복'), findsOneWidget);
    expect(find.textContaining('성격'), findsOneWidget);
    expect(find.text('진화까지'), findsOneWidget);
    expect(find.text('EXP 20 / 500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet food picker shows preferences and records the meal',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(1);
    final pet = controller.state.activePet!;
    final favorite = controller.favoriteFoodFor(pet);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const PetScreen()));
    await _settle(tester);

    final feedAction = find.text('밥 주기');
    await tester.ensureVisible(feedAction);
    await _settle(tester);
    await tester.tap(feedAction);
    await _settle(tester);

    expect(find.text('${pet.name}에게 무엇을 줄까요?'), findsOneWidget);
    expect(find.text('가장 좋아해요'), findsOneWidget);

    await tester.tap(find.text(favorite.label));
    await _settle(tester);

    expect(controller.state.activePetCare!.lastFood, favorite);
    expect(controller.state.activePetCare!.memories.first.category,
        PoiCategory.food);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet care actions update play clean and sleep feedback',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(1);
    final initialCare = controller.state.activePetCare!;
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const PetScreen()));
    await _settle(tester);

    final playAction = find.text('놀아주기');
    await tester.ensureVisible(playAction);
    await tester.pump();
    await tester.tap(playAction);
    await _settle(tester);

    expect(
      controller.state.activePetCare!.playCountToday,
      initialCare.playCountToday + 1,
    );
    expect(controller.state.fieldActivity, PetFieldActivity.jumping);

    final cleanAction = find.text('씻기기');
    await tester.ensureVisible(cleanAction);
    await tester.pump();
    await tester.tap(cleanAction);
    await _settle(tester);

    expect(
      controller.state.activePetCare!.cleanCountToday,
      initialCare.cleanCountToday + 1,
    );
    expect(
      controller.state.activePetCare!.cleanliness,
      greaterThanOrEqualTo(initialCare.cleanliness),
    );

    final sleepAction = find.text('포근하게 재우기');
    await tester.ensureVisible(sleepAction);
    await tester.pump();
    await tester.tap(sleepAction);
    await _settle(tester);

    expect(controller.state.fieldActivity, PetFieldActivity.sleeping);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet feeding respects the daily limit',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(1);
    for (var i = 0; i < dailyFeedCareLimit; i++) {
      await controller.feedActivePet();
    }
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const PetScreen()));
    await _settle(tester);

    expect(find.text('오늘 충분해요'), findsOneWidget);
    expect(
      controller.state.activePetCare!.feedCountToday,
      dailyFeedCareLimit,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet talk action says so once the daily limit is spent',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(1);
    controller.state = controller.state.copyWith(
      dialogueCountToday: 5,
      dialogueDay: DateTime.now(),
    );
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const PetScreen()));
    await _settle(tester);

    // The pill keeps the design's label and answers out loud instead of
    // going grey.
    final pill = find.text('쓰다듬기 · 오늘 0번 남음');
    expect(pill, findsOneWidget);

    await tester.tap(pill);
    await _settle(tester);

    expect(find.text('오늘 대화는 다 했어. 내일 또 얘기하자!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet care points note claims the daily reward once',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(1);
    controller.playActivePet();
    controller.cleanActivePet();
    await controller.feedActivePet();
    await controller.talkWithActivePet();
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const PetScreen()));
    await _settle(tester);

    expect(find.text('돌봄 포인트'), findsOneWidget);

    final claim = find.text('돌봄 보상 받기');
    expect(claim, findsOneWidget);
    await tester.ensureVisible(claim);
    await tester.pump();
    await tester.tap(claim);
    await _settle(tester);

    expect(controller.state.carePoints, dailyCareRewardPoints);
    expect(find.text('$dailyCareRewardPoints P'), findsOneWidget);
    expect(find.text('돌봄 보상 받기'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet growth goal links to map exploration',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(1);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const PetScreen()));
    await _settle(tester);

    expect(find.text('성장 조건'), findsOneWidget);
    expect(find.text('레벨'), findsOneWidget);
    expect(
      find.text('Lv.1 / ${GrowthEngine.grownLevelRequirement}'),
      findsOneWidget,
    );

    final growthAction = find.text('지도에서 성장 보상 얻기');
    await tester.ensureVisible(growthAction);
    await tester.pump();
    await tester.tap(growthAction);
    await _settle(tester);

    expect(controller.state.selectedTab, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet evolution goal shows unmet stat requirements',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(1);
    final activePet = controller.state.activePet!;
    controller.state = controller.state.copyWith(
      pets: [
        activePet.copyWith(
          level: 4,
          stage: PetStage.grown,
          stats: const GrowthStats(
            exp: 320,
            mood: 44,
            knowledge: 38,
            affinity: 72,
          ),
        ),
      ],
    );
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const PetScreen()));
    await _settle(tester);

    expect(find.text('진화 조건'), findsOneWidget);
    expect(
      find.text('Lv.4 / ${GrowthEngine.evolvedLevelRequirement}'),
      findsOneWidget,
    );
    expect(
      find.text('38 / ${GrowthEngine.evolvedKnowledgeRequirement}'),
      findsOneWidget,
    );
    expect(
      find.text('72 / ${GrowthEngine.evolvedAffinityRequirement}'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet roster marks the current companion',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(1);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const PetScreen()));
    await _settle(tester);

    expect(find.text('내 마실펫 1마리'), findsOneWidget);
    expect(find.text('동행'), findsOneWidget);
    expect(find.text('지금 함께 다녀요'), findsOneWidget);
    expect(find.text('상세보기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet roster opens a detail sheet for a companion',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(1);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const PetScreen()));
    await _settle(tester);

    final detail = find.text('상세보기');
    await tester.ensureVisible(detail);
    await tester.pump();
    await tester.tap(detail);
    await _settle(tester);

    expect(find.text('첫 만남'), findsOneWidget);
    expect(find.text('지금 함께 다니는 친구'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await _settle(tester);

    expect(find.text('첫 만남'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet roster selects another walking companion',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(1);
    final first = controller.state.activePet!;
    final second = Pet(
      id: 'pet-second',
      templateId: starterPetTemplates[1].id,
      name: starterPetTemplates[1].name,
      stage: PetStage.baby,
      level: 2,
      stats: const GrowthStats(exp: 40, mood: 10, knowledge: 4, affinity: 6),
      originRegionId: starterPetTemplates[1].regionId,
      hatchedAt: DateTime.now(),
      lastInteractedAt: null,
    );
    controller.state = controller.state.copyWith(pets: [first, second]);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const PetScreen()));
    await _settle(tester);

    expect(find.text('내 마실펫 2마리'), findsOneWidget);

    final promote = find.text('함께 걷기');
    expect(promote, findsOneWidget);
    await tester.ensureVisible(promote);
    await tester.pump();
    await tester.tap(promote);
    await _settle(tester);

    expect(controller.state.activePetId, second.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pet screen hides care actions when no active pet is available',
      (WidgetTester tester) async {
    final controller = _EmptyPetController();
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const PetScreen()));
    await _settle(tester);

    expect(find.text('함께 다니는 마실펫이 없어요'), findsOneWidget);
    expect(find.text('오늘 해준 것'), findsNothing);
    expect(find.text('밥 주기'), findsNothing);

    await tester.tap(find.text('하우스로 가기'));
    await _settle(tester);

    expect(controller.state.selectedTab, 2);
    expect(tester.takeException(), isNull);
  });

  // ─────────────────────────────────────────────────────────────────── house ──

  testWidgets('house screen shows the yard, the egg and today\'s care',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(2);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const HouseScreen()));
    await _settle(tester);

    expect(find.byType(PetPlayField), findsOneWidget);
    expect(find.text('마당 · 친구를 누르고, 공과 밥그릇도 건드려보세요'), findsOneWidget);
    expect(find.text('1200 / 3500 걸음'), findsOneWidget);
    expect(find.text('오늘의 돌봄'), findsOneWidget);
    expect(find.text('밥 주기'), findsOneWidget);
    expect(find.text('한 곳 체크인하기'), findsOneWidget);
    expect(find.text('하우스 현황'), findsOneWidget);
    expect(find.text('도감 수집률'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('house screen labels an incubating egg with remaining steps',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(2);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const HouseScreen()));
    await _settle(tester);

    expect(find.textContaining('2300 걸음만 더!'), findsOneWidget);
    expect(find.text('부화시키기'), findsNothing);
    expect(find.text('지도에서 걸음 모으기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('house screen hatches a ready egg', (WidgetTester tester) async {
    final controller = _controller()..setTab(2);
    final egg = controller.state.eggs.first;
    controller.state = controller.state.copyWith(
      eggs: [
        egg.copyWith(
          progress: egg.requiredSteps,
          status: EggStatus.hatchable,
        ),
      ],
    );
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const HouseScreen()));
    await _settle(tester);

    final hatch = find.text('부화시키기');
    expect(hatch, findsOneWidget);
    await tester.ensureVisible(hatch);
    await tester.pump();
    await tester.tap(hatch);
    await _settle(tester);

    expect(controller.state.pets.length, 2);
    expect(controller.state.eggs, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('house next outing note opens the map',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(2);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const HouseScreen()));
    await _settle(tester);

    expect(find.text('다음 외출'), findsOneWidget);

    final action = find.text('지도에서 도장 찍기');
    await tester.ensureVisible(action);
    await tester.pump();
    await tester.tap(action);
    await _settle(tester);

    expect(controller.state.selectedTab, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('house yard grows on desktop width', (WidgetTester tester) async {
    final controller = _controller()..setTab(2);
    _sizeView(tester, _desktop);

    await tester.pumpWidget(_hostScreen(controller, const HouseScreen()));
    await _settle(tester);

    final field = tester.widget<PetPlayField>(find.byType(PetPlayField));
    expect(field.height, 400);
    expect(tester.takeException(), isNull);
  });

  testWidgets('house yard stays compact on phone width',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(2);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const HouseScreen()));
    await _settle(tester);

    final field = tester.widget<PetPlayField>(find.byType(PetPlayField));
    expect(field.height, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('house screen shows an empty state without eggs',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(2);
    controller.state = controller.state.copyWith(eggs: const []);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const HouseScreen()));
    await _settle(tester);

    expect(find.text('부화할 알이 없어요'), findsOneWidget);
    expect(find.textContaining('새 알이 수첩에 들어와요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ───────────────────────────────────────────────────────────────────── dex ──

  testWidgets('dex screen summarizes collection progress',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(3);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const DexScreen()));
    await _settle(tester);

    expect(find.text('전국 도감'), findsOneWidget);
    expect(find.text(' / ${starterPetTemplates.length}종'), findsOneWidget);
    expect(find.text('COLLECTED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dex screen marks undiscovered pets as exploration goals',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(3);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const DexScreen()));
    await _settle(tester);

    expect(find.text('미발견'), findsWidgets);
    expect(find.text('???'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dex screen filters by discovery state',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(3);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const DexScreen()));
    await _settle(tester);

    // Undiscovered cells label their region as ???, so it stands in for them.
    expect(find.text('???'), findsWidgets);

    await tester.tap(find.text('발견'));
    await _settle(tester);

    expect(find.text('???'), findsNothing);
    expect(find.text('해랑'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dex screen filters by region', (WidgetTester tester) async {
    final controller = _controller()..setTab(3);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const DexScreen()));
    await _settle(tester);

    // 해랑 is a Busan pet, so filtering to another region hides it.
    final seoulPill = find.text('서울');
    expect(seoulPill, findsOneWidget);

    await tester.tap(seoulPill);
    await _settle(tester);

    expect(find.text('해랑'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dex opens a detail sheet for a discovered pet',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(3);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const DexScreen()));
    await _settle(tester);

    // 해랑 sits well down the 57-cell grid, so scroll it into view first.
    // The pill rows are scrollables too, hence naming the vertical one.
    final cell = find.text('해랑');
    await tester.dragUntilVisible(
      cell,
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await _settle(tester);
    await tester.tap(cell);
    await _settle(tester);

    expect(find.text('즐겨 찾는 곳'), findsOneWidget);
    expect(find.text('첫 만남'), findsOneWidget);
    expect(find.text('닫기'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await _settle(tester);

    expect(find.text('즐겨 찾는 곳'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dex undiscovered cell hints where to look',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(3);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const DexScreen()));
    await _settle(tester);

    // Tapping the cell itself, not the like-named discovery filter pill.
    await tester.tap(find.text('???').first);
    await _settle(tester);

    expect(find.textContaining('에서 만날 수 있어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dex discovery note opens the map with a category goal',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(3);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const DexScreen()));
    await _settle(tester);

    expect(find.text('다음 발견 후보'), findsOneWidget);

    final action = find.text('지도에서 탐험하기');
    await tester.ensureVisible(action);
    await tester.pump();
    await tester.tap(action);
    await _settle(tester);

    expect(controller.state.selectedTab, 0);
    expect(controller.state.mapCategoryFocus, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dex discovery hints use friendly POI source labels',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(3);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const DexScreen()));
    await _settle(tester);

    final hints = find.text('발견 힌트가 있는 산책지');
    await tester.ensureVisible(hints);
    await tester.pump();

    expect(hints, findsOneWidget);
    expect(find.textContaining('기본 수록 산책지'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dex empty filter result offers a reset',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(3);
    controller.state = controller.state.copyWith(pets: const []);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const DexScreen()));
    await _settle(tester);

    await tester.tap(find.text('발견'));
    await _settle(tester);

    expect(find.text('조건에 맞는 스티커가 없어요'), findsOneWidget);

    await tester.tap(find.text('필터 초기화'));
    await _settle(tester);

    expect(find.text('조건에 맞는 스티커가 없어요'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // ───────────────────────────────────────────────────────────────── profile ──

  testWidgets('profile passport shows the streak and this month\'s grid',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(4);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const ProfileScreen()));
    await _settle(tester);

    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    expect(find.text('WALKING PASSPORT · ${now.year}.$month'), findsOneWidget);
    expect(find.text('오늘 첫 도장'), findsOneWidget);
    expect(find.byType(PassportDay), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile passport stamps a day that was walked',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(4);
    final poi = starterPoiSeed.first;
    controller.state = controller.state.copyWith(
      checkIns: [_checkIn(poi: poi)],
    );
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const ProfileScreen()));
    await _settle(tester);

    expect(find.text('1일 연속 산책'), findsOneWidget);

    final today = DateTime.now().day;
    final stamped = tester
        .widgetList<PassportDay>(find.byType(PassportDay))
        .where((day) => day.stamped)
        .toList();
    expect(stamped, hasLength(1));
    expect(stamped.single.day, today);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile totals summarize the walk history',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(4);
    controller.state = controller.state.copyWith(
      checkIns: [
        _checkIn(poi: starterPoiSeed.first),
        _checkIn(poi: starterPoiSeed[1]),
      ],
    );
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const ProfileScreen()));
    await _settle(tester);

    expect(find.text('다녀온 산책지'), findsOneWidget);
    expect(find.text('2곳'), findsOneWidget);
    expect(find.text('누적 체크인'), findsOneWidget);
    expect(find.text('2회'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile recent walks list the latest visits',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(4);
    final poi = starterPoiSeed.first;
    controller.state = controller.state.copyWith(
      checkIns: [
        _checkIn(
          poi: poi,
          reward: const CheckInReward(
            stats: GrowthStats(exp: 33, mood: 4, knowledge: 5, affinity: 6),
            eggProgress: 77,
          ),
        ),
      ],
    );
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const ProfileScreen()));
    await _settle(tester);

    expect(find.text('최근 산책'), findsOneWidget);
    expect(find.text(poi.title), findsWidgets);
    expect(
      find.text('EXP +33 · 기분 +4 · 지식 +5 · 친밀도 +6 · 알 +77'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile report copies today\'s summary',
      (WidgetTester tester) async {
    _stubClipboard(tester);
    final controller = _controller()..setTab(4);
    controller.state = controller.state.copyWith(
      checkIns: [_checkIn(poi: starterPoiSeed.first)],
    );
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const ProfileScreen()));
    await _settle(tester);

    expect(find.text('오늘의 리포트'), findsOneWidget);
    expect(find.textContaining('도장을 찍었어요'), findsOneWidget);

    final copy = find.text('리포트 복사하기');
    await tester.ensureVisible(copy);
    await tester.pump();
    await tester.tap(copy);
    await _settle(tester);

    expect(find.text('오늘의 리포트를 복사했어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile goals guide the next step', (WidgetTester tester) async {
    final controller = _controller()..setTab(4);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const ProfileScreen()));
    await _settle(tester);

    expect(find.textContaining('수첩 목표'), findsOneWidget);
    expect(find.text('위치 인증'), findsOneWidget);
    expect(find.text('첫 발자국'), findsOneWidget);

    final action = find.text('위치 확인하러 가기');
    await tester.ensureVisible(action);
    await tester.pump();
    await tester.tap(action);
    await _settle(tester);

    expect(controller.state.selectedTab, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile ledger summarizes the notebook',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(4);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const ProfileScreen()));
    await _settle(tester);

    final ledger = find.text('수첩 요약');
    await tester.ensureVisible(ledger);
    await tester.pump();

    expect(ledger, findsOneWidget);
    expect(find.text('첫 산책 지역'), findsOneWidget);
    expect(find.text('대한민국'), findsWidgets);
    expect(find.text('보유 마실펫'), findsOneWidget);
    expect(find.text('도감 수집률'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile location actions use device and starter location',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(4);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const ProfileScreen()));
    await _settle(tester);

    final section = find.text('위치와 동기화');
    await tester.ensureVisible(section);
    await tester.pump();
    expect(section, findsOneWidget);

    final fallback = find.text('전국 기본 지도 보기');
    await tester.ensureVisible(fallback);
    await tester.pump();
    await tester.tap(fallback);
    await _settle(tester);

    expect(controller.state.selectedTab, 0);
    expect(controller.state.hasFreshVerifiedLocation, isTrue);
    expect(controller.state.canCheckInToday(starterPoiSeed.first), isTrue);
    expect(controller.state.statusMessage, contains('체험 위치'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile explains data and map provenance',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(4);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const ProfileScreen()));
    await _settle(tester);

    final sources = find.text('데이터·지도 출처');
    await tester.ensureVisible(sources);
    await tester.pump();

    expect(sources, findsOneWidget);
    expect(find.text('TourAPI 지역 장소'), findsOneWidget);
    expect(find.text('OpenStreetMap 지도'), findsOneWidget);
    expect(find.text('지도 타일 설정'), findsOneWidget);
    expect(
      find.text('OpenStreetMap 기본 타일 · 요청 식별자 com.masilpet.app'),
      findsOneWidget,
    );
    expect(find.text('Firebase Functions 검증'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile privacy section links the policy',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(4);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const ProfileScreen()));
    await _settle(tester);

    final privacy = find.text('위치·개인정보 보호');
    await tester.ensureVisible(privacy);
    await tester.pump();

    expect(privacy, findsOneWidget);
    expect(find.text('개인정보 처리방침: /privacy.html'), findsOneWidget);
    expect(find.text('개인정보 처리방침 열기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile reset action requires confirmation',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = _controller()..setTab(4);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const ProfileScreen()));
    await _settle(tester);

    final resetSection = find.text('진행도 관리');
    await tester.ensureVisible(resetSection);
    await tester.pump();
    expect(resetSection, findsOneWidget);

    final reset = find.text('진행도 초기화');
    await tester.ensureVisible(reset);
    await tester.pump();
    await tester.tap(reset);
    await _settle(tester);

    expect(find.textContaining('다시 되살릴 수 없어요'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await _settle(tester);

    expect(find.textContaining('다시 되살릴 수 없어요'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile app info shows build metadata',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = _controller()..setTab(4);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const ProfileScreen()));
    await _settle(tester);

    final info = find.text('앱 정보와 연결');
    await tester.ensureVisible(info);
    await tester.pump();

    expect(info, findsOneWidget);
    expect(find.text('앱 버전'), findsOneWidget);
    expect(find.text('local-dev'), findsOneWidget);
    expect(find.text('빌드 채널'), findsOneWidget);
    expect(find.text('local'), findsOneWidget);
    expect(find.text('빌드 시각'), findsOneWidget);
    expect(find.text('local build'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection screens expose clear sections on phone width',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(3);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const DexScreen()));
    await _settle(tester);

    expect(find.text('전국 도감'), findsOneWidget);
    expect(find.text('다음 발견 후보'), findsOneWidget);

    await tester.pumpWidget(_hostScreen(controller, const HouseScreen()));
    await _settle(tester);

    expect(find.text('오늘의 돌봄'), findsOneWidget);
    expect(find.text('하우스 현황'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('house yard opens a care menu for the tapped pet',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(2);
    final pet = controller.state.activePet!;
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const HouseScreen()));
    await _settle(tester);

    expect(find.text('상세보기'), findsNothing);

    await tester.tap(find.byKey(ValueKey('pet-play-field-pet-${pet.id}')));
    await _settle(tester);

    expect(find.text(pet.name), findsWidgets);
    expect(find.text('상세보기'), findsOneWidget);
    expect(find.text('밥 주기 $dailyFeedCareLimit'), findsOneWidget);
    expect(find.text('놀아주기'), findsWidgets);
    expect(find.text('씻기기'), findsWidgets);

    await tester.tap(find.text('닫기'));
    await _settle(tester);

    expect(find.text('상세보기'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('house yard menu feeds the tapped pet',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(2);
    final active = controller.state.activePet!;
    final other = Pet(
      id: 'pet-yard-second',
      templateId: starterPetTemplates[1].id,
      name: starterPetTemplates[1].name,
      stage: PetStage.baby,
      level: 2,
      stats: const GrowthStats(exp: 40, mood: 10, knowledge: 4, affinity: 6),
      originRegionId: starterPetTemplates[1].regionId,
      hatchedAt: DateTime.now(),
      lastInteractedAt: null,
    );
    controller.state = controller.state.copyWith(pets: [active, other]);
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const HouseScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('pet-play-field-pet-${other.id}')));
    await _settle(tester);

    await tester.tap(find.text('밥 주기 $dailyFeedCareLimit'));
    await _settle(tester);

    // The tapped pet ate, not the current companion.
    expect(controller.state.careForPet(other.id)!.feedCountToday, 1);
    expect(controller.state.careForPet(active.id)?.feedCountToday ?? 0, 0);
    expect(controller.state.activePetId, active.id);
    expect(find.text('상세보기'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('house yard menu opens the pet detail sheet',
      (WidgetTester tester) async {
    final controller = _controller()..setTab(2);
    final pet = controller.state.activePet!;
    _sizeView(tester, _phone);

    await tester.pumpWidget(_hostScreen(controller, const HouseScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('pet-play-field-pet-${pet.id}')));
    await _settle(tester);
    await tester.tap(find.text('상세보기'));
    await _settle(tester);

    expect(find.byType(PetDetailSheet), findsOneWidget);
    expect(find.text('첫 만남'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset progress returns to a visible onboarding story',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = _controller();
    await controller.completeOnboarding();
    _sizeView(tester, _phone);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MasilPetApp(),
      ),
    );
    await _settle(tester);

    expect(find.byType(HomeShell), findsOneWidget);

    await controller.resetProgress();
    await _settle(tester);

    expect(controller.state.onboardingComplete, isFalse);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('걸으면 만나고,\n만나면 자라요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
