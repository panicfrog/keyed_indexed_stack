import 'package:flutter/material.dart';
import 'package:keyed_indexed_stack/keyed_indexed_stack.dart';

enum AppTab { home, search, profile, settings, about }

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LazyIndexedStack Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  AppTab _currentTab = AppTab.home;
  final _controller = LazyIndexedStackController<AppTab>();
  final _log = <String>[];


  void _logEvent(String event) {
    setState(() {
      _log.insert(0, event);
      if (_log.length > 20) _log.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LazyIndexedStack Demo'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) {
              switch (action) {
                case 'preheat':
                  _controller.preheat({AppTab.about});
                  _logEvent('Preheated ${AppTab.about.name}');
                case 'switchTo':
                  _controller.switchTo(AppTab.profile);
                  _logEvent('SwitchTo ${AppTab.profile.name}');
                case 'dispose':
                  _controller.disposeKeys({AppTab.about});
                  _logEvent('Disposed ${AppTab.about.name}');
                case 'keepAlive':
                  _controller.addKeepAlive({AppTab.home});
                  _logEvent('KeepAlive ${AppTab.home.name}');
                case 'removeKeepAlive':
                  _controller.removeKeepAlive({AppTab.home});
                  _logEvent('Remove keepAlive ${AppTab.home.name}');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 'preheat', child: Text('Preheat ${AppTab.about.name}')),
              PopupMenuItem(
                  value: 'switchTo',
                  child: Text('SwitchTo ${AppTab.profile.name} (preheat+switch)')),
              PopupMenuItem(
                  value: 'dispose', child: Text('Dispose ${AppTab.about.name}')),
              PopupMenuItem(
                  value: 'keepAlive', child: Text('KeepAlive ${AppTab.home.name}')),
              PopupMenuItem(
                  value: 'removeKeepAlive',
                  child: Text('Remove keepAlive ${AppTab.home.name}')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Build status indicator bar.
          _BuildStatusBar(
            builtKeys: _controller.builtKeys,
            currentTab: _currentTab,
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      // Controller action buttons.
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            FilledButton.tonal(
                              onPressed: () {
                                _controller.preheat({AppTab.about});
                                _logEvent('Preheated ${AppTab.about.name}');
                              },
                              child: Text('Preheat ${AppTab.about.name}'),
                            ),
                            FilledButton.tonal(
                              onPressed: () {
                                _controller.switchTo(AppTab.profile);
                                _logEvent('SwitchTo ${AppTab.profile.name}');
                              },
                              child: Text('SwitchTo ${AppTab.profile.name}'),
                            ),
                            FilledButton.tonal(
                              onPressed: () {
                                _controller.disposeKeys({AppTab.about});
                                _logEvent('Disposed ${AppTab.about.name}');
                              },
                              child: Text('Dispose ${AppTab.about.name}'),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                _controller.addKeepAlive({AppTab.home});
                                _logEvent('KeepAlive ${AppTab.home.name}');
                              },
                              child: Text('KeepAlive ${AppTab.home.name}'),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                _controller.removeKeepAlive({AppTab.home});
                                _logEvent('Remove keepAlive ${AppTab.home.name}');
                              },
                              child: Text('UnKeepAlive ${AppTab.home.name}'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: LazyIndexedStack<AppTab>(
                    index: _currentTab,
                    controller: _controller,
                    keepAlive: {AppTab.home},
                    preheat: {AppTab.search},
                    onIndexRequested: (key) =>
                        setState(() => _currentTab = key),
                    onSwitch: (from, to) =>
                        _logEvent('Switch: ${from.name} -> ${to.name}'),
                    onChildBuilt: (key) =>
                        _logEvent('+ Built: ${key.name}'),
                    onChildDisposed: (key) =>
                        _logEvent('- Disposed: ${key.name}'),
                    builder: (context, key) => _TabPage(tab: key),
                  ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: ColoredBox(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Event Log',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _log.length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                _log[i],
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab.index,
        onDestinationSelected: (i) =>
            setState(() => _currentTab = AppTab.values[i]),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home), label: AppTab.home.name),
          NavigationDestination(
              icon: const Icon(Icons.search), label: AppTab.search.name),
          NavigationDestination(
              icon: const Icon(Icons.person), label: AppTab.profile.name),
          NavigationDestination(
              icon: const Icon(Icons.settings), label: AppTab.settings.name),
          NavigationDestination(
              icon: const Icon(Icons.info), label: AppTab.about.name),
        ],
      ),
    );
  }
}

/// A horizontal bar showing the build status of each tab.
class _BuildStatusBar extends StatelessWidget {
  const _BuildStatusBar({
    required this.builtKeys,
    required this.currentTab,
  });

  final Set<AppTab> builtKeys;
  final AppTab currentTab;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lazy Build Status:   Green = built & alive   Grey = not built',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Row(
            children: AppTab.values.map((tab) {
              final isBuilt = builtKeys.contains(tab);
              final isActive = tab == currentTab;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isBuilt
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                    border: isActive
                        ? Border.all(color: colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isBuilt
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color:
                            isBuilt ? colorScheme.primary : colorScheme.outline,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tab.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: isBuilt
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// A simple tab page with its own state (counter) to demonstrate state
/// preservation when using keepAlive.
class _TabPage extends StatefulWidget {
  const _TabPage({required this.tab});

  final AppTab tab;

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(widget.tab), size: 64),
          const SizedBox(height: 16),
          Text(widget.tab.name,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Counter: $_counter',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => setState(() => _counter++),
            child: const Text('Increment'),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(AppTab tab) {
  return const {
    AppTab.home: Icons.home,
    AppTab.search: Icons.search,
    AppTab.profile: Icons.person,
    AppTab.settings: Icons.settings,
    AppTab.about: Icons.info,
  }[tab]!;
}
