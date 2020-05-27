## SafeREPL

[![Build Status](https://travis-ci.org/rfourquet/SafeREPL.jl.svg?branch=master)](https://travis-ci.org/rfourquet/SafeREPL.jl)

The `SafeREPL` package allows to swap the meaning of default float and
integer literals (for `Int`, `Int128` and `BigInt`).
By default, the new defaults are `BigFloat` and `BigInt`.

```julia
julia> using SafeREPL

julia> 2^200
1606938044258990275541962092341162602522202993782792835301376

julia> sqrt(2.0)
1.414213562373095048801688724209698078569671875376948073176679737990732478462102
```

These can be changed via `SafeREPL.swapliterals!`. The four arguments of this
function correspond to `Float64`, `Int`, `Int128`, `BigInt`. Passing `nothing`
means not transforming them, and a symbol is interpreted as a function name
to be applied to the value. The last argument defaults to `nothing`.
Finally, `swapliterals!(false)` deactivates `SafeREPL` and `swapliterals!(true)`
or `swapliterals!()` activates the defaults (what is enabled with `using SafeREPL`,
which is equivalent to `swapliterals(:big, :big, :big)`).


### Examples

```julia
julia> using BitIntegers, BitFloats

julia> SafeREPL.swapliterals!(:Float128, :Int256, :Int256);

julia> log2(factorial(60))
254.8391546883338

julia> sqrt(2.0)
1.41421356237309504880168872420969798

julia> using SaferIntegers, DoubleFloats

julia> SafeREPL.swapliterals!(:DoubleFloat, :SafeInt, :SafeInt128);

julia> typeof(2.0)
Double64

julia> 2^64
ERROR: OverflowError: 2^64
Stacktrace:
[...]

julia> 10000000000000000000^3
ERROR: OverflowError: 10000000000000000000 * 100000000000000000000000000000000000000 overflowed for type Int128
Stacktrace:
[...]

julia> using Nemo; SafeREPL.swapliterals!(nothing, :fmpz, :fmpz, :fmpz);

julia> factorial(100)
93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000

julia> typeof(ans)
fmpz

julia> SafeREPL.swapliterals!(false)

julia> typeof(1), typeof(1.0)
(Int64, Float64)

julia> SafeREPL.swapliterals!(true)

julia> typeof(1), typeof(1.0)
(BigInt, BigFloat)
```


### String macros

For `Int128` and `BigInt`, it's possible to pass the name of a string macro (as a `String`) instead
of a symbol. In this case, the macro is used to directly interpret the number. For example:

```julia
julia> SafeREPL.swapliterals!(nothing, nothing, "@int1024_str", "@int1024_str");

julia> typeof(111111111111111111111111111111111)
Int1024

julia> 1234...(many digits).....789 # of course very big numbers can't be input anymore!
ERROR: LoadError: OverflowError: overflow parsing "1234..."
[...]
```

As an experimental feature, when a string macro is passed to interpret `Float64`,
the input is then first converted to a `String` which is passed to the macro:

```julia
julia> SafeREPL.swapliterals!("@big_str", nothing, nothing)

julia> 1.2
1.200000000000000000000000000000000000000000000000000000000000000000000000000007

julia> 1.2 == big"1.2"
true

julia> 1.1999999999999999 == big"1.1999999999999999"
false
```


### How to use in source code?

Via the `@swapliterals` macro, with the same arguments as the `swapliterals!` function:
```julia
using SafeREPL: @swapliterals

x = @swapliterals :big :big :big begin
    1.0, 2^123
end
typeof(x) # Tuple{BigFloat,BigInt}
x = @swapliterals (1.0, 2^123) # shorter version, uses :big as defaults
```
Note: if you try the above at the REPL, `typeof(x)` will be `Tuple{BigFloat,BigInt}`.
Try first `SafeREPL.swapliterals!(false)` to deactivate `SafeREPL`.

_Warning_: this is alpha software and it's not recommended to use this macro in production.


### Installation

This package requires Julia version at least 1.5. It is not yet registered,
install it via:
```
using Pkg; pkg"add https://github.com/rfourquet/SafeREPL.jl"
```


### Visual indicator that SafeREPL is active

The following can be put in the "startup.jl" file to modify the color of the prompt,
or to modify the text in the prompt. Tweak as necessary.

```julia
using REPL

atreplinit() do repl
    repl.interface = REPL.setup_interface(repl)
    julia_mode = repl.interface.modes[1]

    old_prefix = julia_mode.prompt_prefix
    julia_mode.prompt_prefix = function()
        if isdefined(Main, :SafeREPL) && SafeREPL.isactive()
            Base.text_colors[:yellow]
        else
            old_prefix
        end
    end

    old_prompt = julia_mode.prompt
    julia_mode.prompt = function()
        if isdefined(Main, :SafeREPL) && SafeREPL.isactive()
            "safejulia> " # ;-)
        else
            old_prompt
        end
    end
end
```


### Caveats

* This package was not tested on 32-bits architectures, help will be needed to support them.

* Using new number types by default in the REPL might reveal many missing methods
  for these types and render the REPL less usable than ideal.
  Time for opening ticket/issues in the corresponding projects :)

* float literals are stored as `Float64` in the Julia AST, meaning that information can be lost:

```julia
julia> using SafeREPL; 1.2 # this is equivalent to `big(1.2)`
1.1999999999999999555910790149937383830547332763671875

julia> big"1.2"
1.200000000000000000000000000000000000000000000000000000000000000000000000000007
```

As said earlier, one can pass `"@big_str"` for the `Float64` converter to try
to mitigate this problem. Another alternative (which does _not_ always produce
the same results as with `"@big_str"`) is to call `rationalize` before
converting to a float.
There is an experimental option to have `SafeREPL` implicitly insert
calls to `rationalize`, which is enabled by calling
`floats_use_rationalize!(true)`:

```julia
julia> bigfloat(x) = BigFloat(rationalize(x));

julia> SafeREPL.swapliterals!(:bigfloat, nothing, nothing)

julia> 1.2
1.200000000000000000000000000000000000000000000000000000000000000000000000000007

julia> SafeREPL.swapliterals!(); SafeREPL.floats_use_rationalize!(true); 1.2
1.200000000000000000000000000000000000000000000000000000000000000000000000000007

julia> 1.20000000000001
1.200000000000010169642905566151645987816694259698096594761182517957654980952429

julia> SafeREPL.swapliterals!("@big_str", nothing, nothing) # rationalize not used

julia> 1.20000000000001
1.200000000000010000000000000000000000000000000000000000000000000000000000000006
```

Note that `bigfloat` could not be defined on the fly like in
`swapliterals!(x -> BigFloat(rationalize(x)), nothing, nothing)`,
because `swapliterals!` requires symbol names. Passing a function
is currently reserved for possible future features.


### Alternatives

Before Julia 1.5, the easiest alternative was probably to use a custom REPL mode,
and [ReplMaker.jl](https://github.com/MasonProtter/ReplMaker.jl#example-3-big-mode)
even has an example to set this up in few lines.

At least a couple of related projects have a macro similar to `@swapliterals`:
* [ChangePrecision.jl](https://github.com/stevengj/ChangePrecision.jl),
  with the `@changeprecision` macro which reinterprets floating-point literals
  but also some floats-producing functions like `rand()`.
* [SaferIntegers.jl](https://github.com/JeffreySarnoff/SaferIntegers.jl),
  with the `@saferintegers` macro which wraps integers using `SaferIntegers`
  types.
