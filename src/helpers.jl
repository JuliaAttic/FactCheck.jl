############################################################
# FactCheck.jl
# A testing framework for Julia
# http://github.com/JuliaLang/FactCheck.jl
# MIT Licensed
############################################################
# Assertion helpers
# - not
# - exactly
# - roughly
# - anyof
# - less_than
# - less_than_or_equal
# - greater_than_or_equal
############################################################

# not: logical not for values and functions
not(x) = isa(x, Function) ? (y) -> !x(y) :
                            (y) -> x != y

# exactly: tests object/function equality (i.e. ===)
exactly(x) = (y) -> x === y

# approx/roughly: Comparing numbers approximately
roughly(x::Number, atol) = (y::Number) -> isapprox(y, x, atol=atol)
roughly(x::Number; kvtols...) = (y::Number) -> isapprox(y, x; kvtols...)

roughly(A::AbstractArray, atol) = (B::AbstractArray) -> begin
    size(A) != size(B) && return false
    return isapprox(A, B, atol=atol)
end
roughly(A::AbstractArray; kvtols...) = (B::AbstractArray) -> begin
    size(A) != size(B) && return false
    return isapprox(A, B; kvtols...)
end

# anyof: match any of the arguments
anyof(x...) = y -> any(arg->(isa(arg,Function) ? arg(y)::Bool : (y==arg)), x)

# less_than: Comparing two numbers
less_than(compared) = (compare) -> compare < compared

# less_than_or_equal: Comparing two numbers
less_than_or_equal(compared) = (compare) -> compare <= compared

# greater_than: Comparing two numbers
greater_than(compared) = (compare) -> compare > compared

# greater_than_or_equal: Comparing two numbers
greater_than_or_equal(compared) = (compare) -> compare >= compared
