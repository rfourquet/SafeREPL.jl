module BigInREPL

using REPL

function makebig(@nospecialize ex)
    if ex isa Expr
        h = ex.head
        # copied from REPL.softscope
        if h in (:meta, :import, :using, :export, :module, :error, :incomplete, :thunk)
            ex
        else
            ex′ = Expr(h)
            map!(makebig, resize!(ex′.args, length(ex.args)), ex.args)
            ex′
        end
    elseif ex isa Int
        :(big($ex))
    else
        ex
    end
end

function __init__()
    transforms = if isdefined(Base, :active_repl_backend) &&
                         isdefined(Base.active_repl_backend, :ast_transforms)
                     Base.active_repl_backend.ast_transforms
                 elseif isdefined(REPL, :repl_ast_transforms)
                     REPL.repl_ast_transforms
                 else
                     nothing
                 end
    if transforms !== nothing
        push!(transforms, makebig)
    end
end

end # module
