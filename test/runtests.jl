using Test

using BigInREPL: makebig

@testset "makebig" begin
    @test makebig(1) == :(big(1))
    for T in Base.BitUnsigned_types
        @test typeof(makebig(T(1))) == T
    end
end
