# NEWS

## v0.2.1 (unreleased)

* NEW: helper `anyof`: fact passes if expression matches any of the arguments to `anyof`.
* CHANGE: `roughly` now has a two-argument, no keyword, form where the second argument is taken to be `atol`.

## v0.2.0

* NEW: Custom test messages, e.g. `@fact 1=>2 "two != one"`
* NEW: Added a compact mode, enable with `FactCheck.setstyle(:compact)`
* NEW: Added a `@pending` test type that is a no-op but records its existence.
* CHANGE: Minimum Julia version bumped to 0.3
* CHANGE: Colored output handled by Julia itself - to get colored output run with `julia --color`.
* CHANGE: `exitstatus` no longer exits Julia, instead throws an uncaught exception.
* REMOVED: `irrelevant` assertion helper.
* REMOVED: `@runtest` macro - was partially broken anyway.
* Re-written README. Simpler, explains all features, builds up incrementally to more advanced options.
* General refactoring of code base.