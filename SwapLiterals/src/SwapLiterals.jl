module SwapLiterals

export @swapliterals


const FLOATS_USE_RATIONALIZE = Ref(false)

const defaultswaps = (Float64   = "@big_str",
                      Int       = :big,
                      Int128    = :big)

"""
    floats_use_rationalize!(yesno::Bool=true)

If `true`, a `Float64` input is first converted to `Rational{Int}`
via `rationalize` before being further transformed.
"""
floats_use_rationalize!(yesno::Bool=true) = FLOATS_USE_RATIONALIZE[] = yesno

function literalswapper(Float64, Int, Int128, BigInt=nothing)
    @nospecialize
    literalswapper(; Float64, Int, Int128, BigInt)
end

function literalswapper(; swaps...)
    @nospecialize

    all(kv -> kv[2] isa Union{String,Symbol,Nothing}, swaps) ||
        throw(ArgumentError("unsupported type for swapper"))

    foreach(swaps) do kv
        eval(kv[1]) ∈ [Float32,Float64,Int,String,Char,
                       Base.BitUnsigned64_types...,Int128,UInt128,BigInt] ||
                           throw(ArgumentError("type $(kv[1]) cannot be replaced"))
    end

    function swapper(@nospecialize(ex::Union{Float32,Float64,Int,String,Char,
                                             Base.BitUnsigned64}), quoted=false)
        ts = Symbol(typeof(ex))
        swap = get(swaps, ts, nothing)

        if ex isa UInt && swap === nothing
            swap = get(swaps, :UInt, nothing)
        elseif ex isa Int && swap === nothing
            swap = get(swaps, :Int, nothing)
        end

        if quoted || swap === nothing
            ex
        elseif swap isa String
            Expr(:macrocall, Symbol(swap), nothing, string(ex))
        elseif ex isa AbstractFloat && FLOATS_USE_RATIONALIZE[]
            if swap == :big # big(1//2) doesn't return BigFloat
                swap = :BigFloat
            end
            :($swap(rationalize($ex)))
        else # ex isa Symbol
            :($swap($ex))
        end
    end

    function swapper(@nospecialize(ex), quoted=false)
        if ex isa Expr && ex.head == :macrocall &&
            ex.args[1] isa GlobalRef &&
            ex.args[1].name ∈ (Symbol("@int128_str"),
                               Symbol("@uint128_str"),
                               Symbol("@big_str"))

            swap = get(swaps,
                       ex.args[1].name == Symbol("@big_str") ? :BigInt :
                       ex.args[1].name == Symbol("@int128_str") ? :Int128 : :UInt128,
                       nothing)

            if quoted || swap === nothing
                ex
            else
                if swap == :big
                    swap = "@big_str"
                end
                if swap isa String
                    ex.args[1] = Symbol(swap)
                    ex
                else # Symbol
                    :($swap($ex))
                end
            end
        else
            ex =
                if ex isa Expr
                    h = ex.head
                    # copied from REPL.softscope
                    if h in (:meta, :import, :using, :export, :module, :error, :incomplete, :thunk)
                        ex
                    elseif Meta.isexpr(ex, :$, 1)
                        swapper(ex.args[1], true)
                    else
                        ex′ = Expr(h)
                        map!(swapper, resize!(ex′.args, length(ex.args)), ex.args)
                        ex′
                    end
                else
                    ex
                end
            if quoted
                Expr(:$, ex)
            else
                ex
            end
        end
    end
end


## macro

transform_arg(@nospecialize(x)) =
    if x isa QuoteNode
        x.value
    elseif x == :nothing
        nothing
    elseif x isa String
        x
    else
        throw(ArgumentError("invalid argument"))
    end

macro swapliterals(swaps...)

    length(swaps) == 1 &&
        return literalswapper(; defaultswaps...)(esc(swaps[1]))

    # either there are keyword arguments (handled first),
    # or positional arguments (handled second), but not both

    if swaps[1] isa Expr
        ex = esc(swaps[end])
        swaps = swaps[1:end-1]

        if Meta.isexpr(swaps[1], :call, 3)
            # convert `=>` expressions to `=` expressions
            swaps = map(swaps) do sw
                Meta.isexpr(sw, :call, 3) && sw.args[1] == :(=>) ||
                    throw(ArgumentError("invalid pair argument"))
                Expr(:(=), sw.args[2], sw.args[3])
            end
        else
            all(sw -> Meta.isexpr(sw, :(=), 2), swaps) ||
                throw(ArgumentError("invalid keyword argument"))
        end

        # keys are wrapped inside Expr, so get them out as
        # NamedTuple keys
        swaps = NamedTuple{Tuple(sw.args[1] for sw in swaps)}(
                           Tuple(sw.args[2] for sw in swaps))
    else
        for a in swaps[1:end-1]
            a isa Union{QuoteNode,String} || a == :nothing ||
                throw(ArgumentError("invalid argument: $a"))
        end

        ex = esc(swaps[end])

        if length(swaps) == 4
            swaps = (Float64=swaps[1], Int=swaps[2], Int128=swaps[3])
        elseif length(swaps) == 5
            swaps = (Float64=swaps[1], Int=swaps[2], Int128=swaps[3], BigInt=swaps[4])
        else
            throw(ArgumentError("wrong number of arguments"))
        end
    end

    swaps = map(transform_arg, swaps)
    literalswapper(; swaps...)(ex)
end


end # module
