# de facto

[Midje](https://github.com/marick/Midje)-like testing for Julia. A
work-in-progress.

### Usage

```jl
using DeFacto

facts() do

    @fact 1 => 1

    @fact "two is also two" 2 => 2

    @fact "predicates can be used" begin
        2 => iseven
        3 => isodd
    end

end
```
