# FactCheck.jl

### A test framework for [Julia](http://julialang.org)

[![Build Status](https://travis-ci.org/JuliaLang/FactCheck.jl.png)](https://travis-ci.org/JuliaLang/FactCheck.jl)
[![Coverage Status](https://img.shields.io/coveralls/JuliaLang/FactCheck.jl.svg)](https://coveralls.io/r/JuliaLang/FactCheck.jl)
[![FactCheck](http://pkg.julialang.org/badges/FactCheck_release.svg)](http://pkg.julialang.org/?pkg=FactCheck&ver=release)

`FactCheck.jl` is a [Julia](http://julialang.org) testing framework inspired by the [Midje](https://github.com/marick/Midje) library for Clojure. It aims to add more functionality over the basic [Base.Test](http://docs.julialang.org/en/latest/stdlib/test/).

*MIT Licensed*

**Installation**: `julia> Pkg.add("FactCheck")`

## Usage

```jl
using FactCheck
```

**Note**: `FactCheck` has colored output, but only if you run Julia with the `--color` option, e.g. `julia --color test/runtests.jl`.

The top-level function `facts` describes the scope of your tests and does the setup required by the test runner.
It can be called with or without a description:

```jl
facts("With a description") do
    # ...
end

facts() do
    # ...
end
```

Inside of the function passed to `facts`, a fact can be asserted using the `@fact` macro, or `@fact_throws` if you're asserting a thrown exception.

```jl
facts("Simple facts") do

    # expression => assertion
    @fact 1 => 1

    @fact_throws error()

end
```

Related facts can also be grouped inside of a `context`:

```jl
facts("Simple facts") do

    context("numbers are themselves") do
        @fact 1 => 1
        @fact 2 => 2
        @fact 3 => 3
    end

end
```

The symbol `=>` is used as an assertion more general than `==`.
Each fact will be transformed into a test, the type of which depends on the value to the right of the `=>`.
(We'll call that value the assertion.)

An assertion can take two forms:

```jl
# If the assertion is a function, it will be called on the expression
# to determine whether or not the fact holds.
@fact 2 => iseven

# Otherwise, the fact holds if the expression is `==` to the assertion.
@fact [1,2,3] => [1,2,3]
```

As the function-assertion form is rather convenient and reads nicely, a number of helper assertion functions are provided.

```jl
facts("Using helper assertions") do

    context("some helpers operate on values") do
        @fact false => anything
        @fact 1 => not(2)
    end

    context("... or on functions") do
        @fact 2 => not(isodd)
    end

end
```

These can be found at the bottom of [src/FactCheck.jl](https://github.com/JuliaLang/FactCheck.jl/blob/master/src/FactCheck.jl).

### Exit status

When a program ends it returns an [exit status](http://en.wikipedia.org/wiki/Exit_status). This is used by other programs to figure out how a program ended. For example, [Travis CI](https://travis-ci.org/) looks at Julia exit code to determine if your tests passed or failed. Because `FactCheck` catches all the test errors, it will return `0` even if a test fails. To address this you can use `exitstatus()` at the end of your tests. This will throw a error, so Julia terminates in an error state.

```jl
module MyPkgTests
    using FactCheck
    # Your tests...
    FactCheck.exitstatus()
end
```

## Workflow

You can run your tests simply by calling them from the command line, e.g. `julia --color test/runtests.jl`, but another option is to play your tests in a module, e.g.

```jl
module MyPkgTests
    # Your tests...
end
```

then repeatedly reload your tests using `reload`, e.g. `julia> reload("test/runtests")`
