using Test

using SafeREPL: swapliterals

@testset "swapliterals" begin
    swapbig = swapliterals(BigFloat, big)
    @test swapbig(1) == :($big(1))
    @test swapbig(1.2) == :($BigFloat(1.2))
    for T in Base.BitUnsigned_types
        @test typeof(swapbig(T(1))) == T
    end
    for T in [Float32, Float16]
        @test typeof(swapbig(T(1))) == T
    end
end
