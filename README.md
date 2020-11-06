[![Build Status](https://travis-ci.org/rfourquet/SafeREPL.jl.svg?branch=master)](https://travis-ci.org/rfourquet/SafeREPL.jl)


## SafeREPL

The `SafeREPL` package allows to swap, in the REPL, the meaning of Julia's
literals (in particular numbers).
Upon loading, the default is to replace `Float64` literals with `BigFloat`,
and `Int`, `Int64` and `Int128` literals with `BigInt`.
A literal prefixed with `$` is left unchanged.

```julia
julia> using SafeREPL

julia> 2^200
1606938044258990275541962092341162602522202993782792835301376

julia> sqrt(2.0)
1.414213562373095048801688724209698078569671875376948073176679737990732478462102

julia> typeof($2)
Int64
```


### Installation

This package requires Julia version at least 1.5. It depends on a sub-package,
`SwapLiterals`, described below, which requires only Julia 1.1.
Both packages are registered and can be installed via

```julia
using Pkg
pkg"add SafeREPL"
pkg"add SwapLiterals"
```


### Custom types

What literals mean is specified via `SafeREPL.swapliterals!`.

The four arguments of this function correspond to
`Float64`, `Int`, `Int128`, `BigInt`.
Passing `nothing` means not transforming literals of this type, and
a symbol is interpreted as the name of a function to be applied to the value.
The last argument defaults to `nothing`.
On 32-bits systems, `Int64` literals are transformed in the same way as `Int`
literals.

A single boolean value can also be passed: `swapliterals!(false)` deactivates
`SafeREPL` and `swapliterals!(true)` re-activates it with the previous setting.
Finally, `swapliterals!()` activates the default setting
(what is enabled with `using SafeREPL`, which is equivalent to
`swapliterals!("@big_str", :big, :big)`, see [below](#string-macros)
for the meaning of `"@big_str"`).


#### Examples

```julia
julia> using BitIntegers, BitFloats

julia> swapliterals!(:Float128, :Int256, :Int256)

julia> log2(factorial(60))
254.8391546883338

julia> sqrt(2.0)
1.41421356237309504880168872420969798

julia> using SaferIntegers, DoubleFloats

julia> swapliterals!(:DoubleFloat, :SafeInt, :SafeInt128)

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

julia> using Nemo; swapliterals!(nothing, :fmpz, :fmpz, :fmpz)

julia> factorial(100)
93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000

julia> typeof(ans), typeof(1.2)
(fmpz, Float64)

julia> [1, 2, 3][1] # fmpz is currently not <: Integer ...
ERROR: ArgumentError: invalid index: 1 of type fmpz
[...]

julia> [1, 2, 3][$1] # ... so quote array indices
1

julia> swapliterals!(false); typeof(1), typeof(1.0) # this swapliterals! doesn't act on this line!
(fmpz, Float64)

julia> typeof(1), typeof(1.0)
(Int64, Float64)

julia> swapliterals!(true)

julia> typeof(1), typeof(1.0)
(fmpz, Float64)

julia> swapliterals!() # activate defaults

julia> typeof(1), typeof(1.0)
(BigInt, BigFloat)
```


### How to substitute other literals?

The more general API of `swapliterals!` is to pass a list of pairs
`SourceType => converter`, where `SourceType` is the type on which `converter`
should be applied. For example:

```julia
julia> swapliterals!(Char => :string, Float32 => :Float64, UInt8 => :UInt)

julia> 'a', 1.2f0, 0x12
("a", 1.2000000476837158, 0x0000000000000012)

julia> using Strs; swapliterals!(String => :Str)

julia> typeof("a")
ASCIIStr
```

Notable exceptions are `Symbol` and `Bool` literals, which currently can't be
converted with `swapliterals!` (open an issue if you really need this
feature).


### String macros

For `Int128`, `UInt128` and `BigInt`, it's possible to pass the name of a
string macro (as a `String`) instead of a symbol.
In this case, the macro is used to directly interpret the number. For example:

```julia
julia> swapliterals!(Int128 => "@int1024_str", BigInt => "@int1024_str")

julia> typeof(111111111111111111111111111111111)
Int1024

julia> 1234...(many digits).....789 # of course very big numbers can't be input anymore!
ERROR: LoadError: OverflowError: overflow parsing "1234..."
[...]
```

As an experimental feature, when a string macro is passed to interpret `Float64`,
the input is then first converted to a `String` which is passed to the macro:

```julia
julia> swapliterals!()

julia> 2.6 - 0.7 - 1.9
2.220446049250313e-16

julia> swapliterals!(Float64 => "@big_str")

julia> 1.2
1.200000000000000000000000000000000000000000000000000000000000000000000000000007

julia> 1.2 == big"1.2"
true

julia> 1.1999999999999999 == big"1.1999999999999999"
false

julia> 2.6 - 0.7 - 1.9
-1.727233711018888925077270372560079914223200072887256277004740694033718360632485e-77

julia> using DecFP; swapliterals!(Float64 => "@d64_str")

julia> 2.6 - 0.7 - 1.9
0.0
```


### For the adventurous

<details>
    <summary>Are you sure?</summary>

Few more literals can be substituted: arrays and tuples, and the `{}` vector
syntax, which are specified respectively as `:vect`, `:tuple`, `:braces`.
For example:
```julia
julia> swapliterals!(:vect => :Set)

julia> [1, 2]
Set{Int64} with 2 elements:
  2
  1

julia> :[1, 2]
:(Set([1, 2]))

julia> $[1, 2]
2-element Array{Int64,1}:
 1
 2
```

The next question is: how to use the `:braces` syntax, given that it is not
valid normal-Julia syntax? In addition to the previously mentioned
converter types (`Symbol` and `String`), it's possible to pass a function
which is used to transform the Julia AST:

```julia
julia> makeset(ex) = Expr(:call, :Set, Expr(:vect, ex.args...));

julia> swapliterals!(:braces => makeset)

julia> {1, 2, 3}
Set{Int64} with 3 elements:
  2
  3
  1
```

For types which are stored directly in the AST, using a symbol or
a function is roughly equivalent (and using `$`-quoting or `:`-quoting
is similarly equivalent), for example:

```julia
julia> swapliterals!(Int => Float64)

julia> (1, :1, $1)
1.0, 1, 1

julia> :(1 + 2)
:(1.0 + 2.0)

julia> swapliterals!(Int => :Float64)

julia> (1, :1, $1)
1.0, 1, 1

julia> :(1 + 2)
:(Float64(1) + Float64(2))
```

Note that using functions is a rather experimental feature.

A natural question arising pretty quickly is how `$`-quoting interacts with
other `$`-quoting contexts, in particular with `BenchmarkTools`. With
scalar-substitutions, this is mostly a non-issue, as we usually do not
`$`-quote literal numbers while benchmarking, but this is a bit more subtle
when substituting container literals:

```julia
julia> swapliterals!(false)

julia> @btime sum([1, 2]);
  31.520 ns (1 allocation: 96 bytes)

julia> @btime sum($[1, 2]);
  3.129 ns (0 allocations: 0 bytes)

julia> @btime sum($(Set([1, 2])));
  20.090 ns (0 allocations: 0 bytes)

julia> swapliterals!(:vect => makeset)

julia> @btime sum($[1, 2]); # $[1, 2] is really a vector
  31.459 ns (1 allocation: 96 bytes)

julia> @btime sum($$[1, 2]); # BenchmarkTools-$-quoting for real [1, 2]
  3.480 ns (0 allocations: 0 bytes)

julia> @btime sum($(begin [1, 2] end)); # BenchmarkTools-$-quoting for real Set([1, 2])
  19.786 ns (0 allocations: 0 bytes)

julia> @btime sum($:[1, 2]) # ???
  20.077 ns (0 allocations: 0 bytes)
```

Using a symbol versus a function can also have a subtle impact on benchmarking:
```julia
julia> swapliterals!(false)

julia> @btime big(1) + big(2);
  176.467 ns (6 allocations: 128 bytes)

julia> @btime $(big(1)) + $(big(2));
  71.681 ns (2 allocations: 48 bytes)

julia> swapliterals!(Int => :big)

julia> :(1 + 2)
:(big(1) + big(2))

julia> @btime 1 + 2
  176.982 ns (6 allocations: 128 bytes)

julia> swapliterals!(Int => big)

julia> :(1 + 2)
:(1 + 2)

julia> dump(:(1 + 2))
Expr
  head: Symbol call
  args: Array{Any}((3,))
    1: Symbol +
    2: BigInt
      alloc: Int32 1
      size: Int32 1
      d: Ptr{UInt64} @0x0000000004662760
    3: BigInt
      alloc: Int32 1
      size: Int32 1
      d: Ptr{UInt64} @0x000000000356d4a0

julia> @btime 1 + 2
  63.765 ns (2 allocations: 48 bytes)
```

Finally, as an experimental feature, expressions involving `:=`
can also be transformed, with the same mechanism, for example:
```julia
julia> swapliterals!(:(:=) => ex -> Expr(:(=),
                                         Symbol(uppercase(String(ex.args[1]))),
                                         ex.args[2:end]...))

julia> a := 1; A # equivalent to `A = 1`
1
```
</details>


### How to use in source code?

Via the `@swapliterals` macro from the `SwapLiterals` package,
which has roughly the same API as the `swapliterals!` function:

```julia
using SwapLiterals

x = @swapliterals :big :big :big begin
    1.0, 2^123
end
typeof(x) # Tuple{BigFloat,BigInt}

x = @swapliterals (1.0, 2^123) # shorter version, uses :big as defaults
```
Note: if you try the above at the REPL while `SafeREPL` is also active, `typeof(x)`
might be `Tuple{BigFloat,BigInt}`.
Try first `swapliterals!(false)` to deactivate `SafeREPL`.

The pair API is also available, as well as the possibility to pass converters in
a (literal) array for more clarity:

```julia
@swapliterals Int => :big 1

x = @swapliterals [Int => :big,
                   Int128 => :big,
                   Float64 => big
                  ] begin
       1.0, 1, 111111111111111111111
end
typeof(x) # Tuple{BigFloat,BigInt,BigInt}
```

Note that passing a non-global function as the converter
(to transform the AST, cf. [previous section](#for-the-adventurous))
is likely to fail.


### Visual indicator that SafeREPL is active

The following can be put in the "startup.jl" file to modify the color of the
prompt, or to modify the text in the prompt. Tweak as necessary.

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


### Switching easily back and forth

You can set up a keybinding to activate or de-activate `SafeREPL`, e.g.
`Ctrl-x` followed by `Ctrl-s`, by putting the following in "startup.jl":

```julia
using REPL

const mykeys = Dict(
    "^x^s" => function (s, o...)
                  swapliterals!(!SafeREPL.isactive())
                  REPL.LineEdit.refresh_line(s)
              end
)

atreplinit() do repl
    repl.interface = REPL.setup_interface(repl; extra_repl_keymap = mykeys)
end
```
Cf. the
[manual](https://docs.julialang.org/en/v1.4/stdlib/REPL/#Customizing-keybindings-1)
for details.
Note that `REPL.setup_interface` should be called only once, so to set up
a keybinding together with a custom prompt as shown in last section,
both `atreplinit` calls must be combined, e.g.

```julia
atreplinit() do repl
    repl.interface = REPL.setup_interface(repl; extra_repl_keymap = mykeys)
    julia_mode = repl.interface.modes[1]

    # ... modify julia_mode
end
```


### Caveats

* This package was not tested on 32-bits architectures, so use it at your own risks.
  By the way, there is no guarantee even on 64-bits architectures...

* Using new number types by default in the REPL might reveal many missing methods
  for these types and render the REPL less usable than ideal.
  Good opportunity for opening ticket/issues in the corresponding projects :)
  In the meantime, this can be mitigated by the use of `$`.

* It should be clear that using `BigInt` and `BigFloat` for literals instead
  of `Int` and `Float64` can make some function calls quite more expensive,
  time-wise and memory-wise. So `SafeREPL` just offers a different trade-off
  than the default Julia REPL, it's not a panacea.

* float literals are stored as `Float64` in the Julia AST, meaning that
  information can be lost:

```julia
julia> using SafeREPL; swapliterals!(Float64 => :big)

julia> :(print(1.2))
:(print(big(1.2)))

julia> 1.2 # this is equivalent to `big(1.2)`
1.1999999999999999555910790149937383830547332763671875

julia> big"1.2"
1.200000000000000000000000000000000000000000000000000000000000000000000000000007
```

As said earlier, one can pass `"@big_str"` for the `Float64` converter to try
to mitigate this problem: this is currently the default.
Another alternative (which does _not_ always produce
the same results as with `"@big_str"`) is to call `rationalize` before
converting to a float.
There is an experimental option to have `SafeREPL` implicitly insert
calls to `rationalize`, which is enabled by calling
`floats_use_rationalize!(true)`:

```julia
julia> bigfloat(x) = BigFloat(rationalize(x));

julia> swapliterals!(Float64 => :bigfloat)

julia> 1.2
1.200000000000000000000000000000000000000000000000000000000000000000000000000007

julia> swapliterals!(Float64 => :big); SafeREPL.floats_use_rationalize!(true);

julia> 1.2
1.200000000000000000000000000000000000000000000000000000000000000000000000000007

julia> 1.20000000000001
1.200000000000010169642905566151645987816694259698096594761182517957654980952429

julia> swapliterals!(Float64 => "@big_str") # rationalize not used

julia> 1.20000000000001
1.200000000000010000000000000000000000000000000000000000000000000000000000000006
```


### How "safe" is it?

This is totally up to the user. Some Julia users get disappointed when they
encounter some "unsafe" arithmetic operations (due to integer overflow for
example). "Safe" in `SafeREPL` must be understood tongue-in-cheek, and applies
to the default setting where some overflows will disappear. This package can
make Julia quite more unsafe; here is a "soft" example:

```julia
julia> swapliterals!(Int => x -> x % Int8)

julia> 1234
-46
```


### Alternatives

Before Julia 1.5, the easiest alternative was probably to use a custom REPL
mode, and
[ReplMaker.jl](https://github.com/MasonProtter/ReplMaker.jl#example-3-big-mode)
even has an example to set this up in few lines.
Here is a way to use `SwapLiterals` as a backend for a `ReplMaker` mode,
which uses the `valid_julia` function defined in its
[README](https://github.com/MasonProtter/ReplMaker.jl#example-1-expr-mode):

```julia
julia> literals_swapper = SwapLiterals.literals_swapper([Int=>:big, Int128=>:big, Float64=>"@big_str"]);

julia> function Big_parse(s)
           expr = Meta.parse(s)
           literals_swapper(expr)
       end

julia> initrepl(Big_parse,
                prompt_text="BigJulia> ",
                prompt_color = :red,
                start_key='>',
                mode_name="Big-Mode",
                valid_input_checker=valid_julia)
```

The `SwapLiterals.literals_swapper` function takes a list of pairs which have
the same meaning as in `swapliterals!`. Note that it's currently not part of the
public API of `SwapLiterals`.

At least a couple of packages have a macro similar to `@swapliterals`:
* [ChangePrecision.jl](https://github.com/stevengj/ChangePrecision.jl),
  with the `@changeprecision` macro which reinterprets floating-point literals
  but also some floats-producing functions like `rand()`.
* [SaferIntegers.jl](https://github.com/JeffreySarnoff/SaferIntegers.jl),
  with the `@saferintegers` macro which wraps integers using `SaferIntegers`
  types.
