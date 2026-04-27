import 'package:flutter_test/flutter_test.dart';
import 'package:masilpet/src/models.dart';
import 'package:masilpet/src/services.dart';

void main() {
  test('same coordinates are inside check-in radius', () {
    const haeundae = Coordinates(latitude: 35.1587, longitude: 129.1604);

    expect(haeundae.distanceTo(haeundae), lessThan(1));
    expect(haeundae.distanceTo(haeundae), lessThan(checkInRadiusMeters));
  });

  test('different Busan landmarks are outside check-in radius', () {
    const haeundae = Coordinates(latitude: 35.1587, longitude: 129.1604);
    const jagalchi = Coordinates(latitude: 35.0969, longitude: 129.0305);

    expect(haeundae.distanceTo(jagalchi), greaterThan(checkInRadiusMeters));
  });

  test('local day comparison ignores time within a day', () {
    expect(
      isSameLocalDay(DateTime(2026, 4, 27, 9), DateTime(2026, 4, 27, 23)),
      isTrue,
    );
    expect(
      isSameLocalDay(DateTime(2026, 4, 27, 23), DateTime(2026, 4, 28, 0)),
      isFalse,
    );
  });
}
