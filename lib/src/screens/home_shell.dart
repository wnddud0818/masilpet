import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state.dart';
import 'dex_screen.dart';
import 'house_screen.dart';
import 'map_screen.dart';
import 'pet_screen.dart';
import 'profile_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _wideNavigationBreakpoint = 720.0;
  static const _extendedRailBreakpoint = 1040.0;

  static const _screens = [
    MapScreen(),
    PetScreen(),
    HouseScreen(),
    DexScreen(),
    ProfileScreen(),
  ];

  static const _navigationDestinations = [
    NavigationDestination(
      icon: Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map),
      label: '지도',
    ),
    NavigationDestination(
      icon: Icon(Icons.pets_outlined),
      selectedIcon: Icon(Icons.pets),
      label: '마실펫',
    ),
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: '하우스',
    ),
    NavigationDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book),
      label: '도감',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: '내 정보',
    ),
  ];

  static const _railDestinations = [
    NavigationRailDestination(
      icon: Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map),
      label: Text('지도'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.pets_outlined),
      selectedIcon: Icon(Icons.pets),
      label: Text('마실펫'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: Text('하우스'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book),
      label: Text('도감'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: Text('내 정보'),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(
      masilPetControllerProvider.select((state) => state.selectedTab),
    );
    final controller = ref.read(masilPetControllerProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= _wideNavigationBreakpoint;
        if (!useRail) {
          return Scaffold(
            body: const SafeArea(child: _HomeTabStack()),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: controller.setTab,
              destinations: _navigationDestinations,
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
                  selectedIndex: tab,
                  onDestinationSelected: controller.setTab,
                  destinations: _railDestinations,
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
      children: HomeShell._screens,
    );
  }
}
