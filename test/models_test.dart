import 'package:flutter_test/flutter_test.dart';

import 'package:masilpet/src/models.dart';

void main() {
  test('pet rarity values have localized display labels', () {
    expect(rarityDisplayLabel('common'), '일반');
    expect(rarityDisplayLabel('rare'), '희귀');
    expect(rarityDisplayLabel('epic'), '영웅');
    expect(rarityDisplayLabel('seasonal'), 'seasonal');
  });

  test('check-in reward summary lists all visible growth rewards', () {
    const reward = CheckInReward(
      stats: GrowthStats(exp: 18, mood: 8, knowledge: 4, affinity: 12),
      eggProgress: 680,
    );

    expect(
      reward.summaryLabel,
      'EXP +18 · 기분 +8 · 지식 +4 · 친밀도 +12 · 알 +680',
    );
  });
}
