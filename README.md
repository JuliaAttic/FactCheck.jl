# de facto

[Midje](https://github.com/marick/Midje)-like testing for Julia. A
work-in-progress.

### Usage

```jl
using DeFacto

facts("These are important facts to me") do

    @fact begin
        1 => 1
    end

    @fact "two is also two" begin
        2 => 2
    end

    @fact "predicates can be used" begin
        2 => iseven
        3 => isodd
    end

end
```
