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

### How to use in source code?

Via the `@swapliterals` macro, with the same arguments as the `swapliterals!` function:
```julia
using SafeREPL: @swapliterals

x = @swapliterals :big :big :big begin
    1.0, 2^123
end
typeof(x) # Tuple{BigFloat,BigInt}
```
Note: if you try the above at the REPL, `typeof(x)` will be `Tuple{BigFloat,BigInt}`.
Try first `SafeREPL.swapliterals!(nothing, nothing, nothing)` to deactivate `SafeREPL`.

_Warning_: this is alpha software and it's not recommended to use this macro in production.


### Installation

This package requires Julia version at least 1.5. It is not yet registered,
install it via:
```
using Pkg; pkg"add https://github.com/rfourquet/SafeREPL.jl"
```

### Caveats

* This package was not tested on 32-bits architectures, help will be needed to support them.
* float literals are stored as `Float64` in the AST, meaning that information can be lost:

```julia
julia> using SafeREPL; 1.2 # this is equivalent to `big(1.2)`
1.1999999999999999555910790149937383830547332763671875

julia> big"1.2"
1.200000000000000000000000000000000000000000000000000000000000000000000000000007
```
* Using different number types as default in the REPL might reveal many missing methods
  for these types and render the REPL less usable than ideal.
  Time for opening ticket/issues in the corresponding projects :)

### Alternatives

Before Julia 1.5, the easiest alternative was probably to use a custom REPL mode,
and [ReplMaker.jl](https://github.com/MasonProtter/ReplMaker.jl#example-3-big-mode)
even has an example to set this up in few lines.
