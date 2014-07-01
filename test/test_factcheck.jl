module TestFactCheck

using FactCheck

# We have to define macros around certain functions that return expressions
# so that the :escape Exprs inside them are expanded.
#
# See: https://gist.github.com/zachallaun/5257930
#
macro throws_pred(ex) FactCheck.throws_pred(ex) end
macro fact_pred(x, y) FactCheck.fact_pred(x, y) end

type Foo a end
type Bar a end
==(x::Foo, y::Foo) = x.a == y.a

facts("FactCheck core functions") do

    context("throws_pred is true on error") do
        @fact @throws_pred(1 + 1)   => (false, "no error")
        @fact @throws_pred(error()) => (true, "error")
    end

    context("fact_pred tests equality on values") do
        @fact @fact_pred(1, 1) => (true, 1)
        @fact @fact_pred("foo", "foo") => (true, "foo")
        @fact @fact_pred(Foo(1), Foo(1)) => (x) -> x[1]
        @fact @fact_pred(Bar(1), Bar(1)) => (x) -> !x[1]
    end

    context("fact_pred applies Function assertions") do
        @fact @fact_pred(2, iseven) => (true, 2)
        @fact @fact_pred(2, isodd)  => (false, 2)

        isone(x) = x == 1
        @fact @fact_pred(1, isone)  => (true, 1)
    end

end

type Baz end
type Bazz a end

facts("FactCheck assertion helper functions") do

    context("`not` works for values and functions") do
        notone = not(1)
        @fact notone(2) => true
        @fact notone(1) => false

        noteven = not(iseven)
        @fact noteven(3) => true
        @fact noteven(2) => false
        @fact not(iseven)(2) => false
    end

    context("`truthy` is anything other than nothing or false (which is 0)") do
        @fact truthy(-1) => true
        @fact truthy("") => true
        @fact truthy([]) => true
        @fact truthy(Dict())  => true
        @fact truthy(nothing) => false
        @fact truthy(false)   => false
        @fact truthy(0)       => false
    end

    context("`anything` and `irrelevant` are always true") do
        @fact anything => exactly(irrelevant)
        @fact anything(false)   => true
        @fact irrelevant(false) => true
    end

    context("`exactly` can be used to check object equality") do
        @fact exactly(exactly)(exactly) => true

        x() = ()
        @fact exactly(x)(x) => true

        # types with no fields return a singleton object when instantiated
        @fact exactly(Baz())(Baz()) => true

        @fact exactly(Bazz(1))(Bazz(1)) => false
    end

    context("`roughly` compares numbers... roughly") do
        @fact 2.4999999999999 => roughly(2.5) #roughly(2.5)(2.4999) => true
        @fact 9.5 => roughly(10; atol=1.0) #roughly(10, 1)(9.5) => true
        @fact 10.5 => roughly(10; atol=1.0) #roughly(10, 1)(10.5) => true
    end

    context("`roughly` compares matrixes... roughly") do
        X = [1.1 1.2; 2.1 2.2]
        Y = X + [0 0.000001; -0.00000349 0.00001]
        Z = [1 1; 2 2]
        @fact X => roughly(Y)
        @fact X => roughly(Z; atol=0.2)
    end

end

facts("Suite Printing") do
    context("print shows suite name") do
        suite = FactCheck.TestSuite("testfile.jl", "A Sweet Suite")
        @fact string(suite) => "A Sweet Suite: (testfile.jl)"
    end
end

exitstatus()

end # module

