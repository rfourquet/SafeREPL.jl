module SafeREPL

using REPL

function __init__()
    activate = get(ENV, "SAFEREPL_INIT", "true")
    if activate == "true"
        swapliterals!(:big, :big, :big, nothing, true)
    end
end

const SmallArgs = Union{Nothing,Symbol}
const BigArgs = Union{Nothing,String,Symbol}

function literalswapper(@nospecialize(swapfloat::SmallArgs),
                      @nospecialize(swapint::SmallArgs),
                      @nospecialize(swapint128::BigArgs),
                      @nospecialize(swapbig::BigArgs)=nothing)
    function swapper(@nospecialize(ex))
        if swapfloat !== nothing && ex isa Float64
            :($swapfloat($ex))
        elseif swapint !== nothing && ex isa Int
            :($swapint($ex))
        elseif swapint128 !== nothing && ex isa Expr &&
            ex.head == :macrocall && ex.args[1] isa GlobalRef &&
            ex.args[1].name == Symbol("@int128_str")

            if swapint128 == :big
                swapint128 = "@big_str"
            end
            if swapint128 isa String
                ex.args[1] = Symbol(swapint128)
                ex
            else # Symbol
                :($swapint128($ex))
            end
        elseif swapbig !== nothing && ex isa Expr &&
            ex.head == :macrocall && ex.args[1] isa GlobalRef &&
            ex.args[1].name == Symbol("@big_str")

            if swapbig == :big
                swapbig = "@big_str"
            end
            if swapbig isa String
                ex.args[1] = Symbol(swapbig)
                ex
            else # Symbol
                :($swapbig($ex))
            end
        elseif ex isa Expr
            h = ex.head
            # copied from REPL.softscope
            if h in (:meta, :import, :using, :export, :module, :error, :incomplete, :thunk)
                ex
            else
                ex′ = Expr(h)
                map!(swapper, resize!(ex′.args, length(ex.args)), ex.args)
                ex′
            end
        else
            ex
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

function swapliterals!(@nospecialize(F::SmallArgs),
                       @nospecialize(I::SmallArgs),
                       @nospecialize(I128::BigArgs),
                       @nospecialize(B::BigArgs)=nothing,
                       firsttime=false)
    # firsttime: when loading, avoiding filtering shaves off few tens of ms
    firsttime || swapliterals!(false) # remove previous settings
    transforms = get_transforms()
    if transforms === nothing
        @warn "$(@__MODULE__) could not be loaded"
    else
        push!(transforms, literalswapper(F, I, I128, B))
    end
    nothing
end

function swapliterals!(swap::Bool=true)
    transforms = get_transforms()
    if swap
        swapliterals!(:big, :big, :big)
    else # deactivate
        filter!(f -> parentmodule(f) != @__MODULE__, transforms)
    end
    nothing
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

function swapliterals_macro(F, I, I128, B, ex)
    F = transform_arg(F)
    I = transform_arg(I)
    I128 = transform_arg(I128)
    B = transform_arg(B)
    literalswapper(F, I, I128, B)(ex)
end

macro swapliterals(args...)
    if length(args) == 1
        swapliterals_macro(:(:big), :(:big), :(:big), :nothing, esc(args[1]))
    elseif length(args) == 4
        swapliterals_macro(args[1], args[2], args[3], :nothing, esc(args[4]))
    elseif length(args) == 5
        swapliterals_macro(args[1:4]..., esc(args[5]))
    else
        throw(ArgumentError("wrong number of arguments"))
    end
end


end # module
