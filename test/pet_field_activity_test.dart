import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masilpet/src/models.dart';
import 'package:masilpet/src/screens/home_shell.dart';
import 'package:masilpet/src/seed_data.dart';
import 'package:masilpet/src/services.dart';
import 'package:masilpet/src/state.dart';
import 'package:masilpet/src/widgets/pet_play_field.dart';

MasilPetController _controller() {
  return MasilPetController(
    firebaseReady: false,
    locationService: const DeviceLocationService(),
    backend: null,
    userRepository: null,
  );
}

String? _assetName(ImageProvider<Object> provider) {
  if (provider is AssetImage) {
    return provider.assetName;
  }
  if (provider is ResizeImage && provider.imageProvider is AssetImage) {
    return (provider.imageProvider as AssetImage).assetName;
  }
  return null;
}

List<String> _assetNames(WidgetTester tester) {
  return tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => _assetName(image.image))
      .nonNulls
      .toList();
}

PetPlayField _playField(
  MasilPetState state, {
  bool showVisitors = true,
}) {
  return PetPlayField(
    templates: starterPetTemplates,
    pets: state.pets,
    eggs: state.eggs,
    activePetId: state.activePetId,
    activity: state.fieldActivity,
    activityNonce: state.fieldActivityNonce,
    showVisitors: showVisitors,
  );
}

void main() {
  test('step progress triggers walking field activity', () async {
    final controller = _controller();

    await controller.addStepProgress(500);

    expect(controller.state.fieldActivity, PetFieldActivity.walking);
    expect(controller.state.fieldActivityNonce, 1);
  });

  test('talking triggers greeting field activity', () async {
    final controller = _controller();

    await controller.talkWithActivePet();

    expect(controller.state.fieldActivity, PetFieldActivity.greeting);
    expect(controller.state.fieldActivityNonce, 1);
  });

  test('feeding triggers eating field activity', () async {
    final controller = _controller();

    await controller.feedActivePet();

    expect(controller.state.fieldActivity, PetFieldActivity.eating);
    expect(controller.state.fieldActivityNonce, 1);
  });

  testWidgets('play field uses action animation frames for active pet',
      (tester) async {
    final controller = _controller();
    final state = controller.state.copyWith(
      fieldActivity: PetFieldActivity.eating,
      bumpFieldActivity: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PetPlayField(
          templates: starterPetTemplates,
          pets: state.pets,
          eggs: state.eggs,
          activePetId: state.activePetId,
          activity: state.fieldActivity,
          activityNonce: state.fieldActivityNonce,
        ),
      ),
    );

    final assetNames = _assetNames(tester);

    expect(
      assetNames.any((name) => name.contains('/animations/eat_')),
      isTrue,
    );
  });

  testWidgets('play field has several pets walking by default', (tester) async {
    final controller = _controller();
    final state = controller.state;

    await tester.pumpWidget(
      MaterialApp(
        home: PetPlayField(
          templates: starterPetTemplates,
          pets: state.pets,
          eggs: state.eggs,
          activePetId: state.activePetId,
          activity: state.fieldActivity,
          activityNonce: state.fieldActivityNonce,
        ),
      ),
    );

    final walkingFrameCount = _assetNames(tester)
        .where((assetName) => assetName.contains('/animations/walk_'))
        .length;

    expect(walkingFrameCount, greaterThanOrEqualTo(3));
  });

  testWidgets('play field renders the neighborhood yard scene', (tester) async {
    final controller = _controller();
    final state = controller.state;

    await tester.pumpWidget(
      MaterialApp(
        home: PetPlayField(
          templates: starterPetTemplates,
          pets: state.pets,
          eggs: state.eggs,
          activePetId: state.activePetId,
          activity: state.fieldActivity,
          activityNonce: state.fieldActivityNonce,
          height: 300,
          scene: PetPlayFieldScene.neighborhoodYard,
          spriteScale: 1.16,
        ),
      ),
    );

    final field = tester.widget<PetPlayField>(find.byType(PetPlayField));
    expect(field.scene, PetPlayFieldScene.neighborhoodYard);
    expect(field.height, 300);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('play field stops and resumes with TickerMode', (tester) async {
    final state = _controller().state;
    final tickersEnabled = ValueNotifier(true);
    addTearDown(tickersEnabled.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: tickersEnabled,
          builder: (context, enabled, child) {
            return TickerMode(
              enabled: enabled,
              child: _playField(state),
            );
          },
        ),
      ),
    );

    final initialFrames = _assetNames(tester);
    await tester.pump(const Duration(milliseconds: 350));
    expect(_assetNames(tester), isNot(equals(initialFrames)));

    tickersEnabled.value = false;
    await tester.pump();
    final stoppedFrames = _assetNames(tester);
    await tester.pump(const Duration(milliseconds: 900));
    expect(_assetNames(tester), stoppedFrames);

    tickersEnabled.value = true;
    await tester.pump();
    final resumedFrames = _assetNames(tester);
    await tester.pump(const Duration(milliseconds: 350));
    expect(_assetNames(tester), isNot(equals(resumedFrames)));
  });

  testWidgets('play field respects reduced motion', (tester) async {
    final state = _controller().state;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _playField(state),
        ),
      ),
    );

    final initialFrames = _assetNames(tester);
    await tester.pump(const Duration(milliseconds: 900));
    expect(_assetNames(tester), initialFrames);
  });

  testWidgets('play field describes activity and can hide visitors',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = _controller();
      final state = controller.state.copyWith(
        fieldActivity: PetFieldActivity.eating,
        bumpFieldActivity: true,
      );
      const radius = BorderRadius.all(Radius.circular(24));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            cardTheme: const CardThemeData(
              shape: RoundedRectangleBorder(borderRadius: radius),
            ),
          ),
          home: _playField(state, showVisitors: false),
        ),
      );

      expect(_assetNames(tester), hasLength(1));
      expect(
        find.bySemanticsLabel(
          '마실펫 놀이터. 대표 마실펫 파도나루, 간식을 먹는 중. 함께 있는 마실펫 1마리.',
        ),
        findsOneWidget,
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.filterQuality, FilterQuality.none);
      expect(image.image, isA<ResizeImage>());
      final provider = image.image as ResizeImage;
      expect(provider.width, inInclusiveRange(64, 256));
      expect(provider.height, provider.width);
      expect(
        tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
        radius,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('home shell enables tickers only for the selected tab',
      (tester) async {
    final controller = _controller()..setTab(2);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          masilPetControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pump();

    var stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.children, everyElement(isA<TickerMode>()));
    expect(
      stack.children.cast<TickerMode>().map((mode) => mode.enabled),
      [false, false, true, false, false],
    );

    controller.setTab(4);
    await tester.pump();
    stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(
      stack.children.cast<TickerMode>().map((mode) => mode.enabled),
      [false, false, false, false, true],
    );
  });
}
