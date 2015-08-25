using FactCheck

inc(x) = x + 1

facts("Succeeding examples") do

    @fact 1 --> 1

    context("You can define contexts") do
        @fact 1 --> 1
    end

    @fact_throws error("neat")

    context("group facts") do
        @fact 1 --> not(2)
        @fact 2 --> not(isodd)
    end

    context("generating facts") do
        for i=1:5
            @fact i --> i
        end
    end

end

facts("Failing examples") do

    @fact 1 --> 2

    context("strings are strings") do
        @fact "bar" --> "barr"
        @fact "baz" --> "bazz"
    end

    context("some numbers are even") do
        @fact 3 --> iseven
    end

    context("incrementing") do
        x = 10
        @fact inc(inc(inc(0))) --> 2
    end

    context("nonsense") do
        x = 5
        y = 10
        @fact x --> y
    end

    context("throws an error") do
        @fact error("foo") --> 1
    end

end

facts("Assertion helpers") do

    @fact 1 --> not(iseven)
    @fact iseven --> exactly(iseven)
    @fact 2.499999 --> roughly(2.5)
    @fact 1 --> less_than(2)
    @fact 1 --> less_than_or_equal(1)
    @fact 2 --> greater_than(1)
    @fact 2 --> greater_than_or_equal(2)

end
