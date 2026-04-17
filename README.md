# keyed_indexed_stack

A lazy-loading replacement for Flutter's `IndexedStack`.

Unlike `IndexedStack` which eagerly builds all children at once, this widget
only builds children that are active, kept alive, or preheated. Children are
constructed on first access and optionally disposed when no longer needed.

## Features

- **Lazy building** — children are built only when first needed
- **Generic keys** — use enums, strings, or any type with proper `==` and `hashCode`
- **Keep-alive** — specify keys that should stay built when inactive
- **Preheat** — build children offstage before they become visible
- **Lifecycle callbacks** — `onSwitch`, `onChildBuilt`, `onChildDisposed`
- **Controller** — imperative API for preheat, dispose, keep-alive, and switching

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
controller.disposeKeys({Tab.search});    // Remove search from tree
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
| `onSwitch` | `void Function(T from, T to)?` | Called on index change |
| `onChildBuilt` | `void Function(T)?` | Called when child is first built |
| `onChildDisposed` | `void Function(T)?` | Called when child is removed |
| `onIndexRequested` | `void Function(T)?` | Called by `controller.switchTo()` |

Stack pass-through: `alignment`, `textDirection`, `clipBehavior`, `sizing`.

### `LazyIndexedStackController<T>`

| Method | Description |
|---|---|
| `preheat(Set<T>)` | Build children offstage |
| `disposeKeys(Set<T>)` | Remove children from tree |
| `addKeepAlive(Set<T>)` | Add to keep-alive set |
| `removeKeepAlive(Set<T>)` | Remove from keep-alive set |
| `switchTo(T)` | Switch active key (requires `onIndexRequested`) |

| Property | Description |
|---|---|
| `builtKeys` | Set of currently built keys |
| `currentKey` | Currently active key |
| `isBuilt(T)` | Whether a key is built |

## License

MIT
