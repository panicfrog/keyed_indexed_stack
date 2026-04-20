## 0.2.0

* Breaking: inactive retained children now pause tickers and animations by default.
* Added `maintainAnimationWhenInactive` to preserve background animation globally.
* Added `maintainAnimationWhenInactiveKeys` for per-key inactive animation overrides.

## 0.1.0

* Clarified lifecycle callback timing and rebuild semantics in docs.
* Changed `disposeKeys()` to release controller-managed retention only.
* Added `forceDisposeKeys()` for explicit forced disposal of inactive retained children.
