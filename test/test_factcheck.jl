using FactCheck

# We have to define macros around certain functions that return expressions
# so that the :escape Exprs inside them are expanded.
#
# See: https://gist.github.com/zachallaun/5257930
#
macro throws_pred(ex) FactCheck.throws_pred(ex) end
macro fact_pred(x, y) FactCheck.fact_pred(x, y) end

@facts "FactCheck core functions" begin

    @fact "throws_pred is true on error" begin
        @throws_pred(1 + 1)   => (false, "no error")
        @throws_pred(error()) => (true, "error")
    end

    @fact "fact_pred tests equality on values" begin
        @fact_pred(1, 1) => (true, 1)
        @fact_pred("foo", "foo") => (true, "foo")

        type Foo a end
        ==(x::Foo, y::Foo) = x.a == y.a
        @fact_pred(Foo(1), Foo(1)) => (x) -> x[1]

        type Bar a end
        @fact_pred(Bar(1), Bar(1)) => (x) -> !x[1]
    end

    @fact "fact_pred applies Function assertions" begin
        @fact_pred(2, iseven) => (true, 2)
        @fact_pred(2, isodd)  => (false, 2)

        isone(x) = x == 1
        @fact_pred(1, isone)  => (true, 1)
    end

end

@facts "FactCheck assertion helper functions" begin

    @fact "`not` works for values and functions" begin
        notone = not(1)
        notone(2) => true
        notone(1) => false

        noteven = not(iseven)
        noteven(3) => true
        noteven(2) => false
        not(iseven)(2) => false
    end

    @fact "`truthy` is anything other than nothing or false (which is 0)" begin
        truthy(-1) => true
        truthy("") => true
        truthy([]) => true
        truthy(Dict())  => true
        truthy(nothing) => false
        truthy(false)   => false
        truthy(0)       => false
    end

    @fact "`anything` and `irrelevant` are always true" begin
        anything => exactly(irrelevant)
        anything(false)   => true
        irrelevant(false) => true
    end

    @fact "`exactly` can be used to check object equality" begin
        exactly(exactly)(exactly) => true

        x() = ()
        exactly(x)(x) => true

        # types with no fields return a singleton object when instantiated
        type Baz end
        exactly(Baz())(Baz()) => true

        type Bazz a end
        exactly(Bazz(1))(Bazz(1)) => false
    end

    @fact "`roughly` compares numbers... roughly" begin
        2.4999999999999 => roughly(2.5) #roughly(2.5)(2.4999) => true
        9.5 => roughly(10, 1.0) #roughly(10, 1)(9.5) => true
        10.5 => roughly(10, 1.0) #roughly(10, 1)(10.5) => true
    end

    @fact "`roughly` compares matrixes... roughly" begin
        X = [1.1 1.2; 2.1 2.2]
        Y = X + [0 0.000001; -0.00000349 0.00001]
        X => roughly(Y)
    end

end
