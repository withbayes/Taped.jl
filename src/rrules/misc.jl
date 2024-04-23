#
# Performance-only rules. These should be able to be removed, and everything still works,
# just a bit slower. The effect of these is typically to remove many nodes from the tape.
# Ideally, it would be the case that acitivty analysis eliminates any run-time improvements
# that these rules provide. Possibly they would still be useful in order to avoid having to
# deduce that these bits of code are inactive though.
#

for name in [
    :size,
    :(LinearAlgebra.lapack_size),
    :(Base.require_one_based_indexing),
    :in,
    :iszero,
    :isempty,
    :isbitstype,
    :sizeof,
    :promote_type,
    :(Base.elsize),
    :(Core.Compiler.sizeof_nothrow),
    :(Base.datatype_haspadding),
    :(Base.datatype_nfields),
    :(Base.datatype_pointerfree),
    :(Base.datatype_alignment),
    :(Base.datatype_fielddesc_type),
    :(LinearAlgebra.chkstride1),
    :(Threads.nthreads),
    :(Base.depwarn),
    :(Base.reduced_indices),
    :(Base.check_reducedims),
    :(Base.throw_boundserror),
]
    @eval @is_primitive DefaultCtx Tuple{typeof($name), Vararg}
    @eval function rrule!!(::CoDual{_typeof($name)}, args::CoDual...)
        v = $name(map(primal, args)...)
        pb!! = NoPullback((NoRData(), tuple_map(zero_rdata, args)...))
        return zero_fcodual(v), pb!!
    end
end

@is_primitive MinimalCtx Tuple{Type, TypeVar, Type}
function rrule!!(x::CoDual{<:Type}, y::CoDual{<:TypeVar}, z::CoDual{<:Type})
    return CoDual(primal(x)(primal(y), primal(z)), NoTangent()), NoPullback()
end

"""
    lgetfield(x, f::Val)

An implementation of `getfield` in which the the field `f` is specified statically via a
`Val`. This enables the implementation to be type-stable even when it is not
possible to constant-propagate `f`. Moreover, it enable the pullback to also be type-stable.

It will always be the case that
```julia
getfield(x, :f) === lgetfield(x, Val(:f))
getfield(x, 2) === lgetfield(x, Val(2))
```

This approach is identical to the one taken by `Zygote.jl` to circumvent the same problem.
`Zygote.jl` calls the function `literal_getfield`, while we call it `lgetfield`.
"""
lgetfield(x, ::Val{f}) where {f} = getfield(x, f)

@is_primitive MinimalCtx Tuple{typeof(lgetfield), Any, Any}
@inline function rrule!!(
    ::CoDual{typeof(lgetfield)}, x::CoDual{P}, ::CoDual{Val{f}}
) where {P, f}
    pb!! = if ismutabletype(P)
        dx = tangent(x)
        function mutable_lgetfield_pb!!(dy)
            increment_field_rdata!(dx, dy, Val{f}())
            return NoRData(), NoRData(), NoRData()
        end
    else
        dx_r = LazyZeroRData(primal(x))
        field = Val{f}()
        function immutable_lgetfield_pb!!(dy)
            return NoRData(), increment_field!!(instantiate(dx_r), dy, field), NoRData()
        end
    end
    y = CoDual(getfield(primal(x), f), _get_fdata_field(primal(x), tangent(x), f))
    return y, pb!!
end

_get_fdata_field(_, t::Union{Tuple, NamedTuple}, f...) = getfield(t, f...)
_get_fdata_field(_, data::FData, f...) = val(getfield(data.data, f...))
_get_fdata_field(primal, ::NoFData, f...) = uninit_fdata(getfield(primal, f...))
_get_fdata_field(_, t::MutableTangent, f...) = fdata(val(getfield(t.fields, f...)))

increment_field_rdata!(dx::MutableTangent, ::NoRData, ::Val) = dx
increment_field_rdata!(dx::NoFData, ::NoRData, ::Val) = dx
function increment_field_rdata!(dx::T, dy_rdata, ::Val{f}) where {T<:MutableTangent, f}
    set_tangent_field!(dx, f, increment_rdata!!(get_tangent_field(dx, f), dy_rdata))
    return dx
end

#
# lgetfield with order argument
#

lgetfield(x, ::Val{f}, ::Val{order}) where {f, order} = getfield(x, f, order)

@is_primitive MinimalCtx Tuple{typeof(lgetfield), Any, Any, Any}
@inline function rrule!!(
    ::CoDual{typeof(lgetfield)}, x::CoDual{P}, ::CoDual{Val{f}}, ::CoDual{Val{order}}
) where {P, f, order}
    T = tangent_type(P)
    R = rdata_type(T)

    if ismutabletype(P)
        dx = tangent(x)
        pb!! = if R == NoRData
            NoPullback((NoRData(), NoRData(), NoRData(), NoRData()))
        else
            function mutable_lgetfield_pb!!(dy)
                return NoRData(), increment_field_rdata!!(dx, dy, Val{f}()), NoRData(), NoRData()
            end
        end
        y = CoDual(getfield(primal(x), f), fdata(_get_fdata_field(primal(x), tangent(x), f)))
        return y, pb!!
    else
        pb!! = if R == NoRData
            NoPullback((NoRData(), NoRData(), NoRData(), NoRData()))
        else
            dx_r = LazyZeroRData(primal(x))
            function immutable_lgetfield_pb!!(dy)
                tmp = increment_field!!(instantiate(dx_r), dy, Val{f}())
                return NoRData(), tmp, NoRData(), NoRData()
            end
        end
        y = CoDual(getfield(primal(x), f, order), _get_fdata_field(primal(x), tangent(x), f))
        return y, pb!!
    end
end

"""
    lsetfield!(value, name::Val, x, [order::Val])

This function is to `setfield!` what `lgetfield` is to `getfield`. It will always hold that
```julia
setfield!(copy(x), :f, v) == lsetfield!(copy(x), Val(:f), v)
setfield!(copy(x), 2, v) == lsetfield(copy(x), Val(2), v)
```
"""
lsetfield!(value, ::Val{name}, x) where {name} = setfield!(value, name, x)

@is_primitive MinimalCtx Tuple{typeof(lsetfield!), Any, Any, Any}
@inline function rrule!!(
    ::CoDual{typeof(lsetfield!)}, value::CoDual{P}, ::CoDual{Val{name}}, x::CoDual
) where {P, name}
    F = fdata_type(tangent_type(P))
    save = isdefined(primal(value), name)
    old_x = save ? getfield(primal(value), name) : nothing
    old_dx = if F == NoFData
        NoFData()
    else
        save ? val(getfield(tangent(value).fields, name)) : nothing
    end
    dvalue = tangent(value)
    pb!! = if F == NoFData
        function __setfield!_pullback(dy)
            old_x !== nothing && lsetfield!(primal(value), Val(name), old_x)
            return NoRData(), NoRData(), NoRData(), dy
        end
    else
        function setfield!_pullback(dy)
            new_dx = increment!!(dy, rdata(val(getfield(dvalue.fields, name))))
            old_x !== nothing && lsetfield!(primal(value), Val(name), old_x)
            old_x !== nothing && set_tangent_field!(dvalue, name, old_dx)
            return NoRData(), NoRData(), NoRData(), new_dx
        end
    end
    yf = F == NoFData ? NoFData() : fdata(set_tangent_field!(dvalue, name, zero_tangent(primal(x), tangent(x))))
    y = CoDual(lsetfield!(primal(value), Val(name), primal(x)), yf)
    return y, pb!!
end

function generate_hand_written_rrule!!_test_cases(rng_ctor, ::Val{:misc})

    # Data which needs to not be GC'd.
    _x = Ref(5.0)
    _dx = Ref(4.0)
    memory = Any[_x, _dx]

    specific_test_cases = Any[
        # Rules to avoid pointer type conversions.
        (
            true, :stability, nothing,
            +,
            CoDual(
                bitcast(Ptr{Float64}, pointer_from_objref(_x)),
                bitcast(Ptr{Float64}, pointer_from_objref(_dx)),
            ),
            2,
        ),

        # Lack of activity-analysis rules:
        (false, :stability_and_allocs, nothing, Base.elsize, randn(5, 4)),
        (false, :stability_and_allocs, nothing, Base.elsize, view(randn(5, 4), 1:2, 1:2)),
        (false, :stability_and_allocs, nothing, Core.Compiler.sizeof_nothrow, Float64),
        (false, :stability_and_allocs, nothing, Base.datatype_haspadding, Float64),

        # Performance-rules that would ideally be completely removed.
        (false, :stability_and_allocs, nothing, size, randn(5, 4)),
        (
            false, :stability_and_allocs, nothing,
            LinearAlgebra.lapack_size, 'N', randn(5, 4),
        ),
        (
            false, :stability_and_allocs, nothing,
            Base.require_one_based_indexing, randn(2, 3), randn(2, 1),
        ),
        (false, :stability_and_allocs, nothing, in, 5.0, randn(4)),
        (false, :stability_and_allocs, nothing, iszero, 5.0),
        (false, :stability_and_allocs, nothing, isempty, randn(5)),
        (false, :stability_and_allocs, nothing, isbitstype, Float64),
        (false, :stability_and_allocs, nothing, sizeof, Float64),
        (false, :stability_and_allocs, nothing, promote_type, Float64, Float64),
        (false, :stability_and_allocs, nothing, LinearAlgebra.chkstride1, randn(3, 3)),
        (
            false, :stability_and_allocs, nothing,
            LinearAlgebra.chkstride1, randn(3, 3), randn(2, 2),
        ),
        (false, :allocs, nothing, Threads.nthreads),

        # Literal replacements for getfield.

        # Tuple
        (false, :stability_and_allocs, nothing, lgetfield, (5.0, 4), Val(1)),
        (false, :stability_and_allocs, nothing, lgetfield, (5.0, 4), Val(2)),
        (false, :stability_and_allocs, nothing, lgetfield, (1, 4), Val(2)),
        (false, :stability_and_allocs, nothing, lgetfield, ((), 4), Val(2)),
        (false, :stability_and_allocs, nothing, lgetfield, (randn(2),), Val(1)),
        (false, :stability_and_allocs, nothing, lgetfield, (randn(2), 5), Val(1)),
        (false, :stability_and_allocs, nothing, lgetfield, (randn(2), 5), Val(2)),

        # NamedTuple
        (false, :stability_and_allocs, nothing, lgetfield, (a=5.0, b=4), Val(1)),
        (false, :stability_and_allocs, nothing, lgetfield, (a=5.0, b=4), Val(2)),
        (false, :stability_and_allocs, nothing, lgetfield, (a=5.0, b=4), Val(:a)),
        (false, :stability_and_allocs, nothing, lgetfield, (a=5.0, b=4), Val(:b)),
        (false, :stability_and_allocs, nothing, lgetfield, (y=randn(2),), Val(1)),
        (false, :stability_and_allocs, nothing, lgetfield, (y=randn(2),), Val(:y)),
        (false, :stability_and_allocs, nothing, lgetfield, (y=randn(2), x=5), Val(1)),
        (false, :stability_and_allocs, nothing, lgetfield, (y=randn(2), x=5), Val(2)),
        (false, :stability_and_allocs, nothing, lgetfield, (y=randn(2), x=5), Val(:y)),
        (false, :stability_and_allocs, nothing, lgetfield, (y=randn(2), x=5), Val(:x)),

        # structs
        (false, :stability_and_allocs, nothing, lgetfield, 1:5, Val(:start)),
        (false, :stability_and_allocs, nothing, lgetfield, 1:5, Val(:stop)),
        (true, :none, (lb=1, ub=100), lgetfield, StructFoo(5.0), Val(:a)),
        (false, :none, (lb=1, ub=100), lgetfield, StructFoo(5.0, randn(5)), Val(:a)),
        (false, :none, (lb=1, ub=100), lgetfield, StructFoo(5.0, randn(5)), Val(:b)),
        (true, :none, (lb=1, ub=100), lgetfield, StructFoo(5.0), Val(1)),
        (false, :none, (lb=1, ub=100), lgetfield, StructFoo(5.0, randn(5)), Val(1)),
        (false, :none, (lb=1, ub=100), lgetfield, StructFoo(5.0, randn(5)), Val(2)),

        # mutable structs
        (true, :none, nothing, lgetfield, MutableFoo(5.0), Val(:a)),
        (false, :none, nothing, lgetfield, MutableFoo(5.0, randn(5)), Val(:b)),
        (false, :none, nothing, lgetfield, UInt8, Val(:name)),
        (false, :none, nothing, lgetfield, UInt8, Val(:super)),
        (true, :none, nothing, lgetfield, UInt8, Val(:layout)),
        (false, :none, nothing, lgetfield, UInt8, Val(:hash)),
        (false, :none, nothing, lgetfield, UInt8, Val(:flags)),

        # Literal replacement for setfield!.
        (
            false, :stability_and_allocs, nothing,
            lsetfield!, MutableFoo(5.0, [1.0, 2.0]), Val(:a), 4.0,
        ),
        (
            false, :stability_and_allocs, nothing,
            lsetfield!, FullyInitMutableStruct(5.0, [1.0, 2.0]), Val(:y), [1.0, 3.0, 4.0],
        ),
        (
            false, :stability_and_allocs, nothing,
            lsetfield!, NonDifferentiableFoo(5, false), Val(:x), 4,
        ),
        (
            false, :stability_and_allocs, nothing,
            lsetfield!, NonDifferentiableFoo(5, false), Val(:y), true,
        )
    ]
    general_lgetfield_test_cases = map(TestTypes.PRIMALS) do (interface_only, P, args)
        _, primal = TestTypes.instantiate((interface_only, P, args))
        names = fieldnames(P)[1:length(args)] # only query fields which get values
        return Any[(interface_only, :none, nothing, lgetfield, primal, Val(name)) for name in names]
    end
    test_cases = vcat(specific_test_cases, general_lgetfield_test_cases...)
    return test_cases, memory
end

generate_derived_rrule!!_test_cases(rng_ctor, ::Val{:misc}) = Any[], Any[]
