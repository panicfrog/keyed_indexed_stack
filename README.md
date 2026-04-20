# keyed_indexed_stack

A lazy-loading replacement for Flutter's `IndexedStack`.

Unlike `IndexedStack` which eagerly builds all children at once, this widget
only builds children that are active, kept alive, or preheated. Children are
constructed when first needed, may remain mounted while inactive, and may be
disposed when no longer needed.

## Features

- **Lazy building** — children are built only when first needed
- **Generic keys** — use enums, strings, or any type with proper `==` and `hashCode`
- **Keep-alive** — specify keys that should stay built when inactive
- **Preheat** — build children offstage before they become visible
- **Inactive ticker control** — pause hidden retained children by default, with opt-in overrides
- **Lifecycle callbacks** — `onSwitch`, `onChildBuilt`, `onChildDisposed`
- **Controller** — imperative API for preheat, dispose, keep-alive, and switching

## Behavior Notes

- `onSwitch` fires after the `index` change has been applied, not before.
- `onChildBuilt` fires whenever a key is added to the tree. If a child is
  disposed and later rebuilt, the callback fires again.
- `controller.switchTo()` only requests a switch through `onIndexRequested`.
  The parent must update `index` for the visible child to change.
- `controller.disposeKeys()` only releases controller-managed retention for
  those keys. Declarative `keepAlive` / `preheat` still apply.
- `controller.forceDisposeKeys()` is the explicit override. It can remove
  declaratively retained children, but it does not remove the current active
  child.
- Inactive children retained by `keepAlive` / `preheat` pause tickers by
  default. Use `maintainAnimationWhenInactive` or
  `maintainAnimationWhenInactiveKeys` to opt back into background animation.

## Usage

```dart
enum Tab { home, search, profile }

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Tab _currentTab = Tab.home;

  @override
  Widget build(BuildContext context) {
    return LazyIndexedStack<Tab>(
      index: _currentTab,
      keepAlive: {Tab.home},
      preheat: {Tab.search},
      builder: (context, key) => MyPage(tab: key),
    );
  }
}
```

### Inactive animation policy

```dart
LazyIndexedStack<Tab>(
  index: _currentTab,
  keepAlive: {Tab.home, Tab.profile},
  maintainAnimationWhenInactiveKeys: {Tab.profile},
  builder: (context, key) => MyPage(tab: key),
);
```

- Default behavior: inactive built children pause tickers and animations
- `maintainAnimationWhenInactive: true`: preserve the previous global behavior
- `maintainAnimationWhenInactiveKeys`: keep animations running for specific keys only

### With controller

```dart
final controller = LazyIndexedStackController<Tab>();

LazyIndexedStack<Tab>(
  index: _currentTab,
  controller: controller,
  onIndexRequested: (key) => setState(() => _currentTab = key),
  builder: (context, key) => MyPage(tab: key),
);

// Imperative commands:
controller.preheat({Tab.search});        // Build search offstage
controller.addKeepAlive({Tab.home});     // Keep home alive forever
controller.disposeKeys({Tab.search});    // Release controller retention
controller.forceDisposeKeys({Tab.search}); // Force-remove search from tree
controller.switchTo(Tab.profile);        // Switch to profile
```

### Lifecycle callbacks

```dart
LazyIndexedStack<Tab>(
  index: _currentTab,
  onSwitch: (from, to) => print('Switch: $from -> $to'),
  onChildBuilt: (key) => print('Built: $key'),
  onChildDisposed: (key) => print('Disposed: $key'),
  builder: (context, key) => MyPage(tab: key),
);
```

## API

### `LazyIndexedStack<T>`

| Parameter | Type | Description |
|---|---|---|
| `index` | `T` (required) | Currently visible key |
| `builder` | `Widget Function(BuildContext, T)` (required) | Widget builder per key |
| `controller` | `LazyIndexedStackController<T>?` | Imperative control |
| `keepAlive` | `Set<T>` | Keys that stay built when inactive |
| `preheat` | `Set<T>` | Keys to build offstage before visiting |
| `maintainAnimationWhenInactive` | `bool` | Whether inactive built children keep running animations |
| `maintainAnimationWhenInactiveKeys` | `Set<T>` | Per-key override for inactive animation retention |
| `onSwitch` | `void Function(T from, T to)?` | Called after the active index changes |
| `onChildBuilt` | `void Function(T)?` | Called whenever a child is added to the tree |
| `onChildDisposed` | `void Function(T)?` | Called when child is removed |
| `onIndexRequested` | `void Function(T)?` | Called by `controller.switchTo()` |

Stack pass-through: `alignment`, `textDirection`, `clipBehavior`, `sizing`.

### `LazyIndexedStackController<T>`

| Method | Description |
|---|---|
| `preheat(Set<T>)` | Build children offstage |
| `disposeKeys(Set<T>)` | Release controller-managed retention and reconcile built children |
| `forceDisposeKeys(Set<T>)` | Force-remove built children even if declaratively retained |
| `addKeepAlive(Set<T>)` | Add to keep-alive set |
| `removeKeepAlive(Set<T>)` | Remove from keep-alive set |
| `switchTo(T)` | Request an active key change via `onIndexRequested` |

| Property | Description |
|---|---|
| `builtKeys` | Set of currently built keys |
| `currentKey` | Currently active key |
| `isBuilt(T)` | Whether a key is built |

## License

MIT
