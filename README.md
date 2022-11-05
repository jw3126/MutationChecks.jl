# MutationChecks

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://jw3126.github.io/MutationChecks.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jw3126.github.io/MutationChecks.jl/dev/)
[![Build Status](https://github.com/jw3126/MutationChecks.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jw3126/MutationChecks.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jw3126/MutationChecks.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jw3126/MutationChecks.jl)

Mutation is the source of subtle bugs. This tiny package provides a simple macro that is useful for 
exposing unwanted mutations.

```julia
using MutationChecks

mymul(x,y) = x .* y
myadd(x,y) = x .+ y
mysub(x,y) = x .-= y # oups

function mycalc(a,b)
    c = @mutcheck myadd(a,b)
    d = @mutcheck mymul(c,b)
    e = @mutcheck mysub(d,c)
    c = @mutcheck myadd(a,e)
end

mycalc([1,2],[3,4])
```
```
ERROR: Mutation detected.
* Expression:           mysub(d, c)
* Calle mutated:        false
* Positional arguments: Mutated positions are [1]
* Keyword arguments:    None were mutated.
```
