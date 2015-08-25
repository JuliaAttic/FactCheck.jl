# NEWS

## v0.4.0

* REMOVED: truthy, falsy, falsey, anthing. They were broken for over a month in FactCheck v0.3 and no one noticed. They are also not particularly Julian.
* CHANGE: improved printing to be a lot more clear about what is the actual value, what is the expected value, and what the expression was.

## v0.3.0

* CHANGE: `=>` has been deprecated, use `-->` instead

## v0.2.3

* CHANGE: Added Compat.jl to address Julia 0.4 deprecations.

## v0.2.2

* NEW: helpers `less_than`/`less_than_or_equal`/`less_than_or_equal`/`greater_than_or_equal`

## v0.2.1

* NEW: helper `anyof`: fact passes if expression matches any of the arguments to `anyof`.
* CHANGE: `roughly` now has a two-argument, no keyword, form where the second argument is taken to be `atol`.
* CHANGE: `context` didn't really do anything. Now, if not in compact mode, it'll print the context description indented. Gives a nice indication of progress when running a large number of tests inside a facts block.

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
