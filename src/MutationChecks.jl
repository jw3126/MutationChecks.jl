module MutationChecks
export @mutcheck
import WhyNotEqual as WN

struct Call{F,Args,KW <: NamedTuple}
    f::F
    args::Args
    kw::KW
end
function make_call(f, args...; kw...)
    F = typeof(f)
    Args = typeof(args)
    kw_ = NamedTuple(kw)
    KW = typeof(kw_)
    Call{F,Args,KW}(f,args,kw_)
end

Base.@kwdef struct Options
    cmp = isequal
    copy = deepcopy
    ignore::Vector = Union{Int,Symbol}[]
    skip::Bool = false
    whynot::Bool = true
end

resolve_options(::Nothing) = Options()
resolve_options(opt::Options) = opt
resolve_options(kw::NamedTuple) = Options(;kw...)


function execute(c::Call)
    c.f(c.args...; c.kw...)
end

function trymutcheck(call::Call, options::Options, expr)
    if options.skip
        return (execute(call), nothing)
    end
    # TODO don't copy ignored args
    call_backup = options.copy(call)::typeof(call)
    out = execute(call)
    res = MutationResults(call, call_backup, options)
    if ispass(res)
        return (out, nothing)
    end
    res_self_check = MutationResults(call_backup, deepcopy(call_backup), options)
    if ispass(res_self_check)
        return (out, MutCheckFail(res, expr))
    else
        return (out, CmpSelfCheckFail(res_self_check, expr))
    end
end

macro mutcheck(code, options=nothing)
    mutcheckmacro(code, options)
end

function mutcheckmacro(code, options=nothing)
    if Meta.isexpr(code, :do)
        error("do blocks are currently not supported. Consider making a PR! Got $code")
    end
    if !Meta.isexpr(code, :call)
        error("Expected a function call, got $code instead.")
    end
    call = if length(code.args) >= 2 && Meta.isexpr(code.args[2], :parameters)
        Expr(:call, make_call, code.args[2], code.args[1], code.args[3:end]...)
    else
        Expr(:call, make_call, code.args...)
    end
    quote
        options::$Options = $resolve_options($(esc(options)))
        out, err = $trymutcheck($(esc(call)), options, $(QuoteNode(code)))
        if err isa Exception
            throw(err)
        else
            out
        end
    end
end

struct MutationResults
    f_differs::Bool
    differ_args::Vector{Int}
    differ_kw::Vector{Symbol}
    call1::Call
    call2::Call
    options::Options
end

struct CmpSelfCheckFail <: Exception
    result::MutationResults
    expr
end

struct MutCheckFail <: Exception
    result::MutationResults
    expr
end

function _showerror(io, err::Union{CmpSelfCheckFail, MutCheckFail})
    isselfcheck = err isa CmpSelfCheckFail
    ismutcheck = err isa MutCheckFail
    if isselfcheck
        println(io, "Self comparison failed.")
    else
        @assert ismutcheck
        println(io, "Mutation detected.")
    end
    res = err.result
    pass_calle = !(res.f_differs)
    msg_calle = if !pass_calle && isselfcheck
        "Not self equal."
    elseif !pass_calle &&  ismutcheck
        "Mutated."
    elseif  pass_calle && isselfcheck
        "Self equal."
    elseif pass_calle && ismutcheck
        "Not mutated."
    else
        error()
    end
    pass_pos = isempty(res.differ_args)
    msg_pos = if pass_pos && ismutcheck
        "None were mutated."
    elseif pass_pos && isselfcheck
        "All self equal."
    elseif (!pass_pos) && ismutcheck
        "Mutated positions are $(res.differ_args)."
    elseif (!pass_pos) && isselfcheck
        "Self unequal positions are $(res.differ_args)."
    else
        error()
    end
    pass_kw = isempty(res.differ_kw)
    msg_kw = if pass_kw && ismutcheck
        "None were mutated."
    elseif pass_kw && isselfcheck
        "All self equal."
    elseif (!pass_kw) && ismutcheck
        "Mutated keywords are $(res.differ_kw)."
    elseif (!pass_kw) && isselfcheck
        "Self unequal keywords are $(res.differ_kw)"
    else
        error()
    end
    msg = """
    * Expression:           $(err.expr)
    * Calle:                $(msg_calle)
    * Positional arguments: $(msg_pos)
    * Keyword arguments:    $(msg_kw)
    """
    options = err.result.options
    if options.whynot
        cmp = options.cmp
        msg_whynot = sprint(show, WN.whynot(cmp, err.result.call1, err.result.call2))
        msg = """$msg
        # Description of the mutation
        $msg_whynot
        """
    end
    println(io, msg)
end
Base.showerror(io::IO, err::CmpSelfCheckFail) = _showerror(io, err)
Base.showerror(io::IO, err::MutCheckFail) = _showerror(io, err)

function ispass(o::MutationResults)
    isempty(o.differ_args) && isempty(o.differ_kw) && (!o.f_differs)
end

function MutationResults(call1::Call, call2::Call, options::Options)
    f_differs = !options.cmp(call1.f, call2.f)::Bool
    differ_args = filter(eachindex(call1.args, call2.args)) do i
        i in options.ignore && return false
        arg1 = call1.args[i]
        arg2 = call2.args[i]
        !options.cmp(arg1, arg2)::Bool
    end
    differ_kw = filter(collect(propertynames(call1.kw))) do s
        s in options.ignore && return false
        kw1 = call1.kw[s]
        kw2 = call2.kw[s]
        !options.cmp(kw1, kw2)::Bool
    end
    MutationResults(f_differs, differ_args, differ_kw, call1, call2, options)
end

end
