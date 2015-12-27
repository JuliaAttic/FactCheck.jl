############################################################
# FactCheck.jl
# A testing framework for Julia
# http://github.com/JuliaLang/FactCheck.jl
# MIT Licensed
############################################################
# Test execution
# - runalltests
############################################################

function runalltests(basepath::AbstractString = pwd())
    callingfile = Base.source_path()

    function impl(subdir::AbstractString)
        fullpath = joinpath(basepath, subdir)

        tests = Array(typeof(fullpath), 0)
        dirs = Array(typeof(fullpath), 0)
        for f in readdir(fullpath)
            fname = joinpath(fullpath, f)
            if isdir(fname)
                push!(dirs, f)
            elseif isfile(fname) && endswith(fname, ".jl")
                # Make double sure to exclude calling file to avoid endless
                # recursion:
                if (
                    ( fname != callingfile ) &&
                    ( subdir != "" || f != basename(callingfile) )
                )
                    push!(tests, f)
                end
            end
        end

        for d in dirs
            impl(joinpath(subdir, d))
        end

        for t in tests
            Base.info("Running tests in \"$(joinpath(subdir, t))\"")

            srand(345678)
            include(joinpath(basepath, subdir, t))
        end
    end

    impl("")

    # Program exit code in accordance with testing result:
    FactCheck.exitstatus()
end
