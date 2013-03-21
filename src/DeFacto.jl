module DeFacto

using Test
import Test.do_test,
       Test.Success,
       Test.Failure,
       Test.Error,
       Test.handlers

export @fact, facts

# Setup
# =====

type TestSuite
    nsuccesses::Int
    nfailures::Int
    successes::Array{Test.Success, 1}
    failures::Array{Test.Failure, 1}
end
TestSuite() = TestSuite(0, 0, Test.Success[], Test.Failure[])

test_suite = TestSuite()

# Base.Test integration
# =====================

function make_handler(test_suite::TestSuite)
    function delayed_handler(r::Test.Success)
        test_suite.nsuccesses += 1
        nothing
    end
    function delayed_handler(r::Test.Failure)
        test_suite.nfailures += 1
        push!(test_suite.failures, r)
    end
    function delayed_handler(r::Test.Error)
        rethrow(r)
    end
    delayed_handler
end

# Core testing functions
# ======================

make_pred(f::Function) = :(test(t) = $f(t))
make_pred(v::Any)      = :(test(t) = t == $v)

function make_test(ex::Expr)
    test, assertion = ex.args
    pred = make_pred(eval(assertion))
    :($pred($test))
end

function do_fact(ex::Expr)
    test = make_test(ex)
    :(@test $test)
end

function do_fact(desc::String, ex::Expr)
    if ex.head == :block
        out = :(begin end)
        for subex in ex.args
            if subex.head != :line
                push!(out.args, do_fact(subex))
            end
        end
        out
    else
        do_fact(ex)
    end
end

macro fact(ex...)
    do_fact(ex...)
end

# Display
# =======

RED     = "\x1b[31m"
GREEN   = "\x1b[32m"
DEFAULT = "\x1b[0m"

colored(s::String, color) = string(color, s, DEFAULT)
red(s::String)   = colored(s, RED)
green(s::String) = colored(s, GREEN)

pluralize(s::String, n::Number) = n == 1 ? s : string(s, "s")

print_failure(failure::Test.Failure) = println("\n$(red("Failure:")) $(failure.expr)")

function print_results(suite::TestSuite)
    if suite.nfailures == 0
        println(green("$(suite.nsuccesses) $(pluralize("fact", suite.nsuccesses)) verified."))
    else
        total = suite.nsuccesses + suite.nfailures
        println("Out of $total total $(pluralize("fact", total)):")
        println(green("  Verified: $(suite.nsuccesses)"))
        println(red("  Failed:   $(suite.nfailures)"))

        map(print_failure, suite.failures)
    end
end

# Runner
# ======

function facts(fthunk::Function)
    suite = TestSuite()
    test_handler = make_handler(suite)
    push!(Test.handlers, test_handler)

    fthunk()

    print_results(suite)
end

end # module DeFacto
