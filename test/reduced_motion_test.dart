import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masilpet/src/widgets/paper_kit.dart';

/// The looping decoration in `paper_kit` is atmosphere, not information, so
/// the platform's "reduce motion" setting has to hold every one of them still.
/// `PetPlayField` already honours the setting; these cover the rest.

const _markerKey = Key('motion-probe');

Widget _host({required Widget child, required bool disableAnimations}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );
}

const _probe = SizedBox(key: _markerKey, width: 40, height: 40);

/// Pumps a slice long enough for each loop to visibly move, then reports
/// whether the probe ended up somewhere else. The probe has to sit *inside*
/// the transform being tested, since a transform leaves its own box alone.
Future<bool> _movesOverTime(WidgetTester tester, [Finder? probe]) async {
  final target = probe ?? find.byKey(_markerKey);
  final before = tester.getRect(target);
  await tester.pump(const Duration(milliseconds: 700));
  return tester.getRect(target) != before;
}

/// The ring PulseRing scales; it owns no child slot to key.
Finder _pulseRingCircle() => find.descendant(
      of: find.byType(PulseRing),
      matching: find.byType(Container),
    );

void main() {
  group('BobbingSprite', () {
    testWidgets('floats when motion is allowed', (tester) async {
      await tester.pumpWidget(
        _host(
          child: const BobbingSprite(child: _probe),
          disableAnimations: false,
        ),
      );
      expect(await _movesOverTime(tester), isTrue);
    });

    testWidgets('stands still under reduced motion', (tester) async {
      await tester.pumpWidget(
        _host(
          child: const BobbingSprite(child: _probe),
          disableAnimations: true,
        ),
      );
      expect(await _movesOverTime(tester), isFalse);
    });

    testWidgets('rests on the ground rather than frozen mid-float',
        (tester) async {
      await tester.pumpWidget(
        _host(
          child: const BobbingSprite(child: _probe),
          disableAnimations: true,
        ),
      );
      final still = tester.getRect(find.byKey(_markerKey));

      // The same probe with no bobbing at all, for comparison.
      await tester.pumpWidget(
        _host(child: _probe, disableAnimations: true),
      );
      expect(tester.getRect(find.byKey(_markerKey)), still);
    });
  });

  group('PulseRing', () {
    testWidgets('breathes when motion is allowed', (tester) async {
      await tester.pumpWidget(
        _host(child: const PulseRing(size: 40), disableAnimations: false),
      );
      expect(await _movesOverTime(tester, _pulseRingCircle()), isTrue);
    });

    testWidgets('holds one halo under reduced motion', (tester) async {
      await tester.pumpWidget(
        _host(child: const PulseRing(size: 40), disableAnimations: true),
      );
      expect(await _movesOverTime(tester, _pulseRingCircle()), isFalse);
      // The halo is still drawn; it just stopped pulsing.
      expect(_pulseRingCircle(), findsOneWidget);
    });
  });

  group('ShakeLoop', () {
    testWidgets('shakes a ready egg when motion is allowed', (tester) async {
      await tester.pumpWidget(
        _host(
          child: const ShakeLoop(child: _probe),
          disableAnimations: false,
        ),
      );
      expect(await _movesOverTime(tester), isTrue);
    });

    testWidgets('sits still under reduced motion', (tester) async {
      await tester.pumpWidget(
        _host(
          child: const ShakeLoop(child: _probe),
          disableAnimations: true,
        ),
      );
      expect(await _movesOverTime(tester), isFalse);
    });

    testWidgets('an inactive egg is still, motion setting aside',
        (tester) async {
      await tester.pumpWidget(
        _host(
          child: const ShakeLoop(active: false, child: _probe),
          disableAnimations: false,
        ),
      );
      expect(await _movesOverTime(tester), isFalse);
    });
  });

  group('StampOverlay', () {
    testWidgets('lands by fading instead of swinging in, when motion is cut',
        (tester) async {
      await tester.pumpWidget(
        _host(
          child: const StampOverlay(dateLabel: '2026.08.03'),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      final early = tester.getRect(find.text('방문 인증'));
      await tester.pump(const Duration(milliseconds: 260));
      // The stamp is already at rest, so only its opacity is still moving.
      expect(tester.getRect(find.text('방문 인증')), early);
      expect(find.text('2026.08.03'), findsOneWidget);
    });

    testWidgets('swings down onto the page when motion is allowed',
        (tester) async {
      await tester.pumpWidget(
        _host(
          child: const StampOverlay(dateLabel: '2026.08.03'),
          disableAnimations: false,
        ),
      );
      await tester.pump();

      final early = tester.getRect(find.text('방문 인증'));
      await tester.pump(const Duration(milliseconds: 260));
      expect(tester.getRect(find.text('방문 인증')), isNot(early));
    });
  });
}
