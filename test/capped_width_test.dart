import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takt/widgets/capped_width.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size, Widget child) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CappedWidth(child: child)),
      ),
    );
  }

  testWidgets('leaves content unconstrained below the Medium breakpoint (compact)', (tester) async {
    await pumpAt(tester, const Size(400, 800), const SizedBox(key: Key('probe'), width: 900, height: 10));

    final renderBox = tester.renderObject<RenderBox>(find.byKey(const Key('probe')));
    expect(renderBox.size.width, 400); // clamped only by the actual screen width, not CappedWidth
  });

  testWidgets('caps content to maxWidth and centers it at Medium+', (tester) async {
    await pumpAt(tester, const Size(1200, 800), const SizedBox(key: Key('probe'), width: 900, height: 10));

    final renderBox = tester.renderObject<RenderBox>(find.byKey(const Key('probe')));
    expect(renderBox.size.width, 600); // default maxWidth

    final topLeft = renderBox.localToGlobal(Offset.zero);
    expect(topLeft.dx, closeTo((1200 - 600) / 2, 0.5)); // centered
  });

  testWidgets('honors a custom maxWidth', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CappedWidth(
            maxWidth: 480,
            child: const SizedBox(key: Key('probe'), width: 900, height: 10),
          ),
        ),
      ),
    );

    final renderBox = tester.renderObject<RenderBox>(find.byKey(const Key('probe')));
    expect(renderBox.size.width, 480);
  });
}
