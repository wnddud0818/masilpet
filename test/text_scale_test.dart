import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masilpet/src/screens/dex_screen.dart';
import 'package:masilpet/src/screens/house_screen.dart';
import 'package:masilpet/src/screens/map_screen.dart';
import 'package:masilpet/src/screens/onboarding_screen.dart';
import 'package:masilpet/src/screens/pet_screen.dart';
import 'package:masilpet/src/screens/profile_screen.dart';
import 'package:masilpet/src/services.dart';
import 'package:masilpet/src/state.dart';
import 'package:masilpet/src/theme.dart';

/// Every page has to survive the reader turning their system text size up.
/// Overflow here is not cosmetic: a clipped RenderFlex hides content outright,
/// and the people who need large type are exactly the ones who would lose it.
///
/// 2.5× is roughly Android's largest accessibility step.

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

const _screens = <String, Widget>{
  '지도': MapScreen(),
  '마실펫': PetScreen(),
  '하우스': HouseScreen(),
  '도감': DexScreen(),
  '기록': ProfileScreen(),
  '온보딩': OnboardingScreen(),
};

const _widths = <String, Size>{
  '320px': Size(320, 740),
  '390px': Size(390, 844),
};

const _scales = [1.3, 1.6, 2.0, 2.5];

void main() {
  for (final width in _widths.entries) {
    for (final scale in _scales) {
      for (final screen in _screens.entries) {
        testWidgets('${screen.key} survives ${scale}x text at ${width.key}',
            (WidgetTester tester) async {
          tester.view.physicalSize = width.value;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          // Layout errors are reported, not thrown, so they have to be
          // collected rather than caught.
          final reported = <FlutterErrorDetails>[];
          final previousOnError = FlutterError.onError;
          FlutterError.onError = reported.add;

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                masilPetControllerProvider.overrideWith((ref) => _controller()),
              ],
              child: MaterialApp(
                theme: buildMasilPetTheme(),
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(body: screen.value),
                ),
              ),
            ),
          );
          // The pet stage and map pins animate forever, so settle a slice.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          FlutterError.onError = previousOnError;

          expect(
            reported.map((detail) => detail.exception.toString()).toList(),
            isEmpty,
            reason: '${screen.key} @ ${scale}x / ${width.key}',
          );
        });
      }
    }
  }
}
