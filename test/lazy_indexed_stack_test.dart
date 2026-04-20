import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyed_indexed_stack/keyed_indexed_stack.dart';

enum Tab { home, search, profile, settings, about }

/// A widget that records when its [initState] and [dispose] are called.
class _TrackedChild extends StatefulWidget {
  const _TrackedChild(this.label, this.onInit, this.onDispose);
  final String label;
  final VoidCallback onInit;
  final VoidCallback onDispose;

  @override
  State<_TrackedChild> createState() => _TrackedChildState();
}

class _TrackedChildState extends State<_TrackedChild> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

class _TickingChild extends StatefulWidget {
  const _TickingChild(this.tab, this.tickCounts);

  final Tab tab;
  final Map<Tab, int> tickCounts;

  @override
  State<_TickingChild> createState() => _TickingChildState();
}

class _TickingChildState extends State<_TickingChild>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )
      ..addListener(() {
        widget.tickCounts[widget.tab] =
            (widget.tickCounts[widget.tab] ?? 0) + 1;
      })
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('Ticker ${widget.tab.name}');
}

void main() {
  group('LazyIndexedStack', () {
    Widget buildSut({
      required Tab index,
      Set<Tab>? keepAlive,
      Set<Tab>? preheat,
      LazyIndexedStackController<Tab>? controller,
      OnSwitchCallback<Tab>? onSwitch,
      OnChildCallback<Tab>? onChildBuilt,
      OnChildCallback<Tab>? onChildDisposed,
      OnChildCallback<Tab>? onIndexRequested,
    }) {
      return MaterialApp(
        home: LazyIndexedStack<Tab>(
          index: index,
          keepAlive: keepAlive ?? const {},
          preheat: preheat ?? const {},
          controller: controller,
          onSwitch: onSwitch,
          onChildBuilt: onChildBuilt,
          onChildDisposed: onChildDisposed,
          onIndexRequested: onIndexRequested,
          builder: (context, key) => Text('Page ${key.name}'),
        ),
      );
    }

    testWidgets('only builds the active key initially', (tester) async {
      final builtKeys = <Tab>[];
      await tester.pumpWidget(MaterialApp(
        home: LazyIndexedStack<Tab>(
          index: Tab.profile,
          onChildBuilt: builtKeys.add,
          builder: (context, key) => Text('Page ${key.name}'),
        ),
      ));
      await tester.pump();
      expect(builtKeys, [Tab.profile]);
    });

    testWidgets('builds new key on switch and fires onSwitch', (tester) async {
      final switches = <(Tab, Tab)>[];
      final builtKeys = <Tab>[];
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        onSwitch: (from, to) => switches.add((from, to)),
        onChildBuilt: builtKeys.add,
      ));
      await tester.pump();
      expect(builtKeys, [Tab.home]);

      await tester.pumpWidget(buildSut(
        index: Tab.search,
        onSwitch: (from, to) => switches.add((from, to)),
        onChildBuilt: builtKeys.add,
      ));
      await tester.pump();
      expect(switches, [(Tab.home, Tab.search)]);
      expect(builtKeys, [Tab.home, Tab.search]);
    });

    testWidgets('disposes old child when switching away (not keepAlive)',
        (tester) async {
      final disposed = <Tab>[];
      final built = <Tab>[];
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        onChildBuilt: built.add,
        onChildDisposed: disposed.add,
      ));
      await tester.pump();
      expect(built, [Tab.home]);

      await tester.pumpWidget(buildSut(
        index: Tab.search,
        onChildBuilt: built.add,
        onChildDisposed: disposed.add,
      ));
      await tester.pump();
      expect(disposed, [Tab.home]);
    });

    testWidgets('keeps alive keys in keepAlive set', (tester) async {
      final disposed = <Tab>[];
      final built = <Tab>[];
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        keepAlive: {Tab.home},
        onChildBuilt: built.add,
        onChildDisposed: disposed.add,
      ));
      await tester.pump();
      expect(built, [Tab.home]);

      await tester.pumpWidget(buildSut(
        index: Tab.search,
        keepAlive: {Tab.home},
        onChildBuilt: built.add,
        onChildDisposed: disposed.add,
      ));
      await tester.pump();
      expect(disposed, isEmpty);
      expect(built, [Tab.home, Tab.search]);
    });

    testWidgets('preheats keys declared in preheat set', (tester) async {
      final built = <Tab>[];
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        preheat: {Tab.profile, Tab.settings},
        onChildBuilt: built.add,
      ));
      await tester.pump();
      expect(built, containsAll([Tab.home, Tab.profile, Tab.settings]));
    });

    testWidgets('preheated children are offstage (not visible)',
        (tester) async {
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        preheat: {Tab.search},
      ));
      expect(find.text('Page home'), findsOneWidget);
      final pageSearch = find.text('Page search', skipOffstage: false);
      expect(pageSearch, findsOneWidget);
      final offstageFinder = find.ancestor(
        of: pageSearch,
        matching: find.byWidgetPredicate(
          (widget) => widget is Offstage && widget.offstage,
        ),
      );
      expect(offstageFinder, findsOneWidget);
    });

    testWidgets('controller.preheat builds children', (tester) async {
      final controller = LazyIndexedStackController<Tab>();
      final built = <Tab>[];
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        controller: controller,
        onChildBuilt: built.add,
      ));
      await tester.pump();
      expect(built, [Tab.home]);

      controller.preheat({Tab.profile});
      await tester.pump();
      expect(built, [Tab.home, Tab.profile]);
    });

    testWidgets('controller.disposeKeys releases controller-preheated children',
        (tester) async {
      final controller = LazyIndexedStackController<Tab>();
      final disposed = <Tab>[];
      final built = <Tab>[];
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        controller: controller,
        onChildBuilt: built.add,
        onChildDisposed: disposed.add,
      ));
      await tester.pump();
      expect(built, [Tab.home]);

      controller.preheat({Tab.profile});
      await tester.pump();
      expect(built, [Tab.home, Tab.profile]);

      controller.disposeKeys({Tab.profile});
      await tester.pump();
      expect(disposed, [Tab.profile]);
    });

    testWidgets('controller.disposeKeys does not remove declarative preheat',
        (tester) async {
      final controller = LazyIndexedStackController<Tab>();
      final disposed = <Tab>[];
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        preheat: {Tab.profile},
        controller: controller,
        onChildDisposed: disposed.add,
      ));
      await tester.pump();

      controller.disposeKeys({Tab.profile});
      await tester.pump();

      expect(disposed, isEmpty);
      expect(controller.isBuilt(Tab.profile), isTrue);
    });

    testWidgets('controller.addKeepAlive and removeKeepAlive work',
        (tester) async {
      final controller = LazyIndexedStackController<Tab>();
      final disposed = <Tab>[];
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        controller: controller,
        onChildDisposed: disposed.add,
      ));
      await tester.pump();

      controller.preheat({Tab.profile});
      await tester.pump();
      controller.addKeepAlive({Tab.profile});
      await tester.pump();

      await tester.pumpWidget(buildSut(
        index: Tab.search,
        controller: controller,
        onChildDisposed: disposed.add,
      ));
      await tester.pump();
      expect(disposed, [Tab.home]);
      expect(controller.isBuilt(Tab.profile), isTrue);

      controller.removeKeepAlive({Tab.profile});
      await tester.pump();
      expect(controller.isBuilt(Tab.profile), isTrue); // still preheated

      controller.disposeKeys({Tab.profile});
      await tester.pump();
      expect(disposed, [Tab.home, Tab.profile]);
    });

    testWidgets('controller.forceDisposeKeys removes declarative preheat',
        (tester) async {
      final controller = LazyIndexedStackController<Tab>();
      final disposed = <Tab>[];
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        preheat: {Tab.profile},
        controller: controller,
        onChildDisposed: disposed.add,
      ));
      await tester.pump();
      expect(controller.isBuilt(Tab.profile), isTrue);

      controller.forceDisposeKeys({Tab.profile});
      await tester.pump();

      expect(disposed, [Tab.profile]);
      expect(controller.isBuilt(Tab.profile), isFalse);
    });

    testWidgets('controller.forceDisposeKeys removes declarative keepAlive',
        (tester) async {
      final controller = LazyIndexedStackController<Tab>();
      final disposed = <Tab>[];
      await tester.pumpWidget(buildSut(
        index: Tab.search,
        keepAlive: {Tab.profile},
        controller: controller,
        onChildDisposed: disposed.add,
      ));
      await tester.pump();
      expect(controller.isBuilt(Tab.profile), isTrue);

      controller.forceDisposeKeys({Tab.profile});
      await tester.pump();

      expect(disposed, [Tab.profile]);
      expect(controller.isBuilt(Tab.profile), isFalse);
    });

    testWidgets('controller.forceDisposeKeys does not remove active key',
        (tester) async {
      final controller = LazyIndexedStackController<Tab>();
      final disposed = <Tab>[];
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        controller: controller,
        onChildDisposed: disposed.add,
      ));
      await tester.pump();

      controller.forceDisposeKeys({Tab.home});
      await tester.pump();

      expect(disposed, isEmpty);
      expect(controller.isBuilt(Tab.home), isTrue);
    });

    testWidgets('controller.preheat clears forced disposal for a key',
        (tester) async {
      final controller = LazyIndexedStackController<Tab>();
      final disposed = <Tab>[];
      final built = <Tab>[];
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        preheat: {Tab.profile},
        controller: controller,
        onChildBuilt: built.add,
        onChildDisposed: disposed.add,
      ));
      await tester.pump();
      expect(built, containsAll([Tab.home, Tab.profile]));

      controller.forceDisposeKeys({Tab.profile});
      await tester.pump();
      expect(disposed, [Tab.profile]);
      expect(controller.isBuilt(Tab.profile), isFalse);

      controller.preheat({Tab.profile});
      await tester.pump();
      expect(controller.isBuilt(Tab.profile), isTrue);
      expect(built, contains(Tab.profile));
    });

    testWidgets('controller.builtKeys and isBuilt report correctly',
        (tester) async {
      final controller = LazyIndexedStackController<Tab>();
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        preheat: {Tab.search},
        controller: controller,
      ));
      await tester.pump();

      expect(controller.builtKeys, {Tab.home, Tab.search});
      expect(controller.isBuilt(Tab.home), isTrue);
      expect(controller.isBuilt(Tab.search), isTrue);
      expect(controller.isBuilt(Tab.profile), isFalse);
      expect(controller.currentKey, Tab.home);
    });

    testWidgets('preserves state of kept-alive children', (tester) async {
      final controller = LazyIndexedStackController<Tab>();
      final initCounts = <Tab, int>{};
      final disposeCounts = <Tab, int>{};

      Widget buildApp(Tab index) => MaterialApp(
            home: LazyIndexedStack<Tab>(
              index: index,
              controller: controller,
              builder: (context, key) => _TrackedChild(
                'Page ${key.name}',
                () => initCounts[key] = (initCounts[key] ?? 0) + 1,
                () => disposeCounts[key] = (disposeCounts[key] ?? 0) + 1,
              ),
            ),
          );

      await tester.pumpWidget(buildApp(Tab.home));
      await tester.pump();
      expect(initCounts[Tab.home], 1);

      await tester.pumpWidget(buildApp(Tab.search));
      await tester.pump();
      expect(initCounts[Tab.search], 1);
      expect(disposeCounts[Tab.home], 1);

      await tester.pumpWidget(buildApp(Tab.home));
      await tester.pump();
      expect(initCounts[Tab.home], 2);
    });

    testWidgets('state preserved with keepAlive', (tester) async {
      final initCounts = <Tab, int>{};
      final disposeCounts = <Tab, int>{};

      Widget buildApp(Tab index) => MaterialApp(
            home: LazyIndexedStack<Tab>(
              index: index,
              keepAlive: {Tab.home},
              builder: (context, key) => _TrackedChild(
                'Page ${key.name}',
                () => initCounts[key] = (initCounts[key] ?? 0) + 1,
                () => disposeCounts[key] = (disposeCounts[key] ?? 0) + 1,
              ),
            ),
          );

      await tester.pumpWidget(buildApp(Tab.home));
      await tester.pump();
      expect(initCounts[Tab.home], 1);

      await tester.pumpWidget(buildApp(Tab.search));
      await tester.pump();
      expect(disposeCounts[Tab.home], isNull);
      expect(initCounts[Tab.home], 1);
    });

    testWidgets('inactive keepAlive child pauses ticker by default',
        (tester) async {
      final tickCounts = <Tab, int>{};

      Widget buildApp(Tab index) => MaterialApp(
            home: LazyIndexedStack<Tab>(
              index: index,
              keepAlive: {Tab.home},
              builder: (context, key) => _TickingChild(key, tickCounts),
            ),
          );

      await tester.pumpWidget(buildApp(Tab.home));
      await tester.pump(const Duration(milliseconds: 200));
      final homeWhileActive = tickCounts[Tab.home] ?? 0;
      expect(homeWhileActive, greaterThan(0));

      await tester.pumpWidget(buildApp(Tab.search));
      await tester.pump();
      final beforeInactivePump = tickCounts[Tab.home] ?? 0;
      await tester.pump(const Duration(milliseconds: 200));
      expect(tickCounts[Tab.home] ?? 0, beforeInactivePump);

      await tester.pumpWidget(buildApp(Tab.home));
      await tester.pump();
      final beforeResumePump = tickCounts[Tab.home] ?? 0;
      await tester.pump(const Duration(milliseconds: 200));
      expect(tickCounts[Tab.home] ?? 0, greaterThan(beforeResumePump));
    });

    testWidgets('inactive preheated child pauses ticker by default',
        (tester) async {
      final tickCounts = <Tab, int>{};

      await tester.pumpWidget(MaterialApp(
        home: LazyIndexedStack<Tab>(
          index: Tab.home,
          preheat: {Tab.profile},
          builder: (context, key) => _TickingChild(key, tickCounts),
        ),
      ));
      await tester.pump();
      final beforePump = tickCounts[Tab.profile] ?? 0;
      await tester.pump(const Duration(milliseconds: 200));
      expect(tickCounts[Tab.profile] ?? 0, beforePump);
    });

    testWidgets('global inactive animation policy preserves old behavior',
        (tester) async {
      final tickCounts = <Tab, int>{};

      await tester.pumpWidget(MaterialApp(
        home: LazyIndexedStack<Tab>(
          index: Tab.search,
          keepAlive: {Tab.home},
          maintainAnimationWhenInactive: true,
          builder: (context, key) => _TickingChild(key, tickCounts),
        ),
      ));
      await tester.pump();
      final beforePump = tickCounts[Tab.home] ?? 0;
      await tester.pump(const Duration(milliseconds: 200));
      expect(tickCounts[Tab.home] ?? 0, greaterThan(beforePump));
    });

    testWidgets(
        'per-key inactive animation override keeps selected ticker running',
        (tester) async {
      final tickCounts = <Tab, int>{};

      await tester.pumpWidget(MaterialApp(
        home: LazyIndexedStack<Tab>(
          index: Tab.home,
          preheat: {Tab.profile, Tab.settings},
          maintainAnimationWhenInactiveKeys: {Tab.profile},
          builder: (context, key) => _TickingChild(key, tickCounts),
        ),
      ));
      await tester.pump();
      final profileBeforePump = tickCounts[Tab.profile] ?? 0;
      final settingsBeforePump = tickCounts[Tab.settings] ?? 0;
      await tester.pump(const Duration(milliseconds: 200));
      expect(tickCounts[Tab.profile] ?? 0, greaterThan(profileBeforePump));
      expect(tickCounts[Tab.settings] ?? 0, settingsBeforePump);
    });

    testWidgets('works with String keys', (tester) async {
      final built = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: LazyIndexedStack<String>(
          index: 'a',
          keepAlive: {'a'},
          preheat: {'b'},
          onChildBuilt: built.add,
          builder: (context, key) => Text('Page $key'),
        ),
      ));
      await tester.pump();
      expect(built, containsAll(['a', 'b']));
    });

    testWidgets('removes keys no longer in keepAlive/preheat on update',
        (tester) async {
      final disposed = <Tab>[];
      final built = <Tab>[];
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        preheat: {Tab.about},
        onChildBuilt: built.add,
        onChildDisposed: disposed.add,
      ));
      await tester.pump();
      expect(built, containsAll([Tab.home, Tab.about]));

      // Remove preheat for about — should be disposed.
      await tester.pumpWidget(buildSut(
        index: Tab.home,
        onChildBuilt: built.add,
        onChildDisposed: disposed.add,
      ));
      await tester.pump();
      expect(disposed, [Tab.about]);
    });

    testWidgets('controller.switchTo triggers onIndexRequested',
        (tester) async {
      final controller = LazyIndexedStackController<Tab>();
      final requested = <Tab>[];

      await tester.pumpWidget(buildSut(
        index: Tab.home,
        controller: controller,
        onIndexRequested: requested.add,
      ));
      await tester.pump();

      controller.switchTo(Tab.profile);
      expect(requested, [Tab.profile]);
    });
  });
}
