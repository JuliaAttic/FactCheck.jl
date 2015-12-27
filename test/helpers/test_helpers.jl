using FactCheck

type Baz end
type Bazz a end

facts("FactCheck assertion helper functions") do
    context("`not` works for values and functions") do
        notone = not(1)
        @fact notone(2) --> true
        @fact notone(1) --> false
        @fact 2 --> not(1)

        noteven = not(iseven)
        @fact noteven(3) --> true
        @fact noteven(2) --> false
        @fact not(iseven)(2) --> false
        @fact 3 --> not(iseven)
    end

    context("`exactly` can be used to check object equality") do
        @fact exactly(exactly)(exactly) --> true

        x() = ()
        @fact exactly(x)(x) --> true

        # types with no fields return a singleton object when instantiated
        @fact exactly(Baz())(Baz()) --> true

        @fact exactly(Bazz(1))(Bazz(1)) --> false
    end

    context("`roughly` compares numbers... roughly") do
        @fact 2.4999999999999 --> roughly(2.5)
        @fact 9.5 --> roughly(10; atol=1.0)
        @fact 10.5 --> roughly(10; atol=1.0)
        @fact 10.5 --> roughly(10, 1.0)
    end

    context("`roughly` compares matrixes... roughly") do
        X = [1.1 1.2; 2.1 2.2]
        Y = X + [+1e-8 -1e-8; -1e-8 +1e-8]
        Z = [1 1; 2 2]
        @fact X --> roughly(Y)
        @fact X --> roughly(Z; atol=0.4)
        @fact X --> roughly(Z, 0.4)
    end

    context("`anyof` compares with all arguments") do
        @fact 2+2 --> anyof(4, :four, "four")
        @fact 5   --> not(anyof(:five, "five"))
    end

    context("`anyof` works for functions") do
        @fact 5 --> anyof(5.1, roughly(5.1,0.01), roughly(4.9,0.2))
    end

    context("less_than") do
        @fact 1 --> less_than(2)
    end

    context("less_than_or_equal") do
        @fact 1 --> less_than_or_equal(2)
        @fact 1 --> less_than_or_equal(1)
    end

    context("greater_than") do
        @fact 2 --> greater_than(1)
    end

    context("greater_than_or_equal") do
        @fact 2 --> greater_than_or_equal(1)
        @fact 2 --> greater_than_or_equal(2)
    end
end
