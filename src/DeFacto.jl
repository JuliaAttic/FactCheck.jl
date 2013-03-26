module DeFacto

export @fact, @facts

abstract Result
type Success <: Result
    expr::Expr
    meta::Dict
end
type Failure <: Result
    expr::Expr
    meta::Dict
end
type Error <: Result
    expr::Expr
    err::Exception
    backtrace
    meta::Dict
end

import Base.error_show

function error_show(io::IO, r::Error, backtrace)
    println(io, "Test error: $(r.expr)")
    error_show(io, r.err, r.backtrace)
end
error_show(io::IO, r::Error) = error_show(io, r, {})

type TestSuite
    file::String
    desc::Union(String, Nothing)
    nsuccesses::Int
    nfailures::Int
    successes::Array{Success, 1}
    failures::Array{Failure, 1}
end
function TestSuite(file::String, desc::Union(String, Nothing))
    TestSuite(file, desc, 0, 0, Success[], Failure[])
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

function format_failed(ex::Expr)
    x, y = ex.args
    "$(repr(x)) => $(repr(y))"
end

function print_failure(f::Failure)
    formatted = "$(red("Failure")) "
    formatted = string(formatted, has(f.meta, "line") ?
                       "(line:$(f.meta["line"].args[1])) :: " :
                       "")
    formatted = string(formatted, format_failed(f.expr))

    println(formatted)
end

function print_results(suite::TestSuite)
    println()
    if suite.nfailures == 0
        println(green("$(suite.nsuccesses) $(pluralize("fact", suite.nsuccesses)) verified."))
    else
        total = suite.nsuccesses + suite.nfailures
        println("Out of $total total $(pluralize("fact", total)):")
        println(green("  Verified: $(suite.nsuccesses)"))
        println(red("  Failed:   $(suite.nfailures)\n"))
    end
end

function format_suite(suite::TestSuite)
    suite.desc != nothing ? "$(suite.desc) ($(suite.file))" : suite.file
end

# Core
# ====

const handlers = Function[]

function do_fact(thunk, factex, meta)
    result = try
        thunk() ? Success(factex, meta) : Failure(factex, meta)
    catch err
        Error(factex, err, catch_backtrace(), meta)
    end

    handlers[end](result)
end

function rewrite_assertion(factex::Expr, meta::Dict)
    ex, assertion = factex.args
    test = quote
        pred = function(t)
            e = $(esc(assertion))
            isa(e, Function) ? e(t) : e == t
        end
        pred($(esc(ex)))
    end
    :(do_fact(()->$test, $(Expr(:quote, factex)), $meta))
end

function process_fact(desc::Union(String, Nothing), factex::Expr)
    if factex.head == :block
        out = :(begin end)
        for ex in factex.args
            if ex.head == :line
                line_ann = ex
            else
                push!(out.args,
                      ex.head == :(=>) ?
                      rewrite_assertion(ex, {"desc" => desc, "line" => line_ann}) :
                      esc(ex))
            end
        end
        out
    else
        rewrite_assertion(factex, {"desc" => desc})
    end
end
process_fact(factex::Expr) = process_fact(nothing, factex)

function make_handler(suite::TestSuite)
    function delayed_handler(r::Success)
        suite.nsuccesses += 1
        nothing
    end
    function delayed_handler(r::Failure)
        suite.nfailures += 1
        push!(suite.failures, r)
        print_failure(r)
    end
    function delayed_handler(r::Error)
        rethrow(r)
    end
    delayed_handler
end

function do_facts(desc::Union(String, Nothing), facts_block::Expr)
    file_name = split(string(facts_block.args[1].args[2]), "/")[end]

    suite = TestSuite(file_name, desc)
    test_handler = make_handler(suite)
    push!(handlers, test_handler)

    quote
        println(string(format_suite($suite), "\n"))
        $(esc(facts_block))
        print_results($suite)
    end
end
do_facts(facts_block::Expr) = do_facts(nothing, facts_block)

macro facts(args...)
    do_facts(args...)
end

macro fact(args...)
    process_fact(args...)
end

end # module DeFacto
