module SafeREPL

using REPL

function __init__()
    activate = get(ENV, "SAFEREPL_INIT", "true")
    if activate == "true"
        swapliterals!(firsttime = true)
    end
end

const FLOATS_USE_RATIONALIZE = Ref(false)

"""
    floats_use_rationalize!(yesno::Bool=true)

If `true`, a `Float64` input is first converted to `Rational{Int}`
via `rationalize` before being further transformed.
"""
floats_use_rationalize!(yesno::Bool=true) = FLOATS_USE_RATIONALIZE[] = yesno


const SmallArgs = Union{Nothing,Symbol}
const BigArgs = Union{Nothing,String,Symbol}

function literalswapper(Float64, Int, Int128, BigInt=nothing)
    @nospecialize
    literalswapper(; Float64, Int, Int128, BigInt)
end

function literalswapper(; swaps...)
    @nospecialize

    function swapper(@nospecialize(ex::Union{Float64,Int,String,Char,
                                             Base.BitUnsigned64}), quoted=false)
        ts = ex isa Int ? :Int : Symbol(typeof(ex))
        swap = get(swaps, ts, nothing)
        if ex isa UInt && swap === nothing
            swap = get(swaps, :UInt, nothing)
        end

        if quoted || swap === nothing
            ex
        elseif ex isa Union{Float64,String} && swap isa String
            Expr(:macrocall, Symbol(swap), nothing, string(ex))
        elseif ex isa Float64 && FLOATS_USE_RATIONALIZE[]
            if swap == :big # big(1//2) doesn't return BigFloat
                swap = :BigFloat
            end
            :($swap(rationalize($ex)))
        else
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

function get_transforms()
    if isdefined(Base, :active_repl_backend) &&
        isdefined(Base.active_repl_backend, :ast_transforms)
        Base.active_repl_backend.ast_transforms::Vector{Any}
    elseif isdefined(REPL, :repl_ast_transforms)
        REPL.repl_ast_transforms::Vector{Any}
    else
        nothing
    end
end

"""
    SafeREPL.swapliterals!(Float64, Int, Int128, BigInt=nothing)

Specify transformations for literals:
argument `Float64` corresponds to literals of type `Float64`, etcetera.

A transformation can be
* a `Symbol`, to refer to a function, e.g. `:big`;
* `nothing` to not transform literals of this type;
* a `String` specifying the name of a string macro, e.g. `"@big_str"`,
  which will be applied to the input. Available only for
  `Int128` and `BigInt`, and experimentally for `Float64`.
"""
function swapliterals!(Float64::BigArgs,
                       Int::SmallArgs,
                       Int128::BigArgs,
                       BigInt::BigArgs=nothing)
    @nospecialize
    swapliterals!(; Float64, Int, Int128, BigInt)
end

const defaultswaps = (Float64   = "@big_str",
                      Int       = :big,
                      Int128    = :big)

function swapliterals!(; firsttime=false, swaps...)
    @nospecialize
    if isempty(swaps) # equivalent to swapliterals!(true)
        swaps = defaultswaps
    end
    # firsttime: when loading, avoiding filtering shaves off few tens of ms
    firsttime || swapliterals!(false) # remove previous settings
    transforms = get_transforms()
    if transforms === nothing
        @warn "$(@__MODULE__) could not be loaded"
    else
        push!(transforms, literalswapper(; swaps...))
    end
    nothing
end

function swapliterals!(swap::Bool)
    if swap
        swapliterals!()
    else # deactivate
        filter!(f -> parentmodule(f) != @__MODULE__, get_transforms())
    end
    nothing
end

isactive() = any(==(@__MODULE__) ∘ parentmodule, get_transforms())


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

        all(sw -> Meta.isexpr(sw, :(=), 2), swaps) ||
            throw(ArgumentError("invalid keyword argument"))

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
