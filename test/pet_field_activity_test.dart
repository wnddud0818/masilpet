import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masilpet/src/models.dart';
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
          templates: busanPetTemplates,
          pets: state.pets,
          eggs: state.eggs,
          activePetId: state.activePetId,
          activity: state.fieldActivity,
          activityNonce: state.fieldActivityNonce,
        ),
      ),
    );

    final assetNames = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((image) => image.assetName)
        .toList();

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
          templates: busanPetTemplates,
          pets: state.pets,
          eggs: state.eggs,
          activePetId: state.activePetId,
          activity: state.fieldActivity,
          activityNonce: state.fieldActivityNonce,
        ),
      ),
    );

    final walkingFrameCount = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .where((image) => image.assetName.contains('/animations/walk_'))
        .length;

    expect(walkingFrameCount, greaterThanOrEqualTo(3));
  });
}
