using MutationChecks: @mutcheck, MutCheckFail, CmpSelfCheckFail
using Test

pass(args...; ret, kw...) = ret
apply(f, args...; kw...) = f(args...; kw...)

struct Pass end
(::Pass)(args...; ret, kw...) = ret

struct Ev{T}
    value::T
end
Base.:(==)(o1::Ev, o2::Ev) = o1.value == o2.value
function (o::Ev)(f, args...; kw...)
    f(o.value)
end

mutable struct MutContainer
    value
end
@testset "MutationChecks.jl" begin
    x = 1
    y = 2
    @test sin(10) == @mutcheck sin(10)
    @test nothing === @mutcheck Nothing()
    @test 20 === @mutcheck pass(;ret=20)
    foo = (a=10,b=20)
    a = (1,2,3)
    @test 10 === @mutcheck pass(x,y,a..., c=3; foo..., ret=10)
    @test 11 === @mutcheck pass(x->x,y,c=3; foo..., ret=11)

    copykw!(;src, dst) = copy!(dst, src)
    @test_throws MutCheckFail @mutcheck copykw!(src=[1], dst=[2])
    @test_throws MutCheckFail @mutcheck copykw!(src=[1], dst=[2]) (ignore=[:src],)
    @mutcheck copykw!(src=[1], dst=[2]) (ignore=[:dst],)
    @mutcheck copykw!(src=[1], dst=[2]) (ignore=[:dst, :src],)
    @mutcheck copykw!(src=[1], dst=[2]) (skip=true,)
    @mutcheck copykw!(src=[1], dst=[2]) (skip=true, ignore=[:dst])

    x = [1];y = [2]
    @test_throws MutCheckFail @mutcheck copy!(x,y)
    x = [1];y = [2]
    @test_throws MutCheckFail @mutcheck copy!(x,y) (ignore=[2],)
    x = [1];y = [2]
    @mutcheck copy!(x,y) (ignore=[1],)
    x = [1];y = [2]
    @mutcheck copy!(x,y) (skip=true,)
    x = [1];y = [2]
    outcome = @test_throws MutCheckFail @mutcheck apply(empty!, [1])
    err = outcome.value

    @test Ev([1]) == deepcopy(Ev([1]))
    @test_throws MutCheckFail @mutcheck Ev([1])(empty!)
    @test_throws MutCheckFail @mutcheck Ev([1])(empty!, 1,2,3, a..., x=2, )
    @test !isequal(MutContainer(1), MutContainer(1))
    @test !isequal(MutContainer(MutContainer(1)), MutContainer(MutContainer(1)))

    @test_throws CmpSelfCheckFail @mutcheck pass(MutContainer(1), ret=1)
    @test_throws CmpSelfCheckFail @mutcheck pass(MutContainer(MutContainer(1)), ret=1)

    @test @mutcheck NaN === pass(ret=NaN)
end
