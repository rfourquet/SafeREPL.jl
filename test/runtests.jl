using Test

using BigInREPL: swapint

@testset "swapint" begin
    swapbig = swapint(big)
    @test swapbig(1) == :($big(1))
    for T in Base.BitUnsigned_types
        @test typeof(swapbig(T(1))) == T
    end
end
