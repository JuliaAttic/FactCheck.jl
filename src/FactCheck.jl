module FactCheck

export @fact,
       @fact_throws,
       facts,
       context,
       getStats,
       # assertion helpers
       not,
       truthy,
       falsey,
       falsy,
       anything,
       irrelevant,
       exactly,
       roughly

allresults = {}

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

# Represents the result of a test. The `meta` dictionary is used to retain
# information about the test, such as its file, line number, description, etc.
#
abstract Result
type Success <: Result
    expr::Expr
    val
    meta::Dict
end
type Failure <: Result
    expr::Expr
    val
    meta::Dict
end
type Error <: Result
    expr::Expr
    err::Exception
    backtrace
    meta::Dict
end

# Taken from Base.Test
#
# Allows Errors to be passed to `rethrow`:
#
#     try
#         # ...
#     catch e
#         err = Error(expr, e, catch_backtrace(), Dict())
#     end
#
#     # ...
#     rethrow(err)
#
import Base.showerror
function showerror(io::IO, r::Error, backtrace)
    println(io, "Test error: $(r.expr)")
    showerror(io, r.err, r.backtrace)
end
showerror(io::IO, r::Error) = showerror(io, r, {})

# A TestSuite collects the results of a series of tests, as well as some
# information about the tests such as their file and description.
#
type TestSuite
    filename
    desc
    successes::Array{Success}
    failures::Array{Failure}
    errors::Array{Error}
end
function TestSuite(filename, desc)
    TestSuite(filename, desc, Success[], Failure[], Error[])
end

# Display
# =======

const RED     = "\x1b[31m"
const GREEN   = "\x1b[32m"
const BOLD    = "\x1b[1m"
const DEFAULT = "\x1b[0m"

colored(s::String, color) = string(color, s, DEFAULT)
red(s::String)   = colored(s, RED)
green(s::String) = colored(s, GREEN)
bold(s::String)  = colored(s, BOLD) # Bold is a color. Shut up.

pluralize(s::String, n::Number) = n == 1 ? s : string(s, "s")

# Formats a FactCheck assertion (e.g. `fn(1) => 2`)
#
#     format_assertion(:(fn(1) => 2))
#     # => ":(fn(1)) => 2"
#
function format_assertion(ex::Expr)
    x, y = ex.args
    "$(repr(x)) => $(repr(y))"
end

# Appends a line annotation to a string if the given Result has line information
# in its `meta` dictionary.
#
#     format_line(Success(:(1 => 1), Dict()), "Success")
#     # => "Success :: "
#
#     format_line(Success(:(1 => 1), {"line" => line_annotation}), "Success")
#     # => "Success (line:10) :: "
#
function format_line(r::Result, s::String)
    formatted = haskey(r.meta, "line") ? "$s :: (line:$(r.meta["line"]))" : s
    string(formatted, isempty(contexts) ? "" : " :: $(contexts[end])")
end

format_value(r::Failure, s::String) = "$s :: got $(repr(r.val))"

# Implementing Base.show(io::IO, t::SomeType) gives you control over the
# printed representation of that type. For example:
#
#     type Foo
#     a
#     end
#
#     show(io::IO, f::Foo) = print("Foo: a=$(repr(f.a))")
#
#     print(Foo("attr"))
#     # prints Foo: a="attr"
#
import Base.show

function show(io::IO, f::Failure)
    formatted = "$(red("Failure"))"
    formatted = format_line(f, formatted)
    formatted = format_value(f, formatted)
    println(io, formatted)
    println(io, format_assertion(f.expr))
end

function show(io::IO, e::Error)
    formatted = "$(red("Error"))"
    formatted = format_line(e, formatted)
    println(io, formatted)
    showerror(STDOUT, e)
    println(io)
end

function show(io::IO, s::Success)
    formatted = "$(green("Success")) :: $(format_assertion(s.expr))"
    print(io, formatted)
end

function show(io::IO, suite::TestSuite)
    if length(suite.failures) == 0 && length(suite.errors) == 0
        println(io, green("$(length(suite.successes)) $(pluralize("fact", length(suite.successes))) verified."))
    else
        total = length(suite.successes) + length(suite.failures) + length(suite.errors)
        println(io, "Out of $total total $(pluralize("fact", total)):")
        println(io, green("  Verified: $(length(suite.successes))"))
        println(io,   red("  Failed:   $(length(suite.failures))"))
        println(io,   red("  Errored:  $(length(suite.errors))"))
    end
end

function format_suite(suite::TestSuite)
    s = suite.desc != nothing ? "$(suite.desc) " : ""
    s = string(s, suite.filename != nothing ? "($(suite.filename))" : "")
    bold(string(s, "\n"))
end

# FactCheck core functions and macros
# ========================================

# The last handler function found in `handlers` will be passed test results.
# This means the default handler set up by FactCheck could be overridden with
# `push!(FactCheck.handlers, my_custom_handler)`.
#
const handlers = Function[]

# A list of test contexts. `contexts[end]` should be the inner-most context.
#
const contexts = String[]

# `do_fact` constructs a Success, Failure, or Error depending on the outcome
# of a test and passes it off to the active test handler (`FactCheck.handlers[end]`).
#
# `thunk` should be a parameterless boolean function representing a test.
# `factex` should be the Expr from which `thunk` was constructed.
# `meta` should contain meta information about the test.
#
function do_fact(thunk::Function, factex::Expr, meta::Dict)
    result = try
        res, val = thunk()
        res ? Success(factex, val, meta) : Failure(factex, val, meta)
    catch err
        Error(factex, err, catch_backtrace(), meta)
    end

    !isempty(handlers) && handlers[end](result)
    push!(allresults, result)
    result
end

# Constructs a boolean expression from a given expression `ex` that, when
# evaluated, returns true if `ex` throws an error and false if `ex` does not.
#
throws_pred(ex) = quote
    try
        $(esc(ex))
        (false, "no error")
    catch e
        (true, "error")
    end
end

# Constructs a boolean expression from two values that works differently
# depending on what `assertion` evaluates to.
#
# If `assertion` evaluates to a function, the result of the expression will be
# `assertion(ex)`. Otherwise, the result of the expression will be
# `assertion == ex`.
#
function fact_pred(ex, assertion)
    quote
        pred = function(t)
            e = $(esc(assertion))
            isa(e, Function) ? (e(t), t) : (e == t, t)
        end
        pred($(esc(ex)))
    end
end

# `@fact` rewrites assertions and generates calls to `do_fact`, which
# is responsible for actually running the test.
#
#     macroexpand(:(@fact 1 => 1))
#     #=> do_fact( () -> 1 == 1, :(1 => 1), ...)
#
macro fact(factex::Expr)
    if factex.head == :(=>)
        :(do_fact(() -> $(fact_pred(factex.args...)),
                  $(Expr(:quote, factex)),
                  {"line" => getline()}))
    else
        error("@fact doesn't support expression: $factex")
    end
end

macro fact_throws(factex::Expr)
    :(do_fact(() -> $(throws_pred(factex)),
              $(Expr(:quote, factex)),
              {"line" => getline()}))
end

# Constructs a function that handles Successes, Failures, and Errors,
# pushing them into a given TestSuite and printing Failures and Errors
# as they arrive.
#
function make_handler(suite::TestSuite)
    function delayed_handler(r::Success)
        push!(suite.successes, r)
    end
    function delayed_handler(r::Failure)
        push!(suite.failures, r)
        println(r)
    end
    function delayed_handler(r::Error)
        push!(suite.errors, r)
        println(r)
    end
    delayed_handler
end

# Executes a battery of tests in some descriptive context.
#
function context(f::Function, desc)
    push!(contexts, desc)
    f()
    pop!(contexts)
end
context(f::Function) = f()

# `facts` creates test scope. It is responsible for setting up a testing
# environment, which means constructing a `TestSuite`, generating and
# registering test handlers, and reporting results.
#
# `f` should be a function containing `@fact` invocations.
#
facts(f::Function) = facts(f, nothing)
function facts(f::Function, desc)
    suite = TestSuite(nothing, desc)
    test_handler = make_handler(suite)
    push!(handlers, test_handler)

    println()
    println(format_suite(suite))

    f()

    println(suite)

    pop!(handlers)
end

# `getStats` return a dictionary with a summary over all tests run

function getStats()
    s = 0
    f = 0
    e = 0
    ns = 0
    for r in allresults
        if isa(r, Success)
            s += 1
        elseif isa(r, Failure)
            f += 1
            ns += 1
        elseif isa(r, Error)
            e += 1
            ns += 1
        end
    end
    assert(s+f+e == length(allresults) == s+ns)
    {"nSuccesses" => s, "nFailures" => f, "nErrors" => e, "nNonSuccessful" => ns}
end

# Assertion helpers
# =================

# Logical not for values and functions.
not(x) = isa(x, Function) ? (y) -> !x(y) : (y) -> x != y

# Truthiness is defined as not `nothing` or `false` (which is 0).
# Falsiness is its opposite.
#
truthy(x) = nothing != x != false
falsey = falsy = not(truthy)

irrelevant = anything(x) = true

# Can be used to test object/function equality:
#
#     @fact iseven => exactly(iseven)
#
exactly(x) = (y) -> is(x, y)

# Useful for comparing floating point numbers:
#
#     @fact 4.99999 => roughly(5)
#

roughly(n::Number; kvtols...) = i::Number -> isapprox(i,n; kvtols...)

roughly(X::AbstractArray; kvtols...) = Y::AbstractArray -> begin
    if size(X) != size(Y)
        return false
    end

    for i in 1:length(X)
        if !isapprox(X[i], Y[i]; kvtols...)
            return false
        end
    end
    return true
end

end # module FactCheck
