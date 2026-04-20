import 'package:flutter/widgets.dart';

import 'lazy_indexed_stack_controller.dart';

typedef OnSwitchCallback<T> = void Function(T from, T to);
typedef OnChildCallback<T> = void Function(T key);

/// A lazy-loading replacement for [IndexedStack].
///
/// Unlike [IndexedStack] which eagerly builds all children, this widget only
/// builds children that are active, kept alive, or preheated. Children are
/// constructed when first needed, may remain mounted while inactive, and may be
/// disposed when no longer needed.
///
/// Keys can be any type that correctly implements `==` and `hashCode`
/// (e.g. enums, strings, ints). Custom classes must override both to ensure
/// proper set operations and widget identity — typically an enum for type safety:
///
/// {@tool snippet}
/// ```dart
/// enum Tab { home, search, profile }
///
/// LazyIndexedStack<Tab>(
///   index: Tab.home,
///   keepAlive: {Tab.home},
///   preheat: {Tab.search},
///   builder: (context, key) => MyPage(tab: key),
/// )
/// ```
/// {@end-tool}
class LazyIndexedStack<T> extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.builder,
    this.controller,
    this.keepAlive = const {},
    this.preheat = const {},
    this.maintainAnimationWhenInactive = false,
    this.maintainAnimationWhenInactiveKeys = const {},
    this.onSwitch,
    this.onChildBuilt,
    this.onChildDisposed,
    this.onIndexRequested,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.clipBehavior = Clip.hardEdge,
    this.sizing = StackFit.loose,
  });

  /// The currently visible child key.
  final T index;

  /// Builder that produces the widget for a given key.
  final Widget Function(BuildContext context, T key) builder;

  /// Optional controller for imperative commands.
  final LazyIndexedStackController<T>? controller;

  /// Keys that remain alive even when not active. Built once and kept offstage.
  final Set<T> keepAlive;

  /// Keys that should be built offstage before becoming visible.
  final Set<T> preheat;

  /// Whether inactive but built children should keep running animations.
  ///
  /// This only affects children that remain mounted while inactive, such as
  /// children retained by [keepAlive] or [preheat]. The active child always
  /// keeps its animations enabled.
  final bool maintainAnimationWhenInactive;

  /// Keys that should keep running animations while inactive.
  ///
  /// This overrides [maintainAnimationWhenInactive] for the listed keys.
  /// The active child always keeps its animations enabled regardless.
  final Set<T> maintainAnimationWhenInactiveKeys;

  /// Called after the active key changes from one value to another.
  ///
  /// This callback is scheduled after the widget update has been processed.
  final OnSwitchCallback<T>? onSwitch;

  /// Called when a child is added to the widget tree.
  ///
  /// If a child is later removed and rebuilt again, this callback will fire
  /// again for that key.
  final OnChildCallback<T>? onChildBuilt;

  /// Called when a child is removed from the widget tree.
  final OnChildCallback<T>? onChildDisposed;

  /// Called when [LazyIndexedStackController.switchTo] is invoked.
  ///
  /// The parent should update the `index` parameter in response:
  /// ```dart
  /// LazyIndexedStack<Tab>(
  ///   onIndexRequested: (key) => setState(() => _currentTab = key),
  /// )
  /// ```
  final OnChildCallback<T>? onIndexRequested;

  // Stack property pass-through.
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final Clip clipBehavior;
  final StackFit sizing;

  @override
  State<LazyIndexedStack<T>> createState() => _LazyIndexedStackState<T>();
}

class _LazyIndexedStackState<T> extends State<LazyIndexedStack<T>> {
  final Set<T> _builtKeys = {};
  final Set<T> _controllerKeepAlive = {};
  final Set<T> _controllerPreheated = {};
  final Set<T> _forceDisposedKeys = {};
  // Prevents re-adding consumed preheat keys from widget.preheat on rebuilds.
  final Set<T> _consumedPreheat = {};

  Set<T> get _declarativePreheat => widget.preheat.difference(_consumedPreheat);

  Set<T> get _retainedKeys {
    return <T>{
      ...widget.keepAlive,
      ..._declarativePreheat,
      ..._controllerKeepAlive,
      ..._controllerPreheated,
    };
  }

  Set<T> get _activeKeys {
    return <T>{
      widget.index,
      ..._retainedKeys.difference(_forceDisposedKeys),
    };
  }

  void _attachController() {
    widget.controller?.attach(
      preheat: _handleControllerPreheat,
      disposeKeys: _handleControllerDisposeKeys,
      forceDisposeKeys: _handleControllerForceDisposeKeys,
      addKeepAlive: _handleControllerAddKeepAlive,
      removeKeepAlive: _handleControllerRemoveKeepAlive,
      getBuiltKeys: () => Set<T>.from(_builtKeys),
      isBuilt: _builtKeys.contains,
      getCurrentKey: () => widget.index,
      switchTo: _handleControllerSwitchTo,
    );
  }

  @override
  void initState() {
    super.initState();
    _attachController();
    _builtKeys.addAll(_activeKeys);
    final initialBuilt = _activeKeys;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final key in initialBuilt) {
        widget.onChildBuilt?.call(key);
      }
    });
  }

  @override
  void didUpdateWidget(LazyIndexedStack<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      _attachController();
    }

    final removedPreheat = oldWidget.preheat.difference(widget.preheat);
    _consumedPreheat.removeAll(removedPreheat);
    final newlyDeclaredRetained = <T>{
      ...widget.keepAlive.difference(oldWidget.keepAlive),
      ...widget.preheat.difference(oldWidget.preheat),
    };
    _forceDisposedKeys.removeAll(newlyDeclaredRetained);

    if (oldWidget.index != widget.index) {
      final from = oldWidget.index;
      final to = widget.index;
      if (widget.preheat.contains(from)) {
        _consumedPreheat.add(from);
      }
      if (widget.preheat.contains(to)) {
        _consumedPreheat.add(to);
      }
      _forceDisposedKeys.remove(to);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onSwitch?.call(from, to);
      });
    }

    _reconcile();
  }

  @override
  void dispose() {
    widget.controller?.detach();
    super.dispose();
  }

  void _reconcile() {
    final active = _activeKeys;

    final toRemove = _builtKeys.difference(active);
    final removedKeys = <T>[];
    for (final key in toRemove) {
      _builtKeys.remove(key);
      removedKeys.add(key);
    }

    final toAdd = active.difference(_builtKeys);
    _builtKeys.addAll(toAdd);

    if (toAdd.isEmpty && toRemove.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final key in removedKeys) {
        widget.onChildDisposed?.call(key);
      }
      for (final key in toAdd) {
        widget.onChildBuilt?.call(key);
      }
    });

    setState(() {});
  }

  void _handleControllerPreheat(Set<T> keys) {
    _forceDisposedKeys.removeAll(keys);
    _controllerPreheated.addAll(keys);
    _reconcile();
  }

  void _handleControllerDisposeKeys(Set<T> keys) {
    _controllerPreheated.removeAll(keys);
    _controllerKeepAlive.removeAll(keys);
    _reconcile();
  }

  void _handleControllerForceDisposeKeys(Set<T> keys) {
    final filteredKeys = keys.where((key) => key != widget.index);
    _controllerPreheated.removeAll(filteredKeys);
    _controllerKeepAlive.removeAll(filteredKeys);
    _forceDisposedKeys.addAll(filteredKeys);
    _reconcile();
  }

  void _handleControllerAddKeepAlive(Set<T> keys) {
    _forceDisposedKeys.removeAll(keys);
    _controllerKeepAlive.addAll(keys);
    _reconcile();
  }

  void _handleControllerRemoveKeepAlive(Set<T> keys) {
    _controllerKeepAlive.removeAll(keys);
    _reconcile();
  }

  void _handleControllerSwitchTo(T key) {
    assert(
        widget.onIndexRequested != null,
        'LazyIndexedStack.onIndexRequested must be provided for controller.switchTo() to work. '
        'Add onIndexRequested: (key) => setState(() => _currentTab = key) to your LazyIndexedStack.');
    widget.onIndexRequested?.call(key);
  }

  @override
  Widget build(BuildContext context) {
    final builtList = _builtKeys.toList();

    return Stack(
      alignment: widget.alignment,
      textDirection: widget.textDirection,
      fit: widget.sizing,
      clipBehavior: widget.clipBehavior,
      children: [
        for (final key in builtList)
          (() {
            final isActive = key == widget.index;
            final maintainAnimation = isActive ||
                widget.maintainAnimationWhenInactive ||
                widget.maintainAnimationWhenInactiveKeys.contains(key);

            return KeyedSubtree(
              key: ValueKey(key),
              child: TickerMode(
                enabled: maintainAnimation,
                child: Offstage(
                  offstage: !isActive,
                  child: widget.builder(context, key),
                ),
              ),
            );
          })(),
      ],
    );
  }
}
