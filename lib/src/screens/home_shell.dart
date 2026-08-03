import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../services.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/paper_kit.dart';
import '../widgets/paper_shell.dart';
import 'dex_screen.dart';
import 'house_screen.dart';
import 'map_screen.dart';
import 'pet_screen.dart';
import 'profile_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  /// Navigation reads like a table of contents, so the order is fixed by the
  /// design (지도 · 하우스 · 마실펫 · 도감 · 기록) and mapped onto screen slots.
  static const _navigationOrder = [0, 2, 1, 3, 4];

  static const _screens = [
    MapScreen(),
    PetScreen(),
    HouseScreen(),
    DexScreen(),
    ProfileScreen(),
  ];

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  /// One controller per tab, handed down as each page's primary scroller so
  /// the shell can send a page back to its masthead without the screens
  /// having to know about the navigation at all.
  late final List<ScrollController> _scrollControllers = List.generate(
    HomeShell._screens.length,
    (_) => ScrollController(),
  );

  @override
  void dispose() {
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Tapping the tab you are already reading takes the page back to the top —
  /// the shortcut every long notebook page wants.
  void _onSelected(int navigationIndex, int currentTab) {
    final tab = HomeShell._navigationOrder[navigationIndex];
    if (tab != currentTab) {
      ref.read(masilPetControllerProvider.notifier).setTab(tab);
      return;
    }

    final controller = _scrollControllers[tab];
    if (!controller.hasClients || controller.offset <= 0) {
      return;
    }
    controller.animateTo(
      0,
      duration: MasilPetMotion.standard,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(masilPetControllerProvider);

    final navigationIndex =
        HomeShell._navigationOrder.indexOf(state.selectedTab);
    final activeIndex = navigationIndex < 0 ? 0 : navigationIndex;
    final page = _homePages(state)[activeIndex];
    final streak = state.currentVisitStreakDays;

    return PaperShell(
      dateLine: _homeDateLine(DateTime.now(), state.region.name),
      title: page.title,
      note: page.note,
      items: _homeNavItems(state),
      activeIndex: activeIndex,
      onSelected: (index) => _onSelected(index, state.selectedTab),
      railFooterLabel: '연속 산책',
      railFooterValue: streak == 0 ? '첫 걸음' : '$streak일째',
      body: _HomeTabStack(scrollControllers: _scrollControllers),
    );
  }
}

class _HomeTabStack extends ConsumerWidget {
  const _HomeTabStack({required this.scrollControllers});

  final List<ScrollController> scrollControllers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(
      masilPetControllerProvider.select((state) => state.selectedTab),
    );

    return IndexedStack(
      index: tab,
      children: [
        for (final (index, screen) in HomeShell._screens.indexed)
          TickerMode(
            enabled: index == tab,
            child: PrimaryScrollController(
              controller: scrollControllers[index],
              child: screen,
            ),
          ),
      ],
    );
  }
}

/// `2026.07.29 WED · 부산광역시`
String _homeDateLine(DateTime now, String regionName) {
  const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  final weekday = weekdays[(now.weekday - 1).clamp(0, 6)];
  return '$year.$month.$day $weekday · $regionName';
}

class _HomePage {
  const _HomePage({required this.title, required this.note});

  final String title;
  final String note;
}

List<_HomePage> _homePages(MasilPetState state) {
  final petName = state.activePet?.name ?? '마실펫';
  final streak = state.currentVisitStreakDays;
  final eggProgress = state.activeEgg;

  return [
    _HomePage(
      title: '오늘의 산책',
      note: state.todayCheckInCount > 0
          ? '오늘 ${state.todayCheckInCount}곳\n다녀왔어'
          : '지금 여기서\n찍을 수 있어',
    ),
    _HomePage(
      title: '하우스',
      note: eggProgress == null
          ? '모두 부화했어'
          : (eggProgress.status == EggStatus.hatchable
              ? '알이 흔들려!'
              : '알이 자라는 중'),
    ),
    _HomePage(
      title: petCallName(petName),
      note: '나 기다렸어!',
    ),
    const _HomePage(title: '전국 도감', note: '스탬프 모으기'),
    _HomePage(
      title: '산책 수첩',
      note: streak == 0 ? '첫 도장을\n기다려요' : '$streak일 연속',
    ),
  ];
}

List<PaperNavItem> _homeNavItems(MasilPetState state) {
  final talksLeft = _homeTalksLeftToday(state);
  final undiscoveredCount =
      (state.templates.length - state.discoveredTemplateIds.length)
          .clamp(0, state.templates.length);
  final streak = state.currentVisitStreakDays;

  return [
    PaperNavItem(
      label: '지도',
      number: '01',
      glyph: PaperGlyphKind.map,
      tooltip: _mapNavTooltip(state),
      badge: _mapNavBadge(state),
    ),
    PaperNavItem(
      label: '하우스',
      number: '02',
      glyph: PaperGlyphKind.house,
      tooltip: _houseNavTooltip(state),
      badge: _houseNavBadge(state),
    ),
    PaperNavItem(
      label: '마실펫',
      number: '03',
      glyph: PaperGlyphKind.pet,
      tooltip: talksLeft == 0 ? '마실펫 탭: 오늘 대화 완료' : '마실펫 탭: 대화 $talksLeft회 가능',
      badge: talksLeft == 0 ? null : '$talksLeft',
    ),
    PaperNavItem(
      label: '도감',
      number: '04',
      glyph: PaperGlyphKind.dex,
      tooltip: undiscoveredCount == 0
          ? '도감 탭: 전국 도감 완성'
          : '도감 탭: 미발견 $undiscoveredCount종',
      badge: undiscoveredCount == 0 ? null : '$undiscoveredCount',
    ),
    PaperNavItem(
      label: '기록',
      number: '05',
      glyph: PaperGlyphKind.record,
      tooltip: streak == 0 ? '기록 탭: 첫 산책을 기다리는 중' : '기록 탭: $streak일 연속 산책',
      badge: streak == 0 ? null : '$streak',
    ),
  ];
}

String _mapNavTooltip(MasilPetState state) {
  if (state.todayCheckInCount > 0) {
    return '지도 탭: 오늘 체크인 ${state.todayCheckInCount}회';
  }
  if (state.hasFreshVerifiedLocation && state.todayAvailableCheckInCount > 0) {
    return '지도 탭: 체크인 가능 ${state.todayAvailableCheckInCount}곳';
  }
  return '지도 탭: 위치 확인 필요';
}

String? _mapNavBadge(MasilPetState state) {
  if (state.todayCheckInCount > 0) {
    return '${state.todayCheckInCount}';
  }
  if (state.hasFreshVerifiedLocation && state.todayAvailableCheckInCount > 0) {
    return '${state.todayAvailableCheckInCount}';
  }
  return null;
}

String _houseNavTooltip(MasilPetState state) {
  if (state.hatchableEggCount > 0) {
    return '하우스 탭: 부화 가능 ${state.hatchableEggCount}개';
  }
  if (state.eggs.isNotEmpty) {
    return '하우스 탭: 알 ${state.eggs.length}개 관리';
  }
  return '하우스 탭: 알 없음';
}

String? _houseNavBadge(MasilPetState state) {
  if (state.hatchableEggCount > 0) {
    return '!';
  }
  if (state.eggs.isNotEmpty) {
    return '${state.eggs.length}';
  }
  return null;
}

int _homeTalksLeftToday(MasilPetState state) {
  final countToday = isSameLocalDay(state.dialogueDay, DateTime.now())
      ? state.dialogueCountToday
      : 0;
  return (5 - countToday).clamp(0, 5).toInt();
}
