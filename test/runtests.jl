using Test

using SafeREPL: swapliterals
using BitIntegers, SaferIntegers

@testset "swapliterals" begin
    swapbig = swapliterals(:BigFloat, :big, "@big_str")
    @test swapbig(1) == :(big(1))
    @test swapbig(1.2) == :(BigFloat(1.2))

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

    swap128 = swapliterals(Float64, :Int128, "@int128_str")
    x = eval(swap128(1))
    @test x == 1 && x isa Int128
    x = eval(swap128(:11111111111111111111))
    @test x == 11111111111111111111 && x isa Int128
    x = eval(swap128(1111111111111111111111111111111111111111))
    @test x isa BigInt

    swapnothing = swapliterals(nothing, nothing, nothing)
    x = eval(swapnothing(1.0))
    @test x isa Float64
    x = eval(swapnothing(:11111111111111111111))
    @test x isa Int128
    x = eval(swapnothing(:1111111111111111111111111111111111111111))
    @test x isa BigInt

    # pass :big instead of a string macro
    swaponly128 = swapliterals(nothing, nothing, :big)
    x = eval(swaponly128(:11111111111111111111))
    @test x isa BigInt

    # pass symbol for Int128
    swapBitIntegers = swapliterals(nothing, :Int256, :Int256)
    x = eval(swapBitIntegers(123))
    @test x isa Int256
    x = eval(swapBitIntegers(:11111111111111111111))
    @test x isa Int256
    swapSaferIntegers = swapliterals(nothing, :SafeInt, :SafeInt128)
    x = eval(swapSaferIntegers(123))
    @test x isa SafeInt
    x = eval(swapSaferIntegers(:11111111111111111111))
    @test x isa SafeInt128

    # pass symbol for BigInt
    swapbig = swapliterals(nothing, nothing, :Int1024, :Int1024)
    x = eval(swapbig(:11111111111111111111))
    @test x isa Int1024
    x = eval(swapbig(:1111111111111111111111111111111111111111))
    @test x isa Int1024
    swapbig = swapliterals(nothing, nothing, :big, :big)
    x = eval(swapbig(:11111111111111111111))
    @test x isa BigInt
    x = eval(swapbig(:1111111111111111111111111111111111111111))
    @test x isa BigInt
end
