import 'package:flutter/material.dart';
import 'package:keyed_indexed_stack/keyed_indexed_stack.dart';
import 'dart:async';

enum AppTab { home, chart, player }

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LazyIndexedStack Profiling Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2C6E49)),
        useMaterial3: true,
      ),
      home: const ProfilingDemoPage(),
    );
  }
}

class ProfilingDemoPage extends StatefulWidget {
  const ProfilingDemoPage({super.key});

  @override
  State<ProfilingDemoPage> createState() => _ProfilingDemoPageState();
}

class _ProfilingDemoPageState extends State<ProfilingDemoPage> {
  AppTab _currentTab = AppTab.home;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 1000;

    return Scaffold(
      appBar: AppBar(title: const Text('LazyIndexedStack Profiling Demo')),
      body: Column(
        children: [
          const _IntroCard(),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isCompact
                  ? ListView(
                      children: [
                        _ScenarioCard(
                          title: 'Paused When Inactive',
                          subtitle:
                              'Default behavior: hidden kept-alive tabs stop ticking.',
                          currentTab: _currentTab,
                          maintainAnimationWhenInactive: false,
                          onIndexRequested: (tab) =>
                              setState(() => _currentTab = tab),
                        ),
                        const SizedBox(height: 16),
                        _ScenarioCard(
                          title: 'Maintained When Inactive',
                          subtitle:
                              'Legacy behavior: hidden kept-alive tabs continue ticking.',
                          currentTab: _currentTab,
                          maintainAnimationWhenInactive: true,
                          onIndexRequested: (tab) =>
                              setState(() => _currentTab = tab),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _ScenarioCard(
                            title: 'Paused When Inactive',
                            subtitle:
                                'Default behavior: hidden kept-alive tabs stop ticking.',
                            currentTab: _currentTab,
                            maintainAnimationWhenInactive: false,
                            onIndexRequested: (tab) =>
                                setState(() => _currentTab = tab),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ScenarioCard(
                            title: 'Maintained When Inactive',
                            subtitle:
                                'Legacy behavior: hidden kept-alive tabs continue ticking.',
                            currentTab: _currentTab,
                            maintainAnimationWhenInactive: true,
                            onIndexRequested: (tab) =>
                                setState(() => _currentTab = tab),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab.index,
        onDestinationSelected: (index) {
          setState(() => _currentTab = AppTab.values[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Chart',
          ),
          NavigationDestination(
            icon: Icon(Icons.album_outlined),
            selectedIcon: Icon(Icons.album),
            label: 'Player',
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile hidden ticker behavior',
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Both stacks keep every tab alive. Switch tabs and compare the tick counters. '
                'In profile mode, the left stack should go quiet when hidden tabs move offstage, '
                'while the right stack keeps producing frames for hidden animations. '
                'Each card also exposes controller actions plus a live ticker status table so you can '
                'verify when a hidden tab is actually paused.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HintChip(label: 'KeepAlive on all tabs'),
                  _HintChip(label: 'Continuous AnimationController.repeat()'),
                  _HintChip(label: 'Compare paused vs maintained'),
                  _HintChip(label: 'Live ticker status table'),
                  _HintChip(label: 'Controller actions restored'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

class _ScenarioCard extends StatefulWidget {
  const _ScenarioCard({
    required this.title,
    required this.subtitle,
    required this.currentTab,
    required this.maintainAnimationWhenInactive,
    this.onIndexRequested,
  });

  final String title;
  final String subtitle;
  final AppTab currentTab;
  final bool maintainAnimationWhenInactive;
  final ValueChanged<AppTab>? onIndexRequested;

  @override
  State<_ScenarioCard> createState() => _ScenarioCardState();
}

class _ScenarioCardState extends State<_ScenarioCard> {
  final _controller = LazyIndexedStackController<AppTab>();
  final Map<AppTab, int> _tickCounts = {
    for (final tab in AppTab.values) tab: 0,
  };
  final Map<AppTab, DateTime?> _lastTickTimes = {
    for (final tab in AppTab.values) tab: null,
  };
  final Set<AppTab> _keepAlive = AppTab.values.toSet();
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _recordTick(AppTab tab, int tickCount) {
    _tickCounts[tab] = tickCount;
    _lastTickTimes[tab] = DateTime.now();
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleKeepAlive(AppTab tab) {
    setState(() {
      if (_keepAlive.contains(tab)) {
        _keepAlive.remove(tab);
      } else {
        _keepAlive.add(tab);
      }
    });
  }

  bool _isTickerRunning(AppTab tab) {
    final lastTickTime = _lastTickTimes[tab];
    if (lastTickTime == null) return false;
    return DateTime.now().difference(lastTickTime) <
        const Duration(milliseconds: 450);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final builtKeys = _controller.builtKeys;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: widget.maintainAnimationWhenInactive
                  ? colorScheme.tertiaryContainer
                  : colorScheme.primaryContainer,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(widget.subtitle),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _ScenarioDiagnostics(
                currentTab: widget.currentTab,
                builtKeys: builtKeys,
                keepAlive: _keepAlive,
                tickCounts: _tickCounts,
                isTickerRunning: _isTickerRunning,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _ScenarioControls(
                currentTab: widget.currentTab,
                keepAlive: _keepAlive,
                onPreheatInactive: () => _controller.preheat(
                  AppTab.values
                      .where((tab) => tab != widget.currentTab)
                      .toSet(),
                ),
                onReleaseInactive: () => _controller.disposeKeys(
                  AppTab.values
                      .where((tab) => tab != widget.currentTab)
                      .toSet(),
                ),
                onForceDisposeInactive: () => _controller.forceDisposeKeys(
                  AppTab.values
                      .where((tab) => tab != widget.currentTab)
                      .toSet(),
                ),
                onSwitchToPlayer: () => _controller.switchTo(AppTab.player),
                onToggleKeepAlive: _toggleKeepAlive,
              ),
            ),
            SizedBox(
              height: 420,
              child: LazyIndexedStack<AppTab>(
                index: widget.currentTab,
                controller: _controller,
                keepAlive: _keepAlive,
                maintainAnimationWhenInactive:
                    widget.maintainAnimationWhenInactive,
                onIndexRequested: widget.onIndexRequested,
                onChildBuilt: (_) {
                  if (mounted) setState(() {});
                },
                onChildDisposed: (_) {
                  if (mounted) setState(() {});
                },
                builder: (context, key) => _AnimatedTabPage(
                  tab: key,
                  accentColor: _colorForTab(key),
                  onTick: (tickCount) => _recordTick(key, tickCount),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioDiagnostics extends StatelessWidget {
  const _ScenarioDiagnostics({
    required this.currentTab,
    required this.builtKeys,
    required this.keepAlive,
    required this.tickCounts,
    required this.isTickerRunning,
  });

  final AppTab currentTab;
  final Set<AppTab> builtKeys;
  final Set<AppTab> keepAlive;
  final Map<AppTab, int> tickCounts;
  final bool Function(AppTab tab) isTickerRunning;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ticker status', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tab in AppTab.values)
              _StatusTile(
                label: tab.name,
                icon: _iconFor(tab),
                accentColor: _colorForTab(tab),
                isActive: currentTab == tab,
                isBuilt: builtKeys.contains(tab),
                keepAlive: keepAlive.contains(tab),
                isTickerRunning: isTickerRunning(tab),
                tickCount: tickCounts[tab] ?? 0,
              ),
          ],
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.isActive,
    required this.isBuilt,
    required this.keepAlive,
    required this.isTickerRunning,
    required this.tickCount,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final bool isActive;
  final bool isBuilt;
  final bool keepAlive;
  final bool isTickerRunning;
  final int tickCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? accentColor : accentColor.withValues(alpha: 0.3),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Text(label.toUpperCase()),
            ],
          ),
          const SizedBox(height: 8),
          Text(isActive ? 'Visible now' : 'Hidden now'),
          Text(isBuilt ? 'Built: yes' : 'Built: no'),
          Text(keepAlive ? 'KeepAlive: yes' : 'KeepAlive: no'),
          Text(isTickerRunning ? 'Ticker: running' : 'Ticker: paused'),
          Text('Ticks: $tickCount'),
        ],
      ),
    );
  }
}

class _ScenarioControls extends StatelessWidget {
  const _ScenarioControls({
    required this.currentTab,
    required this.keepAlive,
    required this.onPreheatInactive,
    required this.onReleaseInactive,
    required this.onForceDisposeInactive,
    required this.onSwitchToPlayer,
    required this.onToggleKeepAlive,
  });

  final AppTab currentTab;
  final Set<AppTab> keepAlive;
  final VoidCallback onPreheatInactive;
  final VoidCallback onReleaseInactive;
  final VoidCallback onForceDisposeInactive;
  final VoidCallback onSwitchToPlayer;
  final ValueChanged<AppTab> onToggleKeepAlive;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: const Text('Advanced controls'),
      subtitle: Text('Current tab: ${currentTab.name}'),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: onPreheatInactive,
                child: const Text('Preheat inactive tabs'),
              ),
              FilledButton.tonal(
                onPressed: onReleaseInactive,
                child: const Text('Release inactive tabs'),
              ),
              OutlinedButton(
                onPressed: onForceDisposeInactive,
                child: const Text('Force dispose inactive tabs'),
              ),
              OutlinedButton(
                onPressed: onSwitchToPlayer,
                child: const Text('SwitchTo player'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tab in AppTab.values)
                FilterChip(
                  selected: keepAlive.contains(tab),
                  onSelected: (_) => onToggleKeepAlive(tab),
                  label: Text('KeepAlive ${tab.name}'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _AnimatedTabPage extends StatefulWidget {
  const _AnimatedTabPage({
    required this.tab,
    required this.accentColor,
    required this.onTick,
  });

  final AppTab tab;
  final Color accentColor;
  final ValueChanged<int> onTick;

  @override
  State<_AnimatedTabPage> createState() => _AnimatedTabPageState();
}

class _AnimatedTabPageState extends State<_AnimatedTabPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 900),
          )
          ..addListener(() {
            setState(() => _ticks++);
            widget.onTick(_ticks);
          })
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ColoredBox(
          color: widget.accentColor.withValues(alpha: 0.08),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _iconFor(widget.tab),
                        color: widget.accentColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.tab.name.toUpperCase(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Tick count',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    '$_ticks',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _controller.value * 6.28318,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: widget.accentColor, width: 6),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.18),
                            blurRadius: 18,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _iconFor(widget.tab),
                          color: widget.accentColor,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'How to verify',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Open Flutter DevTools in Profile mode.\n'
                    '2. Stay on one tab and note the hidden tab counters.\n'
                    '3. The left stack should stop incrementing hidden tabs.\n'
                    '4. The right stack should keep incrementing hidden tabs.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Color _colorForTab(AppTab tab) {
  return switch (tab) {
    AppTab.home => const Color(0xFF2C6E49),
    AppTab.chart => const Color(0xFFBC6C25),
    AppTab.player => const Color(0xFF355070),
  };
}

IconData _iconFor(AppTab tab) {
  return switch (tab) {
    AppTab.home => Icons.home,
    AppTab.chart => Icons.show_chart,
    AppTab.player => Icons.album,
  };
}
