module SafeREPL

using REPL

function __init__()
    activate = get(ENV, "SAFEREPL_INIT", "true")
    if activate == "true"
        swapliterals!(:big, :big, :big, nothing, firsttime=true)
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

function literalswapper(swapfloat::BigArgs,
                        swapint::SmallArgs,
                        swapint128::BigArgs,
                        swapbig::BigArgs=nothing;
                        swapstr::BigArgs=nothing)

    @nospecialize
    function swapper(@nospecialize(ex), quoted=false)
        if ex isa Float64
            if quoted || swapfloat === nothing
                ex
            elseif swapfloat isa String
                Expr(:macrocall, Symbol(swapfloat), nothing, string(ex))
            elseif FLOATS_USE_RATIONALIZE[]
                if swapfloat == :big # big(1//2) doesn't return BigFloat
                    swapfloat = :BigFloat
                end
                :($swapfloat(rationalize($ex)))
            else
                :($swapfloat($ex))
            end
        elseif ex isa Int
            if quoted || swapint === nothing
                ex
            else
                :($swapint($ex))
            end
        elseif ex isa Expr && ex.head == :macrocall &&
            ex.args[1] isa GlobalRef &&
            ex.args[1].name == Symbol("@int128_str")

            if quoted || swapint128 === nothing
                ex
            else
                if swapint128 == :big
                    swapint128 = "@big_str"
                end
                if swapint128 isa String
                    ex.args[1] = Symbol(swapint128)
                    ex
                else # Symbol
                    :($swapint128($ex))
                end
            end
        elseif ex isa Expr && ex.head == :macrocall &&
            ex.args[1] isa GlobalRef &&
            ex.args[1].name == Symbol("@big_str")

            if quoted || swapbig === nothing
                ex
            else
                if swapbig == :big
                    swapbig = "@big_str"
                end
                if swapbig isa String
                    ex.args[1] = Symbol(swapbig)
                    ex
                else # Symbol
                    :($swapbig($ex))
                end
            end
        elseif ex isa String
            if quoted || swapstr === nothing
                ex
            elseif swapstr isa String
                Expr(:macrocall, Symbol(swapstr), nothing, ex)
            else
                :($swapstr($ex))
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
    SafeREPL.swapliterals!(F, I, I128, B)

Specify transformations for literals: `F` for literals of type `Float64`,
`I` for `Int`, `I128` for `Int128` and `B` for `BigInt`.

A transformation can be
* a `Symbol`, to refer to a function, e.g. `:big`;
* `nothing` to not transform literals of this type;
* a `String` specifying the name of a string macro, e.g. `"@big_str"`,
  which will be applied to the input. Available only for
  `I128` and `B`, and experimentally for `F`.
"""
function swapliterals!(F::BigArgs,
                       I::SmallArgs,
                       I128::BigArgs,
                       B::BigArgs=nothing;
                       S::BigArgs=nothing,
                       firsttime::Bool=false)
    @nospecialize

    # firsttime: when loading, avoiding filtering shaves off few tens of ms
    firsttime || swapliterals!(false) # remove previous settings
    transforms = get_transforms()
    if transforms === nothing
        @warn "$(@__MODULE__) could not be loaded"
    else
        push!(transforms, literalswapper(F, I, I128, B, swapstr=S))
    end
    nothing
end

function swapliterals!(swap::Bool=true)
    if swap
        swapliterals!(:big, :big, :big)
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

function macro_swapliterals(F, I, I128, B, S, ex)
    F = transform_arg(F)
    I = transform_arg(I)
    I128 = transform_arg(I128)
    B = transform_arg(B)
    S = transform_arg(S)
    literalswapper(F, I, I128, B; swapstr=S)(ex)
end

macro swapliterals(args...)
    if length(args) == 1
        macro_swapliterals(:(:big), :(:big), :(:big), :nothing, :nothing, esc(args[1]))
    elseif length(args) == 4
        macro_swapliterals(args[1:3]..., :nothing, :nothing, esc(args[4]))
    elseif length(args) == 5
        macro_swapliterals(args[1:4]..., :nothing, esc(args[5]))
    elseif length(args) == 6
        macro_swapliterals(args[1:5]..., esc(args[6]))
    else
        throw(ArgumentError("wrong number of arguments"))
    end
end


end # module
