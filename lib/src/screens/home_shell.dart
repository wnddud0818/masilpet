import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services.dart';
import '../state.dart';
import '../theme.dart';
import 'dex_screen.dart';
import 'house_screen.dart';
import 'map_screen.dart';
import 'pet_screen.dart';
import 'profile_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _wideNavigationBreakpoint = 720.0;
  static const _extendedRailBreakpoint = 1040.0;
  static const _navigationOrder = [0, 2, 1, 3, 4];

  static const _screens = [
    MapScreen(),
    PetScreen(),
    HouseScreen(),
    DexScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(masilPetControllerProvider);
    final tab = state.selectedTab;
    final navigationIndex = _navigationOrder.indexOf(tab);
    final controller = ref.read(masilPetControllerProvider.notifier);
    final signals = _homeNavSignals(state);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= _wideNavigationBreakpoint;
        if (!useRail) {
          return Scaffold(
            body: const SafeArea(child: _HomeTabStack()),
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationIndex < 0 ? 2 : navigationIndex,
              onDestinationSelected: (index) {
                controller.setTab(_navigationOrder[index]);
              },
              destinations: _navigationDestinations(signals),
            ),
          );
        }

        final extendRail = constraints.maxWidth >= _extendedRailBreakpoint;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  extended: extendRail,
                  minExtendedWidth: 168,
                  groupAlignment: -0.86,
                  labelType: extendRail
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  selectedIndex: navigationIndex < 0 ? 2 : navigationIndex,
                  onDestinationSelected: (index) {
                    controller.setTab(_navigationOrder[index]);
                  },
                  destinations: _railDestinations(signals),
                ),
                const VerticalDivider(width: 1),
                const Expanded(child: _HomeTabStack()),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeTabStack extends ConsumerWidget {
  const _HomeTabStack();

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
            child: screen,
          ),
      ],
    );
  }
}

List<NavigationDestination> _navigationDestinations(_HomeNavSignals signals) {
  return [
    NavigationDestination(
      icon: _HomeNavIcon(
        icon: Icons.map_outlined,
        signal: signals.map,
      ),
      selectedIcon: _HomeNavIcon(
        icon: Icons.map,
        signal: signals.map,
      ),
      label: '지도',
    ),
    NavigationDestination(
      icon: _HomeNavIcon(
        icon: Icons.home_outlined,
        signal: signals.house,
      ),
      selectedIcon: _HomeNavIcon(
        icon: Icons.home,
        signal: signals.house,
      ),
      label: '하우스',
    ),
    NavigationDestination(
      icon: _HomeNavIcon(
        icon: Icons.pets_outlined,
        signal: signals.pet,
        featured: true,
      ),
      selectedIcon: _HomeNavIcon(
        icon: Icons.pets,
        signal: signals.pet,
        featured: true,
      ),
      label: '마실펫',
    ),
    NavigationDestination(
      icon: _HomeNavIcon(
        icon: Icons.menu_book_outlined,
        signal: signals.dex,
      ),
      selectedIcon: _HomeNavIcon(
        icon: Icons.menu_book,
        signal: signals.dex,
      ),
      label: '도감',
    ),
    NavigationDestination(
      icon: _HomeNavIcon(
        icon: Icons.person_outline,
        signal: signals.profile,
      ),
      selectedIcon: _HomeNavIcon(
        icon: Icons.person,
        signal: signals.profile,
      ),
      label: '기록',
    ),
  ];
}

List<NavigationRailDestination> _railDestinations(_HomeNavSignals signals) {
  return [
    NavigationRailDestination(
      icon: _HomeNavIcon(
        icon: Icons.map_outlined,
        signal: signals.map,
      ),
      selectedIcon: _HomeNavIcon(
        icon: Icons.map,
        signal: signals.map,
      ),
      label: const Text('지도'),
    ),
    NavigationRailDestination(
      icon: _HomeNavIcon(
        icon: Icons.home_outlined,
        signal: signals.house,
      ),
      selectedIcon: _HomeNavIcon(
        icon: Icons.home,
        signal: signals.house,
      ),
      label: const Text('하우스'),
    ),
    NavigationRailDestination(
      icon: _HomeNavIcon(
        icon: Icons.pets_outlined,
        signal: signals.pet,
        featured: true,
      ),
      selectedIcon: _HomeNavIcon(
        icon: Icons.pets,
        signal: signals.pet,
        featured: true,
      ),
      label: const Text('마실펫'),
    ),
    NavigationRailDestination(
      icon: _HomeNavIcon(
        icon: Icons.menu_book_outlined,
        signal: signals.dex,
      ),
      selectedIcon: _HomeNavIcon(
        icon: Icons.menu_book,
        signal: signals.dex,
      ),
      label: const Text('도감'),
    ),
    NavigationRailDestination(
      icon: _HomeNavIcon(
        icon: Icons.person_outline,
        signal: signals.profile,
      ),
      selectedIcon: _HomeNavIcon(
        icon: Icons.person,
        signal: signals.profile,
      ),
      label: const Text('기록'),
    ),
  ];
}

class _HomeNavIcon extends StatelessWidget {
  const _HomeNavIcon({
    required this.icon,
    required this.signal,
    this.featured = false,
  });

  final IconData icon;
  final _HomeNavSignal signal;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    Widget child = Icon(icon);
    if (featured) {
      child = Container(
        width: 38,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MasilPetPalette.sunPale,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: MasilPetPalette.outline),
        ),
        child: child,
      );
    }
    final badgeLabel = signal.badgeLabel;
    if (signal.showBadge) {
      child = Badge(
        label: badgeLabel == null ? null : Text(badgeLabel),
        child: child,
      );
    }

    return Tooltip(
      message: signal.tooltip,
      child: Semantics(
        label: signal.tooltip,
        child: child,
      ),
    );
  }
}

class _HomeNavSignals {
  const _HomeNavSignals({
    required this.map,
    required this.pet,
    required this.house,
    required this.dex,
    required this.profile,
  });

  final _HomeNavSignal map;
  final _HomeNavSignal pet;
  final _HomeNavSignal house;
  final _HomeNavSignal dex;
  final _HomeNavSignal profile;
}

class _HomeNavSignal {
  const _HomeNavSignal({
    required this.tooltip,
    this.badgeLabel,
    this.showBadge = true,
  });

  final String tooltip;
  final String? badgeLabel;
  final bool showBadge;
}

_HomeNavSignals _homeNavSignals(MasilPetState state) {
  final talksLeft = _homeTalksLeftToday(state);
  final undiscoveredCount =
      (state.templates.length - state.discoveredTemplateIds.length)
          .clamp(0, state.templates.length);

  return _HomeNavSignals(
    map: _mapNavSignal(state),
    pet: _HomeNavSignal(
      tooltip: talksLeft == 0 ? '마실펫 탭: 오늘 대화 완료' : '마실펫 탭: 대화 $talksLeft회 가능',
      badgeLabel: talksLeft == 0 ? null : '$talksLeft',
      showBadge: talksLeft > 0,
    ),
    house: _houseNavSignal(state),
    dex: _HomeNavSignal(
      tooltip: undiscoveredCount == 0
          ? '도감 탭: 전국 도감 완성'
          : '도감 탭: 미발견 $undiscoveredCount종',
      badgeLabel: undiscoveredCount == 0 ? null : '$undiscoveredCount',
      showBadge: undiscoveredCount > 0,
    ),
    profile: _HomeNavSignal(
      tooltip: state.currentVisitStreakDays == 0
          ? '기록 탭: 첫 산책을 기다리는 중'
          : '기록 탭: ${state.currentVisitStreakDays}일 연속 산책',
      badgeLabel: state.currentVisitStreakDays == 0
          ? null
          : '${state.currentVisitStreakDays}',
      showBadge: state.currentVisitStreakDays > 0,
    ),
  );
}

_HomeNavSignal _mapNavSignal(MasilPetState state) {
  if (state.todayCheckInCount > 0) {
    return _HomeNavSignal(
      tooltip: '지도 탭: 오늘 체크인 ${state.todayCheckInCount}회',
      badgeLabel: '${state.todayCheckInCount}',
    );
  }

  if (state.hasFreshVerifiedLocation && state.todayAvailableCheckInCount > 0) {
    return _HomeNavSignal(
      tooltip: '지도 탭: 체크인 가능 ${state.todayAvailableCheckInCount}곳',
      badgeLabel: '${state.todayAvailableCheckInCount}',
    );
  }

  return const _HomeNavSignal(
    tooltip: '지도 탭: 위치 확인 필요',
    showBadge: true,
  );
}

_HomeNavSignal _houseNavSignal(MasilPetState state) {
  if (state.hatchableEggCount > 0) {
    return _HomeNavSignal(
      tooltip: '하우스 탭: 부화 가능 ${state.hatchableEggCount}개',
      badgeLabel: '${state.hatchableEggCount}',
    );
  }

  if (state.eggs.isNotEmpty) {
    return _HomeNavSignal(
      tooltip: '하우스 탭: 알 ${state.eggs.length}개 관리',
      badgeLabel: '${state.eggs.length}',
    );
  }

  return const _HomeNavSignal(
    tooltip: '하우스 탭: 알 없음',
    showBadge: false,
  );
}

int _homeTalksLeftToday(MasilPetState state) {
  final countToday = isSameLocalDay(state.dialogueDay, DateTime.now())
      ? state.dialogueCountToday
      : 0;
  return (5 - countToday).clamp(0, 5).toInt();
}
