module DeFacto

export @fact,
       @facts,
       # assertion helpers
       not,
       truthy,
       falsey,
       falsy,
       anything,
       irrelevant,
       exactly,
       roughly

# Represents the result of a test. The `meta` dictionary is used to retain
# information about the test, such as its file, line number, description, etc.
#
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
import Base.error_show
function error_show(io::IO, r::Error, backtrace)
    println(io, "Test error: $(r.expr)")
    error_show(io, r.err, r.backtrace)
end
error_show(io::IO, r::Error) = error_show(io, r, {})

# A TestSuite collects the results of a series of tests, as well as some
# information about the tests such as their file and description.
#
type TestSuite
    file::String
    desc::Union(String, Nothing)
    successes::Array{Success}
    failures::Array{Failure}
    errors::Array{Error}
end
function TestSuite(file::String, desc::Union(String, Nothing))
    TestSuite(file, desc, Success[], Failure[], Error[])
end

# Display
# =======

RED     = "\x1b[31m"
GREEN   = "\x1b[32m"
BOLD    = "\x1b[1m"
DEFAULT = "\x1b[0m"

colored(s::String, color) = string(color, s, DEFAULT)
red(s::String)   = colored(s, RED)
green(s::String) = colored(s, GREEN)
bold(s::String)  = colored(s, BOLD) # Bold is a color. Shut up.

pluralize(s::String, n::Number) = n == 1 ? s : string(s, "s")

# Formats a DeFacto assertion (e.g. `fn(1) => 2`)
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
    formatted = if has(r.meta, "line")
        "$s (line:$(r.meta["line"].args[1])) :: "
    else
        "$s :: "
    end

    string(formatted, r.meta["desc"] == nothing ? "" : r.meta["desc"])
end

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
    println(io, formatted)
    println(io, format_assertion(f.expr))
end

function show(io::IO, e::Error)
    formatted = "$(red("Error"))  "
    formatted = format_line(e, formatted)
    println(io, formatted)
    error_show(STDOUT, e)
    println(io)
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
    bold(string(suite.desc != nothing ? "$(suite.desc) ($(suite.file))" : suite.file, "\n"))
end

# DeFacto core functions and macros
# =================================

# The last handler function found in `handlers` will be passed test results.
# This means the default handler set up by DeFacto could be overridden with
# `push!(DeFacto.handlers, my_custom_handler)`.
#
const handlers = Function[]

# `do_fact` constructs a Success, Failure, or Error depending on the outcome
# of a test and passes it off to the active test handler (`DeFacto.handlers[end]`).
#
# `thunk` should be a parameterless boolean function representing a test.
# `factex` should be the Expr from which `thunk` was constructed.
# `meta` should contain meta information about the test.
#
function do_fact(thunk::Function, factex::Expr, meta::Dict)
    result = try
        thunk() ? Success(factex, meta) : Failure(factex, meta)
    catch err
        Error(factex, err, catch_backtrace(), meta)
    end

    !isempty(handlers) && handlers[end](result)
end

# Constructs a boolean expression from a given expression `ex` that, when
# evaluated, returns true if `ex` throws an error and false if `ex` does not.
#
throws_pred(ex) = :(try $(esc(ex)); false catch e true end)

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
            isa(e, Function) ? e(t) : e == t
        end
        pred($(esc(ex)))
    end
end

# Turns a fact expression (e.g. `:(1 => 1)`) into a `do_fact` call. For
# instance:
#
#     rewrite_assertion(:(1 => 1), {"line" => line_ann})
#     # => :(do_fact( () -> 1 == 1, :(1 => 1), {"line" => line_ann} )
#
function rewrite_assertion(factex::Expr, meta::Dict)
    ex, assertion = factex.args
    test = assertion == :(:throws) ? throws_pred(ex) : fact_pred(ex, assertion)
    :(do_fact(()->$test, $(Expr(:quote, factex)), $meta))
end

# `process_fact` gets all of the arguments given to `@fact`, and is responsible
# for the bulk of the work.
#
# Two expression types are supported:
#
#     @fact 1 => 1
#     @fact begin
#         1 => 1
#         2 => 2
#     end
#
# In the first case, the expression is passed to `rewrite_assertion` directly.
# In the second case, a new block is constructed with every nested assertion
# rewritten. For instance:
#
#      @fact begin
#          x = 1
#          x => 1
#          y = 2
#          y => 2
#      end
#
#      # becomes roughly
#
#      begin
#          x = 1
#          do_fact( () -> x == 1, :(x => 1), ...)
#          y = 2
#          do_fact( () -> y == 2, :(y => 2), ...)
#      end
#
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

# `do_facts` creates test scope. It gets all of the arguments from `@facts`
# and is responsible for setting up a testing environment, which means
# constructing a TestSuite, generating and registering test handlers, and
# reporting results.
#
# The `facts_block` is expected to be an `Expr(:block)` containing many
# invocations of `@fact`.
#
function do_facts(desc::Union(String, Nothing), facts_block::Expr)
    facts_block.head == :block || error("@facts must be passed a `begin ... end` block, given: $facts_block")

    file_name = split(string(facts_block.args[1].args[2]), "/")[end]

    suite = TestSuite(file_name, desc)
    test_handler = make_handler(suite)
    push!(handlers, test_handler)

    quote
        println()
        println(format_suite($suite))
        $(esc(facts_block))
        println($suite)
    end
end
do_facts(facts_block::Expr) = do_facts(nothing, facts_block)

# Top-level macros, pass all arguments to helper functions for implementation
# flexibility. See `do_facts` and `process_fact`.
macro facts(args...)
    do_facts(args...)
end
macro fact(args...)
    process_fact(args...)
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
roughly(n::Number, range::Number) = (i) -> (n-range) <= i <= (n+range)
roughly(n::Number) = roughly(n, n/1000)

end # module DeFacto
