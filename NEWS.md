# NEWS

## v0.2.0 (unreleased)

* Minimum Julia version bumped to 0.3
* Re-written README. Simpler, explains all features, builds up incrementally.
* General refactoring of code base.
* Colored output handled by Julia itself. To get colored output run with `julia --color`
* Removal of the `irrelevant` assertion helper
* `exitstatus` no longer actually exits Julia, it just throws an uncaught exception. It maybe deprecated and removed.
* `@runtest` macro removed, was broken anyway and didn't seem like something that should be in this package.
