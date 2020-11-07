using Pkg

if VERSION >= v"1.5"
    Pkg.develop(path="../SwapLiterals")
end
Pkg.test("SwapLiterals")
