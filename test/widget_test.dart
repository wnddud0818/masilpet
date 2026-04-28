import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:masilpet/src/app.dart';
import 'package:masilpet/src/state.dart';

void main() {
  testWidgets('MasilPet app starts in demo mode', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
        ],
        child: const MasilPetApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MasilPetApp), findsOneWidget);
  });
}
