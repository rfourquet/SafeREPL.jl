using Test

using SafeREPL: literalswapper, @swapliterals
using BitIntegers, SaferIntegers

@testset "swapliterals" begin
    swapbig = literalswapper(:BigFloat, :big, "@big_str")
    @test swapbig(1) == :(big(1))
    @test swapbig(1.2) == :(BigFloat(1.2))

    @swapliterals :BigFloat :big "@big_str" begin
        @test 1 == Int(1)
        @test 1 isa BigInt
        @test 1.2 isa BigFloat
        @test 1.0 == Float64(1.0)
    end

    # TODO: these tests in loop are dubious
    for T in Base.BitUnsigned_types
        @test typeof(swapbig(T(1))) == T
    end
    for T in [Float32, Float16]
        @test typeof(swapbig(T(1))) == T
    end

    x = eval(swapbig(1.0))
    @test x isa BigFloat && x == 1.0
    x = eval(swapbig(1))
    @test x == 1 && x isa BigInt
    x = eval(swapbig(:11111111111111111111))
    @test x == 11111111111111111111 && x isa BigInt
    x = eval(swapbig(:1111111111111111111111111111111111111111))
    @test x isa BigInt

    @swapliterals :BigFloat :big "@big_str" begin
        x = 1.0
        @test x isa BigFloat && x == Float64(1.0)
        x = 1
        @test x == Int(1) && x isa BigInt
        x = 11111111111111111111
        @test x == big"11111111111111111111" && x isa BigInt
        x = 1111111111111111111111111111111111111111
        @test x isa BigInt
    end

    swap128 = literalswapper(:Float64, :Int128, "@int128_str")
    x = eval(swap128(1))
    @test x == 1 && x isa Int128
    x = eval(swap128(:11111111111111111111))
    @test x == 11111111111111111111 && x isa Int128
    x = eval(swap128(:1111111111111111111111111111111111111111))
    @test x isa BigInt

    @swapliterals :Float64 :Int128 "@int128_str" begin
        x = 1
        @test x == Int(1) && x isa Int128
        x = 11111111111111111111
        @test x == Int128(11111111111111111111) && x isa Int128
        x = 1111111111111111111111111111111111111111
        @test x isa BigInt
    end

    swapnothing = literalswapper(nothing, nothing, nothing)
    x = eval(swapnothing(1.0))
    @test x isa Float64
    x = eval(swapnothing(:11111111111111111111))
    @test x isa Int128
    x = eval(swapnothing(:1111111111111111111111111111111111111111))
    @test x isa BigInt

    @swapliterals nothing nothing nothing begin
        x = 1.0
        @test x isa Float64
        x = 11111111111111111111
        @test x isa Int128
        x = 1111111111111111111111111111111111111111
        @test x isa BigInt
    end

    # pass :big instead of a string macro
    swaponly128 = literalswapper(nothing, nothing, :big)
    x = eval(swaponly128(:11111111111111111111))
    @test x isa BigInt

    @swapliterals nothing nothing :big begin
        x = 11111111111111111111
        @test x isa BigInt
    end

    # pass symbol for Int128
    swapBitIntegers = literalswapper(nothing, :Int256, :Int256)
    x = eval(swapBitIntegers(123))
    @test x isa Int256
    x = eval(swapBitIntegers(:11111111111111111111))
    @test x isa Int256

    swapSaferIntegers = literalswapper(nothing, :SafeInt, :SafeInt128)
    x = eval(swapSaferIntegers(123))
    @test x isa SafeInt
    x = eval(swapSaferIntegers(:11111111111111111111))
    @test x isa SafeInt128

    @swapliterals nothing :Int256 :Int256 begin
        x = 123
        @test x isa Int256
        x = 11111111111111111111
        @test x isa Int256
    end

    @swapliterals nothing :SafeInt :SafeInt128 begin
        x = 123
        @test x isa SafeInt
        x = 11111111111111111111
        @test x isa SafeInt128
    end

    # pass symbol for BigInt
    swapbig = literalswapper(nothing, nothing, :Int1024, :Int1024)
    x = eval(swapbig(:11111111111111111111))
    @test x isa Int1024
    x = eval(swapbig(:1111111111111111111111111111111111111111))
    @test x isa Int1024

    @swapliterals nothing nothing :Int1024 :Int1024 begin
        x = 11111111111111111111
        @test x isa Int1024
        x = 1111111111111111111111111111111111111111
        @test x isa Int1024
    end

    swapbig = literalswapper(nothing, nothing, :big, :big)
    x = eval(swapbig(:11111111111111111111))
    @test x isa BigInt
    x = eval(swapbig(:1111111111111111111111111111111111111111))
    @test x isa BigInt

    @swapliterals nothing nothing :big :big begin
        x = 11111111111111111111
        @test x isa BigInt
        x = 1111111111111111111111111111111111111111
        @test x isa BigInt
    end
end
