######################################################################
# FactCheck.jl
# A testing framework for Julia
# http://github.com/JuliaLang/FactCheck.jl
# MIT Licensed
######################################################################

module FactCheck

using Compat

export @fact, @fact_throws, @pending,
       facts, context,
       getstats, exitstatus,
       # Assertion helpers
       not,
       anything,
       truthy, falsey, falsy,
       exactly,
       roughly,
       anyof,
       less_than, less_than_or_equal,
       greater_than, greater_than_or_equal

const INDENT = "  "

# Global configuration for FactCheck
const CONFIG = @compat Dict(:compact => false, :only_stats => false)  # Compact output off by default
# Not exported: sets output style
function setstyle(style)
    global CONFIG
    CONFIG[:compact] = (style == :compact)
end

function onlystats(flag)
    global CONFIG
    CONFIG[:only_stats] = flag
end

######################################################################
# Success, Failure, Error <: Result
# Represents the result of a test. These are very similar to the types
# with the same names in Base.Test, except for the addition of the
# `ResultMetadata` type that is used to retain information about the test,
# such as its file, line number, description, etc.
abstract Result

type ResultMetadata
    line
    msg
    ResultMetadata(;line=nothing, msg=nothing) = begin
        new(line, msg)
    end
end

type Success <: Result
    expr::Expr
    val
    meta::ResultMetadata
end

type Failure <: Result
    expr::Expr
    val
    meta::ResultMetadata
end

type Error <: Result
    expr::Expr
    err::Exception
    backtrace
    meta::ResultMetadata
end

type Pending <: Result
end

# Collection of all results across facts
allresults = Result[]
clear_results() = (global allresults; allresults = Result[])

# Formats a FactCheck assertion
# e.g. :(fn(1) => 2) to  `fn(1) => 2`
function format_assertion(ex::Expr)
    x, y = ex.args
    "$x => $y"
end

# Builds string with line and context annotations, if available
format_line(r::Result) = string(
    r.meta.line != nothing ? " :: (line:$(r.meta.line))" : "",
    isempty(contexts) ? "" : " :: $(contexts[end])",
    r.meta.msg != nothing ? " :: $(r.meta.msg)" : "")

# Define printing functions for the result types
function Base.show(io::IO, f::Failure)
    indent = isempty(handlers) ? "" : INDENT
    print_with_color(:red, io, indent, "Failure")
    println(io, indent, format_line(f), " :: got ", f.val)
    print(io, indent^2, format_assertion(f.expr))
end
function Base.show(io::IO, e::Error)
    indent = isempty(handlers) ? "" : INDENT
    print_with_color(:red, io, indent, "Error")
    println(io, indent, format_line(e))
    println(io, indent^2, format_assertion(e.expr))
    Base.showerror(io, e.err, e.backtrace)
    print(io)
end
function Base.show(io::IO, s::Success)
    indent = isempty(handlers) ? "" : INDENT
    print_with_color(:green, io, indent, "Success")
    print(io, " :: $(format_assertion(s.expr))")
end
function Base.show(io::IO, p::Pending)
    indent = isempty(handlers) ? "" : INDENT
    print_with_color(:yellow, io, indent, "Pending")
end

# When in compact mode, we simply print a single character
print_compact(f::Failure) = print_with_color(:red, "F")
print_compact(e::Error) = print_with_color(:red, "E")
print_compact(s::Success) = print_with_color(:green, ".")
print_compact(s::Pending) = print_with_color(:yellow, "P")

######################################################################
# Core testing macros and functions

# `@fact` is the workhorse macro. It
# * takes in the expresion-assertion pair,
# * converts it to a function that returns tuple (success, assertval)
# * processes and stores result of test [do_fact]
macro fact(factex::Expr, args...)
    factex.head != :(=>) && error("Incorrect usage of @fact: $factex")
    expr, assertion = factex.args
    msg = length(args) > 0 ? args[1] : :nothing
    quote
        pred = function(t)
            e = $(esc(assertion))
            isa(e, Function) ? (e(t), t) : (e == t, t)
        end
        do_fact(() -> pred($(esc(expr))),
                $(Expr(:quote, factex)),
                ResultMetadata(line=getline(),
                               msg=$(esc(msg))))
    end
end

# `@fact_throws` is similar to `@fact`, except it only checks if
# the expression throws an error or not - there is no explict
# assertion to compare against.
macro fact_throws(args...)
    expr, extype, msg = nothing, nothing, nothing
    nargs = length(args)
    if nargs == 1
        if isa(args[1],Expr)
            expr = args[1]
        else
            throw(ArgumentError("invalid @fact_throws macro"))
        end
    elseif nargs == 2
        if isa(args[1],Symbol) && isa(args[2],Expr)
            extype, expr = args
        elseif isa(args[1],Expr)
            expr, msg = args
        else
            throw(ArgumentError("invalid @fact_throws macro"))
        end
    elseif nargs >= 3
        if isa(args[1],Symbol) && isa(args[2],Expr)
            extype, expr, msg = args
        else
            throw(ArgumentError("invalid @fact_throws macro"))
        end
    end
    quote
        do_fact(() -> try
                          $(esc(expr))
                          (false, "no error")
                      catch ex
                          $(if is(extype, nothing)
                              :((true, "error"))
                            else
                              :(if isa(ex,$(esc(extype)))
                                  (true,"error")
                                else
                                  $(:((false, "wrong argument type, expected $($(esc(extype))) got $(typeof(ex))")))
                                end)
                            end)
                      end,
                $(Expr(:quote, expr)),
                ResultMetadata(line=getline(),msg=$(esc(msg))))
    end
end

# `do_fact` constructs a Success, Failure, or Error depending on the
# outcome of a test and passes it off to the active test handler
# `FactCheck.handlers[end]`. It finally returns the test result.
function do_fact(thunk::Function, factex::Expr, meta::ResultMetadata)
    result = try
        res, val = thunk()
        res ? Success(factex, val, meta) : Failure(factex, val, meta)
    catch err
        Error(factex, err, catch_backtrace(), meta)
    end

    !isempty(handlers) && handlers[end](result)
    if CONFIG[:only_stats]
        updatestats!(getstats([result]))
    else
        push!(allresults, result)
    end
    CONFIG[:compact] && print_compact(result)
    result
end

# `@pending` is a no-op test - it doesn't do anything except record
# its existance in the final totals of tests "run"
macro pending(factex::Expr, args...)
    quote
        result = Pending()
        !isempty(handlers) && handlers[end](result)
        if CONFIG[:only_stats]
            updatestats!(getstats([result]))
        else
            push!(allresults, result)
        end
        CONFIG[:compact] && print_compact(result)
        result
    end
end

######################################################################
# Grouping of tests
#
# `facts` describes a top-level test scope, which can contain
# `contexts` to group similar tests. Test results will be collected
# instead of throwing an exception immediately.

# A TestSuite collects the results of a series of tests, as well as
# some information about the tests such as their file and description.
type TestSuite
    filename
    desc
    successes::Vector{Success}
    failures::Vector{Failure}
    errors::Vector{Error}
    pending::Vector{Pending}
end
TestSuite(f, d) = TestSuite(f, d, Success[], Failure[], Error[], Pending[])

function Base.print(io::IO, suite::TestSuite)
    n_succ = length(suite.successes)
    n_fail = length(suite.failures)
    n_err  = length(suite.errors)
    n_pend = length(suite.pending)
    total  = n_succ + n_fail + n_err + n_pend
    if n_fail == 0 && n_err == 0 && n_pend == 0
        print_with_color(:green, io, "$n_succ $(pluralize("fact", n_succ)) verified.\n")
    else
        println(io, "Out of $total total $(pluralize("fact", total)):")
        n_succ > 0 && print_with_color(:green, io, "  Verified: $n_succ\n")
        n_fail > 0 && print_with_color(:red,   io, "  Failed:   $n_fail\n")
        n_err  > 0 && print_with_color(:red,   io, "  Errored:  $n_err\n")
        n_pend > 0 && print_with_color(:yellow,io, "  Pending:  $n_pend\n")
    end
end

function print_header(suite::TestSuite)
    print_with_color(:bold,
        suite.desc     != nothing ? "$(suite.desc)" : "",
        suite.filename != nothing ? " ($(suite.filename))" : "",
        CONFIG[:compact] ? ": " : "\n")
end

# The last handler function found in `handlers` will be passed
# test results.
const handlers = Function[]

# A list of test contexts. `contexts[end]` should be the
# inner-most context.
const contexts = AbstractString[]

# Constructs a function that handles Successes, Failures, and Errors,
# pushing them into a given TestSuite and printing Failures and Errors
# as they arrive (unless in compact mode, in which case we delay
# printing details until the end).
function make_handler(suite::TestSuite)
    function delayed_handler(r::Success)
        push!(suite.successes, r)
    end
    function delayed_handler(r::Failure)
        push!(suite.failures, r)
        !CONFIG[:compact] && println(r)
    end
    function delayed_handler(r::Error)
        push!(suite.errors, r)
        !CONFIG[:compact] && println(r)
    end
    function delayed_handler(p::Pending)
        push!(suite.pending, p)
    end
    delayed_handler
end

# facts
# Creates testing scope. It is responsible for setting up a testing
# environment, which means constructing a `TestSuite`, generating
# and registering test handlers, and reporting results.
function facts(f::Function, desc)
    suite = TestSuite(nothing, desc)
    handler = make_handler(suite)
    push!(handlers, handler)
    print_header(suite)
    f()
    if !CONFIG[:compact]
        # Print out summary of test suite
        print(suite)
    else
        # If in compact mode, we need to display all the
        # failures we hit along along the way
        println()  # End line with dots
        map(println, suite.failures)
        map(println, suite.errors)
    end
    pop!(handlers)
end
facts(f::Function) = facts(f, nothing)

# context
# Executes a battery of tests in some descriptive context, intended
# for use inside of `facts`. Displays the string in default mode.
# for use inside of facts
global LEVEL = 1
function context(f::Function, desc::AbstractString)
    global LEVEL
    push!(contexts, desc)
    LEVEL += 1
    !CONFIG[:compact] && println(INDENT^LEVEL * " - ", desc)
    try
        f()
    finally
        pop!(contexts)
        LEVEL -= 1
    end
end
context(f::Function) = f()


######################################################################

# HACK: get the current line number
#
# This only works inside of a function body:
#
#     julia> hmm = function()
#                2
#                3
#                getline()
#            end
#
#     julia> hmm()
#     4
#
function getline()
    bt = backtrace()
    issecond = false
    for frame in bt
        lookup = ccall(:jl_lookup_code_address, Any, (Ptr{Void}, Int32), frame, 0)
        if lookup != ()
            if issecond
                return lookup[3]
            else
                issecond = true
            end
        end
    end
end

pluralize(s::AbstractString, n::Number) = n == 1 ? s : string(s, "s")

# `getstats` return a dictionary with a summary over all tests run
getstats() = getstats(allresults)

function getstats(results)
    s = 0
    f = 0
    e = 0
    p = 0
    for r in results
        if isa(r, Success)
            s += 1
        elseif isa(r, Failure)
            f += 1
        elseif isa(r, Error)
            e += 1
        elseif isa(r, Pending)
            p += 1
        end
    end
    assert(s+f+e+p == length(results))
    @compat(Dict{ByteString,Int}("nSuccesses" => s,
                                 "nFailures" => f,
                                 "nErrors" => e,
                                 "nNonSuccessful" => f+e,
                                 "nPending" => p))
end

const allstats = getstats()

function updatestats!(stats)
    for (key, value) in stats
        allstats[key] += value
    end
end

function exitstatus()
    global CONFIG
    if CONFIG[:only_stats]
        ns = allstats["nNonSuccessful"]
    else
        ns = getstats()["nNonSuccessful"]
    end
    ns > 0 && error("FactCheck finished with $ns non-successful tests.")
end

############################################################
# Assertion helpers
include("helpers.jl")


end # module FactCheck
