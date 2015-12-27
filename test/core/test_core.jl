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
    a_success = @fact 1 --> 1 "I will never be seen"
    println(a_success)
    a_failure = @fact 1 --> 2 "one doesn't equal two!"
    a_error   = @fact 2^-1 --> 0.5 "domains are tricky"
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
importall Base.Operators
==(x::Foo, y::Foo) = x.a == y.a

type MyError <: Exception
end

module MyModule
    type MyError <: Exception
    end
end

facts("Testing core functionality") do
    @fact 1 --> 1
    @fact 2*2 --> 4
    @fact uppercase("foo") --> "FOO"
    @fact_throws 2^-1
    @fact_throws 2^-1 "a domain error happend"
    @fact_throws DomainError 2^-1
    @fact_throws DomainError 2^-1 "a domain error happened"
    @fact_throws MyError throw(MyError())
    @fact_throws MyError throw(MyError()) "my error happend"
    @fact_throws MyModule.MyError throw(MyModule.MyError())
    @fact_throws MyModule.MyError throw(MyModule.MyError()) "my error happend"
    @fact 2*[1,2,3] --> [2,4,6]
    @fact Foo(1) --> Foo(1)
end

facts("Testing invalid @fact_throws macro") do
    @fact_throws ArgumentError eval(:(@fact_throws "this needs to be an expression"))
    @fact_throws ArgumentError eval(:(@fact_throws "wrong type" :wrong_type))
    @fact_throws ArgumentError eval(:(@fact_throws "wrong type" error("this is an error")))
end

facts("Testing 'context'") do
    # FactCheck.LEVEL starts from 0
    @fact FactCheck.LEVEL --> 0

    context("context will increase LEVEL and set contexts") do
        @fact FactCheck.LEVEL --> 1
        @fact FactCheck.contexts[end] --> "context will increase LEVEL and set contexts"
    end

    @fact FactCheck.LEVEL --> 0

    # context called without 'desc' will still increase LEVEL
    context() do
        @fact FactCheck.LEVEL --> 1
    end

    context("nested context") do
        @fact FactCheck.LEVEL --> 1
        @fact FactCheck.contexts[end] --> "nested context"

        context("inner") do
            @fact FactCheck.LEVEL --> 2
            @fact FactCheck.contexts[end] --> "inner"
        end
    end

    facts("'facts' doesn't increase LEVEL") do
        @fact FactCheck.LEVEL --> 0
    end

    context("will execute the function which is passed to the 'context'") do
        executed = false
        f() = (executed = true)

        @fact executed --> false
        context(f, "Run f")
        @fact executed --> true
    end

    context("indent by current LEVEL") do
        original_STDOUT = STDOUT
        (out_read, out_write) = redirect_stdout()

        context("intended") do
            close(out_write)
            system_output = readavailable(out_read)
            close(out_read)

            redirect_stdout(original_STDOUT)
            # current LEVEL is 2
            expected_str = string(FactCheck.INDENT^2,"> intended\n")
            @fact system_output --> (VERSION >= v"0.4-dev" ?
                                    expected_str.data : expected_str)
        end
    end
end
