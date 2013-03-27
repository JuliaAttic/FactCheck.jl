# de facto

[Midje](https://github.com/marick/Midje)-like testing for Julia.

![Example output](http://s15.postimg.org/4j9hpmf63/Screen_Shot_2013_03_27_at_6_18_07_PM.png)

### Why?

[Base.Test](https://github.com/JuliaLang/julia/blob/master/base/test.jl)
seemed to be the only option in the way of Julia testing, and I wasn't a
huge fan. Midje is a simple and powerful testing framework written for
Clojure, and so I sought to (at least partially) recreate it. This is a
work in progress.

### Usage

```jl
using DeFacto
```

Two macros are required for testing: `@facts` and `@fact`. The first is
used to describe the scope of your tests and to do some setup, while the
second is used to make assertions.

`@facts` can be called in two ways:

```jl
@facts "With a description" begin
    # ...
end

@facts begin
    # ...
end
```

`@fact` can be called in three ways, and must be called within a
`@facts` block:

```jl
@facts "Simple facts" begin

    # expression => assertion
    @fact 1 => 1

    @fact "one is one" 1 => 1

    @fact "numbers are themselves" begin
        1 => 1
        2 => 2
        3 => 3
    end

end
```

Each instance of `=>` will be transformed into a test. The type of test
will depend on the value to the right of the `=>`, which we'll call the
assertion. If the assertion is a `Function`, it will be called on the
expression. Otherwise, `==` will be called.

```jl
@facts "Slightly more complicated facts" begin

    @fact "functions can be used as assertions" begin
        1 => isodd
        2 => iseven
    end

end
```

As this is rather convenient and reads nicely, a number of helper
assertion functions are provided.

```jl
@facts "Using helper assertions" begin

    @fact "some helpers operate on values" begin
        false => anything

        1 => not(2)
    end

    @fact "... or on functions" begin
        2 => not(isodd)
    end

end
```

They can be found at the bottom of [DeFacto.jl](https://github.com/zachallaun/DeFacto/blob/master/src/DeFacto.jl).

### Contributing

I'm incredibly open to contributions. The code base is quite small and
is (I think) well documented. I'm also happy to explain any decisions
I've made, with the caveat that they may have been uninformed.
