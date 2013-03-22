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
    file::String
    desc::String
    nsuccesses::Int
    nfailures::Int
    successes::Array{Test.Success, 1}
    failures::Array{Test.Failure, 1}
end
TestSuite(file::String, desc::String) = TestSuite(file, desc, 0, 0, Test.Success[], Test.Failure[])


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

make_pred(f::Function) = :(test(t)= $f(t))
make_pred(v::Any)      = :(test(t)= t == $v)

function make_test(ex::Expr)
    test, assertion, line_ann = ex.args
    pred = make_pred(eval(assertion))
    quote
        @test begin
            $line_ann
            $pred($(esc(test)))
        end
    end
end

function do_fact(ex::Expr)
    if ex.head == :block
        out = :(begin end)
        for subex in ex.args
            if subex.head == :line
                line_ann = subex
            elseif subex.head == :(=>)
                push!(subex.args, line_ann)
            end
            push!(out.args, subex.head == :(=>) ? do_fact(subex) : subex)
        end
        out
    else
        make_test(ex)
    end
end
do_fact(desc::String, ex::Expr) = do_fact(ex)

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

function format_failed_expr(ex::Expr)
    line_ann = ex.args[2]
    line_no = line_ann.args[1]
    arg = repr(ex.args[end].args[end])
    prefix = "(line:$line_no) :: $arg => "
    test = ex.args[end].args[1]
    if isa(test, Expr)
        if test.args[end].head == :call
            string(prefix, "$(test.args[end].args[1])")
        else
            string(prefix, "$(repr(test.args[2].args[end]))")
        end
    end
end

function print_failure(failure::Test.Failure)
    formatted = format_failed_expr(failure.expr)
    formatted != nothing && println("$(red("Failure")) $formatted")
end

function print_results(suite::TestSuite)
    println("$(suite.desc) ($(suite.file))")
    if suite.nfailures == 0
        println(green("$(suite.nsuccesses) $(pluralize("fact", suite.nsuccesses)) verified."))
    else
        total = suite.nsuccesses + suite.nfailures
        println("Out of $total total $(pluralize("fact", total)):")
        println(green("  Verified: $(suite.nsuccesses)"))
        println(red("  Failed:   $(suite.nfailures)\n"))

        map(print_failure, suite.failures)
    end
end

# Runner
# ======

function facts(fthunk::Function, desc::String)
    # TODO: Less totally hacky way of finding the file in which
    #       this function was defined
    file_name = string(fthunk.code.ast.args[3].args[2].args[2])
    file_name = split(file_name, "/")[end]

    suite = TestSuite(file_name, desc)
    test_handler = make_handler(suite)
    push!(Test.handlers, test_handler)

    fthunk()

    print_results(suite)
end
facts(fthunk::Function) = facts(fthunk, "")

end # module DeFacto
