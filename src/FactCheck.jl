######################################################################
# FactCheck.jl
# A testing framework for Julia
# http://github.com/JuliaLang/FactCheck.jl
# MIT Licensed
######################################################################

module FactCheck

using Compat
import Compat.String

export @fact, @fact_throws, @pending,
       facts, context,
       getstats, exitstatus,
       # Assertion helpers
       not,
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
    function ResultMetadata(;line=nothing, msg=nothing)
        new(line, msg)
    end
end

type Success <: Result
    expr::Expr
    fact_type::Symbol
    lhs  # What it was
    rhs  # What it should have been
    meta::ResultMetadata
end

type Failure <: Result
    expr::Expr
    fact_type::Symbol
    lhs  # What it was
    rhs  # What it should have been
    meta::ResultMetadata
end

type Error <: Result
    expr::Expr
    fact_type::Symbol
    err::Exception
    backtrace
    meta::ResultMetadata
end

type Pending <: Result
end

# Collection of all results across facts
allresults = Result[]
clear_results() = (global allresults; allresults = Result[])

# Formats a fact expression
function format_fact(ex::Expr)
    if ex.head == :(-->) || ex.head == :(=>)
        # :(fn(1) --> 2) to 'fn(1) --> 2'
        # :("1"*"1" --> "11") to '"1" * "1" --> "11"'
        # We handle non-expresion arguments differently,
        # otherwise, e.g. quote marks on strings disappear
        x, y = ex.args
        x_str = sprint(isa(x,Expr) || isa(x,Symbol) ? print : show, x)
        y_str = sprint(isa(y,Expr) || isa(y,Symbol) ? print : show, y)
        string(x_str, " --> ", y_str)
    else
        # Something else, that maybe didn't have a -->
        # such as @fact_throws. Punt and just stringify
        string(ex)
    end
end

# Builds string with line and context annotations, if available
format_line(r::Result) = string(
    r.meta.line != nothing ? " :: (line:$(r.meta.line))" : "",
    isempty(contexts) ? "" : " :: $(contexts[end])",
    r.meta.msg != nothing ? " :: $(r.meta.msg)" : "")

# Define printing functions for the result types
function Base.show(io::IO, f::Failure)
    base_ind, sub_ind = get_indent()
    print_with_color(:red, io, base_ind, "Failure")

    if f.fact_type == :fact_throws
        # @fact_throws didn't get an error, or the right type of error
        println(io, format_line(f), " :: ", f.lhs)
        print(io, sub_ind, "Expression: ", f.expr)
        if f.rhs != :fact_throws_noerror
            println(io)
            println(io, sub_ind, "  Expected: ", f.rhs[1])
            print(  io, sub_ind, "  Occurred: ", f.rhs[2])
        end
    elseif f.fact_type == :fact
        # @fact didn't get the right result
        args = f.expr.args
        println(io, format_line(f), " :: fact was false")
        println(io, sub_ind, "Expression: ", format_fact(f.expr))
        if length(args) >= 2 && _factcheck_function(args[2]) != nothing
            # Fancy helper fact
            fcFunc = _factcheck_function(args[2])
            if haskey(FACTCHECK_FUN_NAMES, fcFunc)
                print(io, sub_ind, "  Expected: ",
                        sprint(show, f.lhs),
                        " ", FACTCHECK_FUN_NAMES[fcFunc], " ",
                        sprint(show, f.rhs))
            else
                print(io, sub_ind, "  Expected: ",
                        sprint(show, f.lhs), " --> ", fcFunc,
                        "(", sprint(show, f.rhs), ")")
            end
        else
            # Normal equality-test-style fact
            println(io, sub_ind, "  Expected: ", sprint(show, f.rhs))
            print(  io, sub_ind, "  Occurred: ", sprint(show, f.lhs))
        end
    else
        error("Unknown fact type: ", f.fact_type)
    end
end
function Base.show(io::IO, e::Error)
    base_ind, sub_ind = get_indent()
    print_with_color(:red, io, base_ind, "Error")
    println(io, format_line(e))
    println(io, sub_ind, "Expression: ", format_fact(e.expr))
    bt_str = sprint(showerror, e.err, e.backtrace)
    print(io, join(map(line->string(sub_ind,line),
                        split(bt_str, "\n")), "\n"))
end
function Base.show(io::IO, s::Success)
    base_ind, sub_ind = get_indent()
    print_with_color(:green, io, base_ind, "Success")
    print(io, format_line(s))
    if s.rhs == :fact_throws_error
        print(io, " :: ", s.lhs)
    else
        println(io, " :: fact was true")
        println(io, sub_ind, "Expression: ", format_fact(s.expr))
        println(io, sub_ind, "  Expected: ", sprint(show, s.rhs))
        print(  io, sub_ind, "  Occurred: ", sprint(show, s.lhs))
    end
end
function Base.show(io::IO, p::Pending)
    base_ind, sub_ind = get_indent()
    print_with_color(:yellow, io, base_ind, "Pending")
end

# When in compact mode, we simply print a single character
print_compact(f::Failure) = print_with_color(:red, "F")
print_compact(e::Error)   = print_with_color(:red, "E")
print_compact(s::Success) = print_with_color(:green, ".")
print_compact(s::Pending) = print_with_color(:yellow, "P")

const SPECIAL_FACTCHECK_FUNCTIONS =
    Set([:not, :exactly, :roughly, :anyof,
         :less_than, :less_than_or_equal, :greater_than, :greater_than_or_equal])

@compat const FACTCHECK_FUN_NAMES =
    Dict{Symbol,AbstractString}(
      :roughly => "≅",
      :less_than => "<",
      :less_than_or_equal => "≤",
      :greater_than => ">",
      :greater_than_or_equal => "≥")

isexpr(x) = isa(x, Expr)
iscallexpr(x) = isexpr(x) && x.head == :call
isdotexpr(x) = isexpr(x) && x.head == :.
isquoteexpr(x) = isexpr(x) && x.head == :quote
isparametersexpr(x) = isexpr(x) && x.head == :parameters

function _factcheck_function(assertion)
    iscallexpr(assertion) || return nothing

    # checking for lhs => roughly(rhs)
    if assertion.args[1] in SPECIAL_FACTCHECK_FUNCTIONS
        return assertion.args[1]
    end

    # checking for lhs => FactCheck.roughly(rhs)
    isdotexpr(assertion.args[1]) || return nothing
    dotexpr = assertion.args[1]
    length(dotexpr.args) >= 2 || return nothing
    if isquoteexpr(dotexpr.args[2])
        quoteexpr = dotexpr.args[2]
        if length(quoteexpr.args) >= 1 && quoteexpr.args[1] in SPECIAL_FACTCHECK_FUNCTIONS
            return quoteexpr.args[1]
        else
            return nothing
        end
    end

    # sometimes it shows up as a QuoteNode...
    if isa(dotexpr.args[2], QuoteNode) && dotexpr.args[2].value in SPECIAL_FACTCHECK_FUNCTIONS
        return dotexpr.args[2].value
    end
    nothing
end


######################################################################
# Core testing macros and functions

# @fact takes an assertion of the form LHS --> RHS, and replaces it
# with code to evaluate that fact (depending on the type of the RHS),
# and produce and record a result based on the outcome
macro fact(factex::Expr, args...)
    if factex.head != :(-->) && factex.head != :(=>)
        error("Incorrect usage of @fact: $factex")
    end
    if factex.head == :(=>)
        Base.warn_once("The `=>` syntax is deprecated, use `-->` instead")
    end
    # Extract the two sides of the fact
    lhs, initial_rhs = factex.args
    # If there is another argument to the macro, assume it is a
    # message and record it
    msg = length(args) > 0 ? args[1] : (:nothing)

    # rhs is the assertion, unless it's wrapped by a special FactCheck function
    rhs = initial_rhs
    if _factcheck_function(initial_rhs) != nothing
        rhs = initial_rhs.args[isparametersexpr(initial_rhs.args[2]) ? 3 : 2]
    end

    quote
        # Build a function (predicate) that, depending on the nature of
        # the RHS, either compares the sides or applies the RHS to the LHS
        predicate = function(lhs_value)
            rhs_value = $(esc(initial_rhs))
            if isa(rhs_value, Function)
                # The RHS is a function, so instead of testing for equality,
                # return the value of applying the RHS to the LHS
                (rhs_value(lhs_value), lhs_value, $(esc(rhs)))
            else
                # The RHS is a value, so test for equality
                (rhs_value == lhs_value, lhs_value, $(esc(rhs)))
            end
        end
        # Replace @fact with a call to the do_fact function that constructs
        # the test result object by evaluating the
        do_fact(() -> predicate($(esc(lhs))),
                $(Expr(:quote, factex)),
                :fact,
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
        if (isa(args[1],Symbol) || isa(args[1],Expr)) && isa(args[2],Expr)
            extype, expr = args
        elseif isa(args[1],Expr)
            expr, msg = args
        else
            throw(ArgumentError("invalid @fact_throws macro"))
        end
    elseif nargs >= 3
        if (isa(args[1],Symbol) || isa(args[1], Expr)) && isa(args[2],Expr)
            extype, expr, msg = args
        else
            throw(ArgumentError("invalid @fact_throws macro"))
        end
    end
    quote
        do_fact(() -> try
                          $(esc(expr))
                          (false, "no exception was thrown", :fact_throws_noerror)
                      catch ex
                          $(if extype === nothing
                              :((true, "an exception was thrown", :fact_throws_error))
                            else
                              :(if isa(ex,$(esc(extype)))
                                  (true, "correct exception was throw", :fact_throws_error)
                                else
                                  (false, "wrong exception was thrown",
                                    ($(esc(extype)),typeof(ex)) )
                                end)
                            end)
                      end,
                $(Expr(:quote, expr)),
                :fact_throws,
                ResultMetadata(line=getline(),msg=$(esc(msg))))
    end
end

# `do_fact` constructs a Success, Failure, or Error depending on the
# outcome of a test and passes it off to the active test handler
# `FactCheck.handlers[end]`. It finally returns the test result.
function do_fact(thunk::Function, factex::Expr, fact_type::Symbol, meta::ResultMetadata)
    result = try
        res, val, rhs = thunk()
        res ? Success(factex, fact_type, val, rhs, meta) :
                Failure(factex, fact_type, val, rhs, meta)
    catch err
        Error(factex, fact_type, err, catch_backtrace(), meta)
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
global LEVEL = 0
function context(f::Function, desc::AbstractString)
    global LEVEL
    push!(contexts, desc)
    LEVEL += 1
    !CONFIG[:compact] && println(INDENT^LEVEL, "> ", desc)
    try
        f()
    finally
        pop!(contexts)
        LEVEL -= 1
    end
end
context(f::Function) = context(f, "")

# get_indent
# Gets indent levels to use for displaying results
function get_indent()
    ind_level = isempty(handlers) ? 0 : LEVEL+1
    return INDENT^ind_level, INDENT^(ind_level+1)
end

######################################################################

if VERSION < v"0.5.0-dev+2428"
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
else
    @noinline getline() = StackTraces.stacktrace()[2].line
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
    @compat(Dict{String,Int}("nSuccesses" => s,
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
