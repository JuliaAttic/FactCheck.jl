using DeFacto

# We have to define macros around certain functions that return expressions
# so that the :escape Exprs inside them are expanded.
#
# See: https://gist.github.com/zachallaun/5257930
#
macro throws_pred(ex) DeFacto.throws_pred(ex) end
macro fact_pred(x, y) DeFacto.fact_pred(x, y) end

@facts "DeFacto core functions" begin

    @fact "throws_pred is true on error" begin
        @throws_pred(1 + 1)   => false
        @throws_pred(error()) => true
    end

    @fact "fact_pred tests equality on values" begin
        @fact_pred(1, 1) => true
        @fact_pred("foo", "foo") => true

        type Foo a end
        ==(x::Foo, y::Foo) = x.a == y.a
        @fact_pred(Foo(1), Foo(1)) => true

        type Bar a end
        @fact_pred(Bar(1), Bar(1)) => false
    end

    @fact "fact_pred applies Function assertions" begin
        @fact_pred(2, iseven) => true
        @fact_pred(2, isodd)  => false

        isone(x) = x == 1
        @fact_pred(1, isone)  => true
    end

end

@facts "DeFacto assertion helper functions" begin

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
        roughly(2.5)(2.4999) => true

        roughly(10, 1)(9.5) => true
        roughly(10, 1)(10.5) => true
    end

end
