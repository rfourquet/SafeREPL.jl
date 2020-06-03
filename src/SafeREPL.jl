module SafeREPL

export swapliterals!


using SwapLiterals: SwapLiterals, literalswapper, defaultswaps
using REPL


__init__() = swapliterals!(firsttime = true)

const LAST_SWAPPER = Ref{Function}()


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
function swapliterals!(Float64,
                       Int,
                       Int128,
                       BigInt=nothing)
    @nospecialize
    swapliterals!(; Float64, Int, Int128, BigInt)
end

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
        LAST_SWAPPER[] = literalswapper(; swaps...)
        push!(transforms, LAST_SWAPPER[])
    end
    nothing
end

function swapliterals!(swaps::Pair...)
    swapliterals!(; [Symbol(first(sw)) => last(sw) for sw in swaps]...)
end

function swapliterals!(activate::Bool)
    transforms = get_transforms()
    # first always de-activate
    filter!(f -> parentmodule(f) != SwapLiterals, transforms)
    if activate
        push!(transforms, LAST_SWAPPER[])
    end
    nothing
end

isactive() = any(==(SwapLiterals) ∘ parentmodule, get_transforms())


end # module
