import 'package:flutter_test/flutter_test.dart';

import 'package:masilpet/src/models.dart';

void main() {
  test('pet rarity values have localized display labels', () {
    expect(rarityDisplayLabel('common'), '일반');
    expect(rarityDisplayLabel('rare'), '희귀');
    expect(rarityDisplayLabel('epic'), '영웅');
    expect(rarityDisplayLabel('seasonal'), 'seasonal');
  });
}
