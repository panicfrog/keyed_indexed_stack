import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('profiling demo renders both comparison stacks', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());

    expect(find.text('LazyIndexedStack Profiling Demo'), findsOneWidget);
    expect(find.text('Paused When Inactive'), findsOneWidget);
    expect(find.text('Maintained When Inactive'), findsOneWidget);
    expect(find.text('Tick count'), findsNWidgets(2));
  });
}
