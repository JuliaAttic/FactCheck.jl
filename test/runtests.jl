############################################################
# FactCheck.jl
# A testing framework for Julia
# http://github.com/JuliaLang/FactCheck.jl
# MIT Licensed
############################################################

module TestFactCheck

using FactCheck
using Base.Test
using Compat

############################################################
# Before we excerse the other various parts of FactCheck,
# check we actually catch and report errors correctly. This
# also allows us to test printing code for the Failure and
# Error cases, which wouldn't be tested otherwise.
print_with_color(:blue,"Testing Result counting and printing, not actual errors!\n")
facts("Test error pathways") do
    a_success = @fact 1 => 1 "I will never be seen"
    println(a_success)
    a_failure = @fact 1 => 2 "one doesn't equal two!"
    a_error   = @fact 2^-1 => 0.5 "domains are tricky"
    a_pending = @pending not_really_pending() "sorta pending"
    println(a_pending)
end
stats = getstats()
FactCheck.clear_results()
@test stats["nSuccesses"] == 1
@test stats["nFailures"] == 1
@test stats["nErrors"] == 1
@test stats["nPending"] == 1
@test stats["nNonSuccessful"] == 2
print_with_color(:blue,"Done, begin actual FactCheck tests\n")

############################################################
# Begin actual tests
type Foo a end
type Bar a end
type Baz end
type Bazz a end
==(x::Foo, y::Foo) = x.a == y.a

facts("Testing core functionality") do
    @fact 1 => 1
    @fact 2*2 => 4
    @fact uppercase("foo") => "FOO"
    @fact_throws 2^-1
    @fact_throws 2^-1 "a domain error happend"
    @fact_throws DomainError 2^-1
    @fact_throws DomainError 2^-1 "a domain error happened"
    @fact 2*[1,2,3] => [2,4,6]
    @fact Foo(1) => Foo(1)
end

facts("Testing invalid @fact_throws macro") do
    @fact_throws ArgumentError eval(:(@fact_throws "this needs to be an expression"))
    @fact_throws ArgumentError eval(:(@fact_throws "wrong type" :wrong_type))
    @fact_throws ArgumentError eval(:(@fact_throws "wrong type" error("this is an error")))
end

facts("Testing 'context'") do
    # FactCheck.LEVEL starts from 1
    @fact FactCheck.LEVEL => 1

    context("context will increase LEVEL and set contexts") do
        @fact FactCheck.LEVEL => 2
        @fact FactCheck.contexts[end] => "context will increase LEVEL and set contexts"
    end

    @fact FactCheck.LEVEL => 1

    # context is called without 'desc' won't increase LEVEL
    context() do
        @fact FactCheck.LEVEL => 1
    end

    context("nested context") do
        @fact FactCheck.LEVEL => 2
        @fact FactCheck.contexts[end] => "nested context"

        context("inner") do
            @fact FactCheck.LEVEL => 3
            @fact FactCheck.contexts[end] => "inner"
        end
    end

    facts("'facts' doesn't increase LEVEL") do
        @fact FactCheck.LEVEL => 1
    end

    context("will execute the function which is passed to the 'context'") do
        executed = false
        f() = (executed = true)

        @fact executed => false
        context(f)
        @fact executed => true
    end

    context("indent by current LEVEL") do
        original_STDOUT = STDOUT
        (out_read, out_write) = redirect_stdout()

        context("intended") do
            close(out_write)
            system_output = readavailable(out_read)
            close(out_read)

            redirect_stdout(original_STDOUT)
            # current LEVEL is 3
            expected_str = "       - intended\n"
            # "  " ^ 3 * " - " * "intended\n"
            @fact system_output => (VERSION >= v"0.4-dev" ?
                                    expected_str.data : expected_str)
        end
    end
end

facts("FactCheck assertion helper functions") do

    context("`not` works for values and functions") do
        notone = not(1)
        @fact notone(2) => true
        @fact notone(1) => false
        @fact 2 => not(1)

        noteven = not(iseven)
        @fact noteven(3) => true
        @fact noteven(2) => false
        @fact not(iseven)(2) => false
        @fact 3 => not(iseven)
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

    context("`anything` is always true") do
        @fact anything(false)   => true
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
        @fact 2.4999999999999 => roughly(2.5)
        @fact 9.5 => roughly(10; atol=1.0)
        @fact 10.5 => roughly(10; atol=1.0)
        @fact 10.5 => roughly(10, 1.0)
    end

    context("`roughly` compares matrixes... roughly") do
        X = [1.1 1.2; 2.1 2.2]
        Y = X + [0 0.000001; -0.00000349 0.00001]
        Z = [1 1; 2 2]
        @fact X => roughly(Y)
        @fact X => roughly(Z; atol=0.2)
        @fact X => roughly(Z, 0.2)
    end

    context("`anyof` compares with all arguments") do
        @fact 2+2 => anyof(4, :four, "four")
        @fact 5   => not(anyof(:five, "five"))
    end

    context("less_than") do
        @fact 1 => less_than(2)
    end

    context("less_than_or_equal") do
        @fact 1 => less_than_or_equal(2)
        @fact 1 => less_than_or_equal(1)
    end

    context("greater_than") do
        @fact 2 => greater_than(1)
    end

    context("greater_than_or_equal") do
        @fact 2 => greater_than_or_equal(1)
        @fact 2 => greater_than_or_equal(2)
    end
end

exitstatus()

end # module

