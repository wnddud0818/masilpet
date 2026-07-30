import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masilpet/src/widgets/paper_shell.dart';

/// The five home tabs, every one carrying a badge so the badge geometry is
/// covered too.
const _items = [
  PaperNavItem(label: '지도', number: '01', tooltip: '지도 탭', badge: '2'),
  PaperNavItem(label: '하우스', number: '02', tooltip: '하우스 탭', badge: '1'),
  PaperNavItem(label: '마실펫', number: '03', tooltip: '마실펫 탭', badge: '3'),
  PaperNavItem(label: '도감', number: '04', tooltip: '도감 탭', badge: '36'),
  PaperNavItem(label: '기록', number: '05', tooltip: '기록 탭', badge: '12'),
];

Future<void> _pumpTabBar(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const Spacer(),
            PaperTabBar(items: _items, activeIndex: 2, onSelected: (_) {}),
          ],
        ),
      ),
    ),
  );
}

Finder _tabs() => find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_PaperTab',
    );

Finder _badges() => find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_NavBadge',
    );

void main() {
  // Phone widths the mobile layout has to survive, narrowest first.
  const widths = [Size(320, 640), Size(360, 800), Size(390, 844)];

  for (final size in widths) {
    final label = '${size.width.toInt()}px';

    testWidgets('$label: every tab label is centred in its cell', (
      tester,
    ) async {
      await _pumpTabBar(tester, size);

      for (final (index, item) in _items.indexed) {
        final cell = tester.getRect(_tabs().at(index));
        final text = tester.getRect(find.text(item.label));

        expect(
          text.center.dx,
          moreOrLessEquals(cell.center.dx, epsilon: 0.5),
          reason: '${item.label} label drifted off its cell centre',
        );
      }
    });

    testWidgets('$label: badges stay inside their own cell', (tester) async {
      await _pumpTabBar(tester, size);

      // The active tab hides its badge, so the remaining four map onto the
      // inactive cells in order.
      final cells = [0, 1, 3, 4];
      expect(_badges(), findsNWidgets(cells.length));

      for (final (badgeIndex, cellIndex) in cells.indexed) {
        final cell = tester.getRect(_tabs().at(cellIndex));
        final badge = tester.getRect(_badges().at(badgeIndex));

        expect(
          badge.left >= cell.left && badge.right <= cell.right,
          isTrue,
          reason: 'badge on ${_items[cellIndex].label} overflows its cell '
              '($badge vs $cell)',
        );
      }
    });
  }
}
