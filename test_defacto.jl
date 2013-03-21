using DeFacto

facts() do
    @fact "foo" => "foo"

    @fact "I can annotate things" 1 => 1

    @fact "strings are strings" begin
        "foo" => "foo"
        "bar" => "barr"
        "baz" => "bazz"
    end

    @fact "some numbers are even" begin
        2 => iseven
        3 => iseven
    end
end
