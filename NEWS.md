# NEWS

## v0.2.0 (unreleased)

* NEW: Custom test messages, e.g. `@fact 1=>2 "two != one"`
* NEW: Added a compact mode, enable with `FactCheck.setstyle(:compact)`
* Minimum Julia version bumped to 0.3
* Colored output handled by Julia itself. To get colored output run with `julia --color`
* Re-written README. Simpler, explains all features, builds up incrementally to more advanced options.
* General refactoring of code base.
* Removal of the `irrelevant` assertion helper
* `exitstatus` no longer actually exits Julia, it just throws an uncaught exception.
* `@runtest` macro removed, was partially broken anyway and didn't seem like something that fit with rest of package.
