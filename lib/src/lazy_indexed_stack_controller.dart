/// Controller for imperative control over a [LazyIndexedStack].
///
/// Attach to a [LazyIndexedStack] via the `controller` parameter, then use
/// this controller to preheat, dispose, or manage keep-alive state at runtime.
///
/// {@tool snippet}
/// ```dart
/// enum Tab { home, search, profile, settings }
///
/// final controller = LazyIndexedStackController<Tab>();
///
/// LazyIndexedStack<Tab>(
///   controller: controller,
///   index: Tab.home,
///   builder: (context, key) => Text('Page $key'),
/// );
///
/// // Later:
/// controller.preheat({Tab.search});       // Build search page offstage
/// controller.addKeepAlive({Tab.home});    // Keep home page alive forever
/// controller.disposeKeys({Tab.settings}); // Dispose settings page
/// ```
/// {@end-tool}
class LazyIndexedStackController<T> {
  void Function(Set<T>)? _preheat;
  void Function(Set<T>)? _disposeKeys;
  void Function(Set<T>)? _addKeepAlive;
  void Function(Set<T>)? _removeKeepAlive;
  Set<T> Function()? _getBuiltKeys;
  bool Function(T)? _isBuilt;
  T Function()? _getCurrentKey;
  void Function(T)? _switchTo;

  // Called by LazyIndexedStack's State. Do not call directly.
  void attach({
    required void Function(Set<T>) preheat,
    required void Function(Set<T>) disposeKeys,
    required void Function(Set<T>) addKeepAlive,
    required void Function(Set<T>) removeKeepAlive,
    required Set<T> Function() getBuiltKeys,
    required bool Function(T) isBuilt,
    required T Function() getCurrentKey,
    required void Function(T) switchTo,
  }) {
    _preheat = preheat;
    _disposeKeys = disposeKeys;
    _addKeepAlive = addKeepAlive;
    _removeKeepAlive = removeKeepAlive;
    _getBuiltKeys = getBuiltKeys;
    _isBuilt = isBuilt;
    _getCurrentKey = getCurrentKey;
    _switchTo = switchTo;
  }

  void detach() {
    _preheat = null;
    _disposeKeys = null;
    _addKeepAlive = null;
    _removeKeepAlive = null;
    _getBuiltKeys = null;
    _isBuilt = null;
    _getCurrentKey = null;
    _switchTo = null;
  }

  /// Imperatively preheat (build + mount offstage) the given keys.
  ///
  /// Children at these keys will be built immediately if not already built.
  /// They remain mounted until explicitly removed via [disposeKeys].
  void preheat(Set<T> keys) {
    assert(_preheat != null, 'Controller is not attached to a LazyIndexedStack');
    _preheat!(keys);
  }

  /// Dispose (remove from tree) the children at given keys.
  ///
  /// Will not dispose the current active key or keys that are in the
  /// widget's keepAlive.
  void disposeKeys(Set<T> keys) {
    assert(_disposeKeys != null,
        'Controller is not attached to a LazyIndexedStack');
    _disposeKeys!(keys);
  }

  /// Dynamically add keys to the keep-alive set.
  ///
  /// These keys will remain built even when they are not the active key,
  /// similar to declaring them in the widget's keepAlive.
  void addKeepAlive(Set<T> keys) {
    assert(_addKeepAlive != null,
        'Controller is not attached to a LazyIndexedStack');
    _addKeepAlive!(keys);
  }

  /// Dynamically remove keys from the controller's keep-alive set.
  ///
  /// Removed keys that are not the active key and not in the widget's
  /// keepAlive or preheat will be disposed.
  void removeKeepAlive(Set<T> keys) {
    assert(_removeKeepAlive != null,
        'Controller is not attached to a LazyIndexedStack');
    _removeKeepAlive!(keys);
  }

  /// Returns the set of keys currently built (mounted in the tree).
  Set<T> get builtKeys =>
      _getBuiltKeys != null ? _getBuiltKeys!() : const {};

  /// Returns the currently active key, or null if not attached.
  T? get currentKey => _getCurrentKey?.call();

  /// Returns true if the child at [key] is currently built.
  bool isBuilt(T key) => _isBuilt?.call(key) ?? false;

  /// Switch to the given key.
  ///
  /// Triggers [LazyIndexedStack.onIndexRequested] to notify the parent
  /// to update the active key. If the child at [key] is not yet built,
  /// it will be built in the same frame.
  ///
  /// The parent must provide [LazyIndexedStack.onIndexRequested] for this
  /// to have any effect.
  void switchTo(T key) {
    assert(_switchTo != null,
        'Controller is not attached to a LazyIndexedStack');
    _switchTo!(key);
  }
}
