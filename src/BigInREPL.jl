module BigInREPL

using REPL

function swapint(@nospecialize(bigger))
    function swapintex(@nospecialize(ex))
        if ex isa Expr
            h = ex.head
            # copied from REPL.softscope
            if h in (:meta, :import, :using, :export, :module, :error, :incomplete, :thunk)
                ex
            else
                ex′ = Expr(h)
                map!(swapintex, resize!(ex′.args, length(ex.args)), ex.args)
                ex′
            end
        elseif ex isa Int
            :($bigger($ex))
        else
            ex
        end
    end
end

get_transforms() =
    transforms = if isdefined(Base, :active_repl_backend) &&
                         isdefined(Base.active_repl_backend, :ast_transforms)
                     Base.active_repl_backend.ast_transforms
                 elseif isdefined(REPL, :repl_ast_transforms)
                     REPL.repl_ast_transforms
                 else
                     nothing
                 end

function __init__()
    transforms = get_transforms()
    if transforms !== nothing
        push!(transforms, swapint(big))
    else
        @warn "$(@__MODULE__) could not be loaded"
    end
end

function setdefaultint(@nospecialize(T))
    transforms = get_transforms()
    filter!(f -> parentmodule(f) != @__MODULE__, transforms)
    if transforms === nothing
        @warn "$(@__MODULE__) could not be loaded"
    else
        push!(transforms, swapint(T))
    end
end

end # module
