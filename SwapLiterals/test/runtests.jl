using Test

using SwapLiterals
using SwapLiterals: floats_use_rationalize!

using BitIntegers, SaferIntegers

literalswapper(sw::Pair...) = SwapLiterals.literalswapper(sw)

literalswapper(F, I, I128, B=nothing) =
    literalswapper(Float64=>F, Int=>I, Int128=>I128, BigInt=>B)

makeset(ex) = Expr(:call, :Set, Expr(:vect, ex.args...))

@testset "swapliterals" begin
    swapbig = literalswapper(:BigFloat, :big, "@big_str")
    @test swapbig(1) == :(big(1))
    @test swapbig(1.2) == :(BigFloat(1.2))

    @swapliterals :BigFloat :big "@big_str" begin
        @test 1 == Int(1)
        @test 1 isa BigInt
        @test 1.2 isa BigFloat
        @test 1.2 == big"1.1999999999999999555910790149937383830547332763671875"
        @test 1.0 == Float64(1.0)
        @test $1 isa Int
        @test $1.2 isa Float64
    end

    # next three blocs should be equivalent
    @swapliterals begin
        @test 1.2 isa BigFloat
        @test 1.2 == big"1.2"
        @test 1 isa BigInt
        @test 11111111111111111111 isa BigInt
    end
    @swapliterals "@big_str" :big :big begin
        @test 1.2 isa BigFloat
        @test 1.2 == big"1.2"
        @test 1 isa BigInt
        @test 11111111111111111111 isa BigInt
    end
    @swapliterals Float64=>"@big_str" Int=>:big Int128=>:big begin
        @test 1.2 isa BigFloat
        @test 1.2 == big"1.2"
        @test 1 isa BigInt
        @test 11111111111111111111 isa BigInt
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

        @test $1.0 isa Float64
        @test $11111111111111111111 isa Int128
        @test $1111111111111111111111111111111111111111 isa BigInt
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
        @test 11111111111111111111 isa Int1024
        @test 1111111111111111111111111111111111111111 isa Int1024
        @test $11111111111111111111 isa Int128
        @test $1111111111111111111111111111111111111111 isa BigInt
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

    # kwargs
    kwswapper = literalswapper(Int=>:big)
    @test eval(kwswapper(1.2)) isa Float64
    @test eval(kwswapper(1)) isa BigInt
    @test eval(kwswapper(:11111111111111111111)) isa Int128
    @test eval(kwswapper(:1111111111111111111111111111111111111111)) isa BigInt

    # Float32
    @swapliterals Float32 => :big begin
        @test 1.2f0 == big"1.2000000476837158203125"
    end
    @swapliterals Float32 => "@big_str" begin
        @test 1.2f0 == big"1.2"
    end

    # string swappers
    @swapliterals Int => "@big_str" UInt8 => "@raw_str" begin
        @test 1 isa BigInt
        @test 0x01 === "1"
    end

    # Int & UInt
    @swapliterals Int => :UInt8 UInt => :Int8 begin
        @test 1 isa UInt8
        @test 0x0000000000000001 isa Int8
    end
    @swapliterals Int64=>:UInt8 UInt64=>:Int8 begin
        @test 1 isa UInt8
        @test 0x0000000000000001 isa Int8
    end

    # unsigned
    @swapliterals UInt8=>:Int UInt16=>:Int UInt32=>:Int UInt64=>:Int UInt128=>:Int128 begin
        @test 0x1 isa Int
        @test 0x0001 isa Int
        @test $0x0001 isa UInt16
        @test 0x00000001 isa Int
        @test $0x00000001 isa UInt32
        @test :0x00000001 isa UInt32
        @test 0x0000000000000001 isa Int
        @test :0x0000000000000001 isa UInt64
        @test 0x00000000000000000000000000000001 isa Int128
        @test $0x00000000000000000000000000000001 isa UInt128
    end
    @swapliterals UInt128=>"@int128_str" begin
        @test 0x00000000000000000000000000000001 isa Int128
        @test $0x00000000000000000000000000000001 isa UInt128
    end

    # strings & chars
    @swapliterals Char=>:string String => "@r_str" begin
        @test "123" isa Regex
        @test 'a' isa String
    end

    @swapliterals Char => :UInt String => :Symbol begin
        @test "123" isa Symbol
        @test 'a' === 0x0000000000000061
    end

    @test_throws ArgumentError literalswapper(Array=>:Int)

    # function swappers
    @swapliterals UInt8 => (x -> x+1) Int => UInt8 Int128 => (ex -> ex.args[3]) begin
        @test 0x01 == 2.0
        @test 1 isa UInt8
        @test 11111111111111111111 == "11111111111111111111"
    end

    # :braces, :tuple, :vect
    @swapliterals  :braces => makeset :tuple => makeset :vect => makeset begin
        r = push!(Set{Int}(), 1, 2, 3)
        s = {1, 2, 3}
        @test s isa Set{Int}
        @test s == r
        s = [1, 2, 3]
        @test s isa Set{Int}
        @test s == r
        s = (1, 2, 3)
        @test s isa Set{Int}
        @test s == r
    end
    @swapliterals :tuple => :collect begin
        v = (1, 2, 3)
        @test v isa Vector{Int}
        @test v == [1, 2, 3]
    end
end

# test name resolution for functions
module TestModule

using SwapLiterals, Test

uint8(x) = UInt8(x)

@swapliterals Int => uint8  Char => (x -> uint8(x)+1) begin
    @test 1 isa UInt8
    @test 'a' == 0x62
end
end

## playing with floats_use_rationalize!()

# can't be in a @testset apparently, probably because the parsing
# in @testset is done before floats_use_rationalize!() takes effect

@swapliterals Float32="@big_str" Float64="@big_str" begin
    @test 1.2 == big"1.2"
    @test 1.2f0 == big"1.2"
end

floats_use_rationalize!()
@swapliterals Float32="@big_str" Float64="@big_str" begin
    @test 1.2 == big"1.2"
    @test 1.2f0 == big"1.2"
end

# try again, with explicit `true` arg, and with :BigFloat instead of :big
floats_use_rationalize!(true)
@swapliterals Float32=:BigFloat Float64=:BigFloat begin
    @test 1.2 == big"1.2"
    @test 1.2f0 == big"1.2"
end

floats_use_rationalize!(false)
@swapliterals Float32=:BigFloat Float64=:BigFloat begin
    @test 1.2 == big"1.1999999999999999555910790149937383830547332763671875"
    @test 1.2f0 == big"1.2000000476837158203125"
end
