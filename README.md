# FactCheck.jl

### A test framework for [Julia](http://julialang.org)

[![Build Status](https://travis-ci.org/JuliaLang/FactCheck.jl.svg?branch=master)](https://travis-ci.org/JuliaLang/FactCheck.jl)
[![codecov.io](http://codecov.io/github/JuliaLang/FactCheck.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaLang/FactCheck.jl?branch=master)

[![FactCheck](http://pkg.julialang.org/badges/FactCheck_0.3.svg)](http://pkg.julialang.org/?pkg=FactCheck&ver=0.3)
[![FactCheck](http://pkg.julialang.org/badges/FactCheck_0.4.svg)](http://pkg.julialang.org/?pkg=FactCheck&ver=0.4)

`FactCheck.jl` is a [Julia](http://julialang.org) testing framework inspired by the [Midje](https://github.com/marick/Midje) library for Clojure. It aims to add more functionality over the basic [Base.Test](http://docs.julialang.org/en/latest/stdlib/test/).

MIT Licensed - see LICENSE.md

**Installation**: `julia> Pkg.add("FactCheck")`

> *Note*: The `=>` syntax has been deprecated in v0.3, use `-->` going forward.

> Note: `FactCheck` produces colored output, but only if you run Julia with the `--color=yes` option, e.g. `julia --color=yes test/runtests.jl`

### Basics

Tests in `FactCheck` should be placed inside a `facts` block. It can be called with or without a description:
```julia
using FactCheck

facts("With a description") do
    # Your tests here
end

facts() do
    # Your tests here
end
```

Related facts can also be grouped as a `context` inside a `facts` block:
```julia
facts("Lots of tests") do
    context("First group") do
        # ...
    end
    context("Second group") do
        # ...
    end
end
```

As for the tests themselves, you can use `FactCheck` to do basic assertions like you would with `Base.Test` using `@fact` and `@fact_throws`:
```julia
facts("Testing basics") do
    @fact 1 --> 1
    @fact 2*2 --> 4
    @fact uppercase("foo") --> "FOO"
    @fact_throws 2^-1
    @fact_throws DomainError 2^-1
    @fact_throws DomainError 2^-1 "a nifty message"
    @fact 2*[1,2,3] --> [2,4,6]
end
```

You can provide custom error messages as a second argument, e.g.
```julia
facts("Messages") do
    x = [1, 2, 3, 4]
    y = [4, 2, 3, 1]
    for i in 1:4
        @fact x[i] --> y[i] "mismatch at i=$i"
    end
end
```
produces
```
Messages
  Failure :: (line:505) :: mismatch at i=1 :: fact was false
    Expression: x[i] --> y[i]
      Expected: 1
      Occurred: 4
  Failure :: (line:505) :: mismatch at i=4 :: fact was false
    Expression: x[i] --> y[i]
      Expected: 4
      Occurred: 1
# ...
```

Finally, if you have an idea for a test you want to implement but haven't yet, you can using `@pending`. `@pending` doesn't attempt to check its assertion, or even evaluate the expression, it simply records that a pending test exists.
```julia
facts("Some pending") do
    @fact 2*3 --> 6
    @pending divide(2,3) --> :something
end
```
produces
```
Some pending
Out of 2 total facts:
  Verified: 1
  Pending:  1
```

### Assertions

A `FactCheck` `-->` is more general than the `==` of `Base.Test.@test`.
We refer to the value to the left of the `-->` as the *expression*, and the value to the right of as the *assertion*.
If the assertion is a literal value, like `1`, `"FOO"`, or `[2,4,6]`, then `@fact` checks if the expression is equal to the assertion.
However if the assertion is a *function*, then function will be applied to the expression, e.g.
```julia
@fact 2 --> iseven
#...is equivalent to...
@fact iseven(2) --> true

@fact Int[] --> isempty
#..is equivalent to...
@fact isempty(Int[]) --> true
```

`FactCheck` provides several helper functions to make more complicated assertions:

#### `not`
Logical not for literal values and functions.
```julia
@fact 1 --> not(2)
# is equivalent to
@fact (1 != 2) --> true

@fact 1 --> not(iseven)
# is equivalent to
@fact !iseven(1) --> true
```

#### `exactly`
Test equality in the same way that `Base.is`/`Base.===` do. For example, two distinct objects with the same values are not `exactly` the same e.g.
```julia
a = [1,2,3]
b = [1,2,3]
@fact a --> b
@fact a --> not(exactly(b))
```

#### `roughly`
Test approximate equality of numbers and arrays of numbers using `Base.isapprox`, and accepts same keyword arguments as that function. If a second argument is provided, but no keyword, it is treated as `atol`.
```julia
@fact 2 + 1e-5 --> roughly(2.0)
@fact 9.5 --> roughly(10; atol=1.0)
A = [2.0, 3.0]
B = (1 + 1e-6)*A
@fact A --> roughly(B)
```

#### `less_than`/
#### `less_than_or_equal`/
#### `less_than_or_equal`/
#### `greater_than_or_equal`
Test inequality relationships between numbers.
```julia
@fact 1 --> less_than(2)
@fact 1 --> less_than_or_equal(1)
@fact 2 --> greater_than(1)
@fact 2 --> greater_than_or_equal(2)
```

#### `anyof`
Test equality with any of the arguments to `anyof`
```julia
@fact 2+2 --> anyof(4, :four, "four")
@fact 5   --> not(anyof(:five, "five"))
```

### Exit status

When a program ends it returns an [exit status](http://en.wikipedia.org/wiki/Exit_status). This is used by other programs to figure out how a program ended. For example, [Travis CI](https://travis-ci.org/) looks at Julia exit code to determine if your tests passed or failed. Because `FactCheck` catches all the test errors, it will return `0` even if a test fails. To address this you can use `exitstatus()` at the end of your tests. This will throw a error, so Julia terminates in an error state.

```jl
module MyPkgTests
    using FactCheck
    # Your tests...
    FactCheck.exitstatus()
end
```

### Options

`FactCheck` currently has one configuration option, for the output style. This can be set with `FactCheck.setstyle(style)`. The default
is `:default`, and the other option currently is `:compact`. To see the difference, consider the following code:

```julia
FactCheck.setstyle(:compact)
facts("Compact vs default") do
    @fact 1 --> 1
    @fact 2 --> 3
    @fact 3 --> 3
    @fact 4 --> 4
    @fact 5 --> 5
end
```
which produces the output
```
Compact vs default: .F...
  Failure :: (line:505) :: fact was false
    Expression: 2 --> 3
      Expected: 2
      Occurred: 3
```

The main difference is that single characters only are emitted as the tests run, with all errors only being displayed at the end.

#### Low memory situations

If you run into problems using `FactCheck` in low memory situations like `Travis` consider to activate the option `only_stats`. This will not store results during the testing and provides only statistics in the end. This can be set with `FactCheck.onlystats(true)`.

### Workflow

You can run your tests simply by calling them from the command line, e.g. `julia --color=yes test/runtests.jl`, but another option is to place your tests in a module, e.g.

```jl
module MyPkgTests
    # Your tests...
end
```

then repeatedly reload your tests using `reload`, e.g. `julia> reload("test/runtests")`
