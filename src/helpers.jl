############################################################
# FactCheck.jl
# A testing framework for Julia
# MIT Licensed
############################################################
# Assertion helpers
# - not
# - anything
# - truthy, falsey/falsy
# - exactly
# - roughly
############################################################

# not: logical not for values and functions
not(x) = isa(x, Function) ? (y) -> !x(y) :
                            (y) -> x != y

# anything: anything but nothing
anything(x) = (x != nothing)

# truthy: not `nothing`, false (== 0)
# falsy/falsey: not truthy
truthy(x) = (x != nothing) && (x != false)
falsey(x) = not(truthy(x))
falsy = falsey

# exactly: tests object/function equality (i.e. ===)
exactly(x) = (y) -> is(x, y)

# approx/roughly: Comparing numbers approximately
roughly(x::Number; kvtols...) = (y::Number) -> isapprox(y, x; kvtols...)

roughly(A::AbstractArray; kvtols...) = (B::AbstractArray) -> begin
    size(A) != size(B) && return false
    for i in 1:length(A)
        if !isapprox(A[i], B[i]; kvtols...)
            return false
        end
    end
    return true
end