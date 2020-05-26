using Test

using SafeREPL: swapliterals

@testset "swapliterals" begin
    swapbig = swapliterals(BigFloat, big, Symbol("@big_str"))
    @test swapbig(1) == :($big(1))
    @test swapbig(1.2) == :($BigFloat(1.2))

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

    swap128 = swapliterals(Float64, :Int128, Symbol("@int128_str"))
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
end
