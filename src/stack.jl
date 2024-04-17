"""
    Stack{T}()

A stack specialised for reverse-mode AD.

Semantically equivalent to a usual stack, but never de-allocates memory once allocated.
"""
mutable struct Stack{T}
    const memory::Vector{T}
    position::Int
    Stack{T}() where {T} = new{T}(Vector{T}(undef, 0), 0)
end

function Stack{T}(x) where {T}
    stack = Stack{T}()
    push!(stack, x)
    return stack
end

Stack(x::T) where {T} = Stack{T}(x)

@inline function Base.push!(x::Stack{T}, val::T) where {T}
    position = x.position + 1
    memory = x.memory
    x.position = position
    if position <= length(memory)
        @inbounds memory[position] = val
        return nothing
    else
        @noinline push!(memory, val)
        return nothing
    end
end

@inline function Base.pop!(x::Stack)
    position = x.position
    val = x.memory[position]
    x.position = position - 1
    return val
end

Base.isempty(x::Stack) = x.position == 0

Base.length(x::Stack) = x.position

"""
    Base.getindex(x::Stack)

Return the value at the top of `x` without popping it.
"""
Base.getindex(x::Stack) = x.memory[x.position]

"""
    Base.setindex!(x::Stack, v)

Set the value of the element at the top of the `x` to `v`.
"""
function Base.setindex!(x::Stack, v)
    x.memory[x.position] = v
    return v
end

Base.eltype(::Stack{T}) where {T} = T


struct SingletonStack{T} end

Base.push!(::SingletonStack, ::Any) = nothing
@generated Base.pop!(::SingletonStack{T}) where {T} = T.instance


function reverse_data_ref_type(::Type{P}) where {P}
    P === DataType && return Ref{Any}
    return Base.RefValue{rdata_type(tangent_type(P))}
end
