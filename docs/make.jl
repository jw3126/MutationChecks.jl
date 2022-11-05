using MutationChecks
using Documenter

DocMeta.setdocmeta!(MutationChecks, :DocTestSetup, :(using MutationChecks); recursive=true)

makedocs(;
    modules=[MutationChecks],
    authors="Jan Weidner <jw3126@gmail.com> and contributors",
    repo="https://github.com/jw3126/MutationChecks.jl/blob/{commit}{path}#{line}",
    sitename="MutationChecks.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://jw3126.github.io/MutationChecks.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/jw3126/MutationChecks.jl",
    devbranch="main",
)
