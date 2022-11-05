module MutationChecks

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
end


function execute(c::Call)
    c.f(c.args...; c.kw...)
end

function trymutcheck(call::Call, options::Options, expr)
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

macro mutcheck(code)
    mutcheckmacro(code)
end

function mutcheckmacro(code)
    if Meta.isexpr(code, :do)
        error("do blocks are currently not supported. Got $code")
    end
    if !Meta.isexpr(code, :call)
        error("Expected a function call, got $code instead.")
    end
    call = if length(code.args) >= 2 && Meta.isexpr(code.args[2], :parameters)
        Expr(:call, make_call, code.args[2], code.args[1], code.args[3:end]...)
    else
        Expr(:call, make_call, code.args...)
    end
    options = Options()
    quote
        out, err = $trymutcheck($(esc(call)), $options, $(QuoteNode(code)))
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
    if err isa CmpSelfCheckFail
        println(io, "Self comparison failed.")
    else
        @assert err isa MutCheckFail
        println(io, "Mutation detected.")
    end
    res = err.result
    msg_pos = if isempty(res.differ_args)
        "None were mutated."
    else
        "Mutated positions are $(res.differ_args)"
    end
    msg_kw = if isempty(res.differ_args)
        "None were mutated."
    else
        "Mutated keywords are $(res.differ_kw)"
    end
    msg = """
    * Expression:           $(err.expr)
    * Calle mutated:        $(res.f_differs)
    * Positional arguments: $(msg_pos)
    * Keyword arguments:    $(msg_kw)
    """
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
        arg1 = call1.args[i]
        arg2 = call2.args[i]
        !options.cmp(arg1, arg2)::Bool
    end
    differ_kw = filter(collect(propertynames(call1.kw))) do s
        kw1 = call1.kw[s]
        kw2 = call2.kw[s]
        !options.cmp(kw1, kw2)::Bool
    end
    MutationResults(f_differs, differ_args, differ_kw, call1, call2, options)
end

end
