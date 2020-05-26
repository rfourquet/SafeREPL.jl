module SafeREPL

using REPL

function __init__()
    activate = get(ENV, "SAFEREPL_INIT", "true")
    if activate == "true"
        setdefaults(big, big, "@big_str")
    end
end

const BigArgs = Union{Nothing,String,Symbol}

function swapliterals(@nospecialize(swapfloat), @nospecialize(swapint),
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
        Base.active_repl_backend.ast_transforms
    elseif isdefined(REPL, :repl_ast_transforms)
        REPL.repl_ast_transforms
    else
        nothing
    end
end

function setdefaults(@nospecialize(F), @nospecialize(I),
                     @nospecialize(I128)=nothing, @nospecialize(B)=nothing)
    transforms = get_transforms()
    filter!(f -> parentmodule(f) != @__MODULE__, transforms)
    if transforms === nothing
        @warn "$(@__MODULE__) could not be loaded"
    else
        push!(transforms, swapliterals(F, I, I128, B))
    end
    nothing
end

end # module
