# de facto

[Midje](https://github.com/marick/Midje)-like testing for Julia. A
work-in-progress.

### Usage

```jl
using DeFacto

inc(x) = x + 1

@facts "Important fact examples" begin
    @fact begin
        "foo" => "foo"
    end

    @fact "I can annotate things" begin
        1 => 1
    end

    @fact "strings are strings" begin
        "foo" => "foo"
        "bar" => "barr"
        "baz" => "bazz"
    end

    @fact "some numbers are even" begin
        2 => iseven
        3 => iseven
    end

    @fact begin
        x = 10
        inc(inc(inc(0))) => 2
    end

    @fact begin
        x = 5
        y = 10
        x => y
    end
end
```
