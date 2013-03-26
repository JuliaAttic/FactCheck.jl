using DeFacto

inc(x) = x + 1

@facts "Important fact examples" begin

    @fact 1 => 1

    @fact begin
        "foo" => "foo"
    end

    @fact "I can annotate things" begin
        1 => 1
    end

    @fact "strings are strings" begin
        "foo" => "foo"
        "bar" => "barr"
        "baz" => "bazz"
    end

    @fact "some numbers are even" begin
        2 => iseven
        3 => iseven
    end

    @fact begin
        x = 10
        inc(inc(inc(0))) => 2
    end

    @fact begin
        x = 5
        y = 10
        x => y
    end

    @fact begin
        error("neat") => :throws
    end

    @fact begin
        1 => not(2)
        2 => not(isodd)
    end
end
