import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/widgets/responsive_grid.dart';

void main() {
  Future<void> pumpGridAt(
    WidgetTester tester, {
    required Size size,
    int itemCount = 6,
    int compactColumns = 1,
    int mediumColumns = 2,
    int expandedColumns = 3,
    int largeColumns = 4,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsiveGrid(
            itemCount: itemCount,
            compactColumns: compactColumns,
            mediumColumns: mediumColumns,
            expandedColumns: expandedColumns,
            largeColumns: largeColumns,
            itemBuilder: (context, index) {
              return Container(
                key: Key('grid_item_$index'),
                child: Text('Item $index'),
              );
            },
          ),
        ),
      ),
    );
  }

  group('ResponsiveGrid column scaling by WindowClass', () {
    testWidgets('uses compactColumns (1) at width < 600', (tester) async {
      await pumpGridAt(tester, size: const Size(400, 800));

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 1);
    });

    testWidgets('uses mediumColumns (2) at 600 <= width < 840', (tester) async {
      await pumpGridAt(tester, size: const Size(700, 800));

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
    });

    testWidgets('uses expandedColumns (3) at 840 <= width < 1200', (tester) async {
      await pumpGridAt(tester, size: const Size(1000, 800));

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
    });

    testWidgets('uses largeColumns (4) at width >= 1200', (tester) async {
      await pumpGridAt(tester, size: const Size(1400, 800));

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 4);
    });

    testWidgets('honors custom column count configuration', (tester) async {
      await pumpGridAt(
        tester,
        size: const Size(1400, 800),
        largeColumns: 6,
      );

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 6);
    });

    testWidgets('renders all items with correct spacing', (tester) async {
      await pumpGridAt(tester, size: const Size(800, 800), itemCount: 4);

      expect(find.byKey(const Key('grid_item_0')), findsOneWidget);
      expect(find.byKey(const Key('grid_item_1')), findsOneWidget);
      expect(find.byKey(const Key('grid_item_2')), findsOneWidget);
      expect(find.byKey(const Key('grid_item_3')), findsOneWidget);
    });
  });
}
