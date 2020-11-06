module SwapLiterals

@static if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@optlevel"))
   Base.Experimental.@optlevel 0
end

export @swapliterals


const FLOATS_USE_RATIONALIZE = Ref(false)

makedict(@nospecialize(pairs)) =
    foldl(Base.ImmutableDict, pairs; init=Base.ImmutableDict{Any,Any}())

makedict(@nospecialize(pairs::AbstractDict)) = pairs

const defaultswaps =
    let swaps = Any[Float64 => "@big_str",
                    Int     => :big,
                    Int128  => :big]

        if Int === Int32
            push!(swaps, Int64 => :big)
        end
        makedict(swaps)
    end

"""
    floats_use_rationalize!(yesno::Bool=true)

If `true`, a `Float64` input is first converted to `Rational{Int}`
via `rationalize` before being further transformed.
"""
floats_use_rationalize!(yesno::Bool=true) = FLOATS_USE_RATIONALIZE[] = yesno

# swaps is a collection of pairs
function literals_swapper(swaps)
    @nospecialize

    swaps = makedict(swaps)

    # Base.Callable might be overly restrictive for callables, this check should
    # probably be removed eventually
    all(kv -> kv[2] isa Union{String,Symbol,Nothing,Base.Callable}, swaps) ||
        throw(ArgumentError("unsupported type for swapper"))

    foreach(swaps) do kv
        kv[1] ∈ Any[Float32,Float64,Int32,Int64,String,Char,
                    Base.BitUnsigned64_types...,Int128,UInt128,BigInt,
                    :braces, :tuple, :vect, :(:=)] ||
                        throw(ArgumentError("type $(kv[1]) cannot be replaced"))
    end

    function swapper(@nospecialize(ex::Union{Float32,Float64,Int32,Int64,String,Char,
                                             Base.BitUnsigned64}), quoted=false)

        swap = get(swaps, typeof(ex), nothing)

        if swap === nothing
            requote(ex, quoted)
        elseif quoted
            ex
        elseif swap isa String
            Expr(:macrocall, Symbol(swap), nothing, string(ex))
        elseif ex isa AbstractFloat && FLOATS_USE_RATIONALIZE[]
            if swap == :big # big(1//2) doesn't return BigFloat
                swap = :BigFloat
            end
            :($swap(rationalize($ex)))
        elseif swap isa Symbol
            :($swap($ex))
        else
            swap(ex)
        end
    end

    function swapper(@nospecialize(ex::Expr), quoted=false)
        h = ex.head
        if h == :macrocall &&
            ex.args[1] isa GlobalRef &&
            ex.args[1].name ∈ (Symbol("@int128_str"),
                               Symbol("@uint128_str"),
                               Symbol("@big_str"))

            swap = get(swaps,
                       ex.args[1].name == Symbol("@big_str") ? BigInt :
                       ex.args[1].name == Symbol("@int128_str") ? Int128 : UInt128,
                       nothing)

            if swap === nothing
                requote(ex, quoted)
            elseif quoted
                ex
            else
                if swap == :big
                    swap = "@big_str"
                end
                if swap isa String
                    ex.args[1] = Symbol(swap)
                    ex
                elseif swap isa Symbol
                    :($swap($ex))
                else
                    swap(ex)
                end
            end
        elseif h ∈ (:braces, :tuple, :vect, :(:=))
            ex = recswap(ex)
            swap = get(swaps, h, nothing)
            if swap === nothing
                requote(ex, quoted)
            elseif quoted
                ex
            elseif swap isa Symbol
                :($swap($ex))
            else
                swap(ex)
            end
        else
            ex = recswap(ex)
            if quoted
                Expr(:$, ex)
            else
                ex
            end
        end
    end

    function recswap(@nospecialize(ex))
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
    end

    requote(@nospecialize(ex), quoted) = quoted ? Expr(:$, ex) : ex

    swapper(@nospecialize(ex), quoted=false) = requote(ex, quoted)

    swapper
end

# to save time loading SafeREPL
const default_literals_swapper = literals_swapper(defaultswaps)


## macro

transform_arg(mod, @nospecialize(x)) =
    if x isa QuoteNode
        x.value
    elseif x == :nothing
        nothing
    elseif x isa String
        x
    elseif x isa Symbol
        getfield(mod, x)
    elseif x isa Expr
        swap = mod.eval(x)
        ex -> Base.invokelatest(swap, ex)
    else
        throw(ArgumentError("invalid swapper type: $(typeof(x))"))
    end

macro swapliterals(swaps...)

    length(swaps) == 1 &&
        return literals_swapper(defaultswaps)(esc(swaps[1]))

    if length(swaps) == 2 && swaps[1] isa Expr && swaps[1].head == :vect
        swaps = Any[swaps[1].args..., swaps[2]]
    end

    # either there are pairs/keyword arguments (handled first),
    # or positional arguments (handled second), but not both

    if swaps[1] isa Expr
        ex = esc(swaps[end])
        swaps = swaps[1:end-1]

        transform_src(x::Symbol) = getfield(Base, x)
        transform_src(x::QuoteNode) = x.value # for `:braces`, etc.

        if Meta.isexpr(swaps[1], :call, 3) # pairs
            swaps = map(swaps) do sw
                Meta.isexpr(sw, :call, 3) && sw.args[1] == :(=>) ||
                    throw(ArgumentError("invalid pair argument"))
                transform_src(sw.args[2]) => sw.args[3]
            end
        else
            swaps = map(swaps) do sw # keyword arguments
                Meta.isexpr(sw, :(=), 2) ||
                    throw(ArgumentError("invalid keyword argument"))
                transform_src(sw.args[1]) => sw.args[2]
            end
        end
    else
        for a in swaps[1:end-1]
            a isa Union{QuoteNode,String} || a == :nothing ||
                throw(ArgumentError("invalid argument: $a"))
        end

        ex = esc(swaps[end])

        if length(swaps) == 4
            swaps = Any[Float64=>swaps[1], Int=>swaps[2], Int128=>swaps[3]]
        elseif length(swaps) == 5
            swaps = Any[Float64=>swaps[1], Int=>swaps[2], Int128=>swaps[3], BigInt=>swaps[4]]
        else
            throw(ArgumentError("wrong number of arguments"))
        end
        if Int !== Int64
            # transform Int64 in the same way we transform Int == Int32
            push!(swaps, Int64 => last(swaps[2]))
        end
    end

    swaps = Any[k => transform_arg(__module__, v) for (k, v) in swaps]
    literals_swapper(swaps)(ex)
end


end # module
