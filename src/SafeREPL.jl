module SafeREPL

using REPL

function __init__()
    activate = get(ENV, "SAFEREPL_INIT", "true")
    if activate == "true"
        setdefaults(big, big)
    end
end


function swapliterals(@nospecialize(swapint), @nospecialize(swapfloat))
    function swapper(@nospecialize(ex))
        if ex isa Expr
            h = ex.head
            # copied from REPL.softscope
            if h in (:meta, :import, :using, :export, :module, :error, :incomplete, :thunk)
                ex
            else
                ex′ = Expr(h)
                map!(swapper, resize!(ex′.args, length(ex.args)), ex.args)
                ex′
            end
        elseif ex isa Int
            :($swapint($ex))
        elseif ex isa Float64
            :($swapfloat($ex))
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

function setdefaults(@nospecialize(I), @nospecialize(F))
    transforms = get_transforms()
    filter!(f -> parentmodule(f) != @__MODULE__, transforms)
    if transforms === nothing
        @warn "$(@__MODULE__) could not be loaded"
    else
        push!(transforms, swapliterals(I, F))
    end
end

end # module
