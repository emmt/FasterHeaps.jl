abstract type AbstractBinaryHeap{T,O<:Ordering} <: AbstractVector{T} end

"""
    BinaryHeap{T}(o = FastMin)

yields an empty binary heap whose nodes are of type `T` and with ordering
specified by `o`.

A vector `vals` storing the nodes of the binary heap can be specified:

    BinaryHeap([o = FastMin,] vals)

Standard methods that can be applied to a binary heap `h`:

    pop!(h)     # yield the root node of heap h
    push!(h, x) # push node x in heap h

A binary heap `h` behaves like an abstract vector(with 1-based linear indices):

    length(h)   # the number of nodes in heap h
    h[i]        # the i-th node of heap h
    h[i] = x    # set the i-th node of heap h and heapify h

Note that `h[1]` is the root node of the heap `h` and that setting a node in
the heap may triggers reordering of the nodes to maintain the binary heap
structure.  In other words, after doing `h[i] = x`, do not assume that `h[i]`
yields `x`.

Other methods:

    delete!(h, i) # deletes i-th value form the heap h and heapify h

    sizehint!(h, n)
    size(h)
    axes(h)
    eltype(h)
    ndims(h)
    empty!(h)
    isempty(h)
    first(h)      # the root node of the heap h
    peek(h)       # the root node of the heap h

Operations that modify the heap, like deletion by `delete!(h,i)`, insertion by
`h[i] = x`, pushing and popping, are `O(1)` in the best case, `O(log(n))` in
the worst case, with `n = length(h)` the number of nodes in the heap

"""
struct BinaryHeap{T,O} <: AbstractBinaryHeap{T,O}
    order::O         # ordering
    nodes::Vector{T} # storage for the nodes
    BinaryHeap{T}(o::O=FastMin) where {T,O<:Ordering} =
        new{T,O}(o, Vector{T}(undef, 0))
    BinaryHeap{T}(o::O, vals::AbstractVector) where {T,O<:Ordering} =
        heapify!(new{T,O}(o, vals))
end

"""
    h = FastBinaryHeap{T}(...)

yields a fast binary heap `h`.  Compared to `BinaryHeap{T}(...)`, the array
backing the storage of the heap values is never reduced to improve performances
in some cases.  You may call `resize!(h)` to explicitly reduce the storage to
its minimum.

"""
mutable struct FastBinaryHeap{T,O} <: AbstractBinaryHeap{T,O}
    order::O         # ordering
    nodes::Vector{T} # storage for the nodes
    count::Int       # current number of nodes
    FastBinaryHeap{T}(o::O=FastMin) where {T,O<:Ordering} =
        new{T,O}(o, Vector{T}(undef, 0), 0)
    FastBinaryHeap{T}(o::O, vals::AbstractVector) where {T,O<:Ordering} =
        heapify!(new{T,O}(o, vals, length(vals)))
end

# Outer constructors.
for type in (:FastBinaryHeap, :BinaryHeap)
    @eval begin
        $type{T}(vals::AbstractVector) where {T} = $type{T}(FastMin, vals)
        $type(vals::AbstractVector{T}) where {T} = $type{T}(vals)
        $type(o::Ordering, vals::AbstractVector{T}) where {T} =
            $type{T}(o, vals)
    end
end

ordering(h::AbstractBinaryHeap) = getfield(h, :order)
nodes(h::AbstractBinaryHeap) = getfield(h, :nodes)
length(h::FastBinaryHeap) = getfield(h, :count)
length(h::BinaryHeap) = length(nodes(h))
size(h::AbstractBinaryHeap) = (length(h),)
IndexStyle(::Type{<:AbstractBinaryHeap}) = IndexLinear()
sizehint!(h::AbstractBinaryHeap, n::Integer) = sizehint!(nodes(h), n)
isempty(h::AbstractBinaryHeap) = length(h) < 1

# Call `resize!(h)` with no other arguments to reduce the storage size.
resize!(h::FastBinaryHeap) = (resize!(nodes(h), length(h)); h)
resize!(h::BinaryHeap) = h

# Heap indexing.  Note that linear 1-based indexing is assumed for the
# array storing the heap.
heap_left(i::Int) = 2*i
heap_right(i::Int) = 2*i + 1
heap_parent(i::Int) = div(i, 2)

@inline function getindex(heap::AbstractBinaryHeap, i::Int)
    @boundscheck checkbounds(heap, i)
    @inbounds r = getindex(nodes(heap), i)
    return r
end

@inline @propagate_inbounds setindex!(heap::AbstractBinaryHeap, x, i::Int) =
    setindex!(heap, to_eltype(heap, x), i)

@inline function setindex!(heap::AbstractBinaryHeap{T},
                           x::T, i::Int) where {T}
    @boundscheck checkbounds(heap, i)
    A = nodes(heap)
    @inbounds y = A[i] # replaced node
    o = ordering(heap)
    if lt(o, y, x)
        # Heap structure _above_ replaced node will remain valid, down-heapify
        # to fix the heap structure at and _below_ the node.
        unsafe_heapify_down!(o, A, i, x, length(heap))
    else
        # Heap structure _below_ replaced node will remain valid, up-heapify to
        # fix the heap structure at and _above_ the node.
        unsafe_heapify_up!(o, A, i, x)
    end
    return heap
end

first(heap::AbstractBinaryHeap) = peek(heap)

function peek(heap::AbstractBinaryHeap)
    isempty(heap) && throw(ArgumentError("heap is empty"))
    @inbounds r = getindex(nodes(heap), 1)
    return r
end

empty!(h::FastBinaryHeap) = (setfield!(h, :count, 0); h)
empty!(h::BinaryHeap) = (empty!(nodes(h)); h)

function pop!(heap::AbstractBinaryHeap)
    n = length(heap)
    n ≥ 1 || throw(ArgumentError("heap is empty"))
    A = nodes(heap)
    @inbounds x = A[1]
    if n > 1
        # Peek the last node and down-heapify starting at the root of the
        # binary heap to insert it.
        @inbounds y = A[n]
        unsafe_heapify_down!(ordering(heap), A, 1, y, n - 1)
    end
    unsafe_shrink!(heap, n - 1)
    return x
end

push!(heap::AbstractBinaryHeap, ::Tuple{}) = heap

function push!(heap::AbstractBinaryHeap, args...)
    for x in args
        push!(heap, x)
    end
    return heap
end

push!(heap::AbstractBinaryHeap, x) = push!(heap, to_eltype(heap, x))

function push!(heap::AbstractBinaryHeap{T}, x::T) where {T}
    n = length(heap) + 1
    unsafe_heapify_up!(ordering(heap), unsafe_grow!(heap, n), n, x)
    return heap
end

delete!(heap::AbstractBinaryHeap, i::Integer) = delete!(heap, to_int(i))

function delete!(heap::AbstractBinaryHeap, i::Int)
    n = length(heap)
    in_range(i, n) || throw_argument_error("out of range index")
    if i < n
        A = nodes(heap)
        o = ordering(heap)
        @inbounds x = A[n] # node to replace deleted node
        @inbounds y = A[i] # deleted node
        if lt(o, y, x)
            # Heap structure _above_ deleted node will remain valid,
            # down-heapify to fix the heap structure at and _below_ the
            # node.
            unsafe_heapify_down!(o, A, i, x, n - 1)
        else
            # Heap structure _below_ deleted node will remain valid,
            # up-heapify to fix the heap structure at and _above_ the node.
            unsafe_heapify_up!(o, A, i, x)
        end
    end
    unsafe_shrink!(heap, n - 1)
    return heap
end

"""
    unsafe_grow!(h, n) -> A

grows the size of the binary heap `h` to be `n` and returns the array `A`
backing the storage of the nodes.  This method is *unsafe* because it does not
check its arguments and because it breaks the binary heap structure of the
array of nodes.

This method is called by `push!` to grow the size of the heap and shall be
specialized for any concrete sub-types of `QuickHeaps.AbstractBinaryHeap`.

"""
unsafe_grow!(heap::BinaryHeap, n::Int) = resize!(nodes(heap), n)
unsafe_grow!(heap::FastBinaryHeap, n::Int) = begin
    A = nodes(heap)
    length(A) < n && resize!(A, n)
    setfield!(heap, :count, n)
    return A
end

"""
    unsafe_shrink!(h, n)

shrinks the size of the binary heap `h` to be `n`.  This method is *unsafe*
because it does not check its arguments.

This method is called by `delete!` to eventually reduce the size of the heap
and shall be specialized for any concrete sub-type of
[`QuickHeaps.AbstractBinaryHeap`](@ref).

"""
unsafe_shrink!(heap::BinaryHeap, n::Int) = resize!(nodes(heap), n)
unsafe_shrink!(heap::FastBinaryHeap, n::Int) = setfield!(heap, :count, n)

"""
    heapify!(h) -> h

reorders the nodes in the binary heap `h` in-place.  This method should be
called to initialize the heap or to re-order the heap if its contents have been
modified by other methods than `pop!` or `push!`.

The method can be called at a lower level to heapify (part of) an array storing
the heap values:

    heapify!(o, A, n=length(A)) -> A

reorders the `n` first elements of array `A` in-place to form a binary heap
according to the ordering specified by `o`.  The array `A` must have 1-based
linear indexing.

""" heapify!

function heapify!(heap::AbstractBinaryHeap)
    heapify!(ordering(heap), nodes(heap), length(heap))
    return heap
end

heapify!(o::Ordering, A::AbstractArray, n::Integer) = heapify!(o, A, to_int(n))

function heapify!(o::Ordering, A::AbstractArray, n::Int = length(A))
    # Heapify the n first elements of A.
    check_heap_storage(A, n)
    @inbounds for i in heap_parent(n):-1:1
        unsafe_heapify_down!(o, A, i, A[i], n)
    end
    return A
end

"""
    heapify(o, A, n=length(A))

yields an array with the `n` first values of array `A` stored in a binary heap
structure of ordering specified by `o`.  The storage of the returned heap is
a different array than `A`.

"""
heapify(o::Ordering, A::AbstractArray{T}, n::Integer = length(A)) where {T} =
    heapify!(o, copyto!(Vector{T}(undef, n), 1, A, 1, n))

"""
    isheap(o, A, n=length(A))

yields whether the `n` first elements of array `A` have a binary heap structure
ordered as specified by `o`.

    isheap(obj; check=false)

yields whether object `obj` is a binary heap.  If keyword `check` is true, the
internal structure of `obj` is checked; otherwise, the type of `obj` is trusted
to determine whether it is a binary heap.

"""
isheap(o::Ordering, A::AbstractArray, n::Integer) = isheap(o, A, to_int(n))

function isheap(o::Ordering, A::AbstractArray, n::Int = length(A))
    check_heap_storage(A, n)
    @inbounds for i in 1:div(n, 2)
        l = heap_left(i)
        r = heap_right(i)
        if lt(o, A[l], A[i]) || (r ≤ n && lt(o, A[r], A[i]))
            return false
        end
    end
    return true
end

isheap(heap::AbstractBinaryHeap; check::Bool = false) =
    if check
        isheap(ordering(heap), nodes(heap), length(heap))
    else
        true
    end

# Cope with different ordering of arguments and using the same default ordering
# as in base Julia and DataStructures.
for func in (:heapify, :heapify!, :isheap)
    @eval begin
        $func(A::AbstractArray) = $func(DefaultOrdering, A)
        $func(A::AbstractArray, n::Integer) = $func(DefaultOrdering, A, n)
        $func(A::AbstractArray, o::Ordering) = $func(o, A)
        $func(A::AbstractArray, o::Ordering, n::Integer) = $func(o, A, n)
        $func(A::AbstractArray, n::Integer, o::Ordering) = $func(o, A, n)
    end
end

"""
    heapify_down!(o, A, i, x=A[i], n=lengh(A))

stores the value `x` in the `i`-th node of the binary heap built into the `n`
first elements of array `A` with ordering `o` and, if needed, moves down the
inserted value to maintain the binary heap structure.

This method is called to *heapify* an array in order to initialize or rebuild
the heap structure or to replace the value of the root node of the heap and
update the heap structure.

"""
function heapify_down!(o::Ordering, A::AbstractArray,
                       i::Integer, x = A[i], n::Integer = length(A))
    heapify_down!(o, A, to_int(i), to_eltype(A, x), to_int(n))
end

function heapify_down!(o::Ordering, A::AbstractArray{T},
                       i::Int, x::T, n::Int) where {T}
    check_heap_storage(A, n)
    in_range(i, n) || throw_argument_error("out of range index")
    unsafe_heapify_down!(o, A, i, x, n)
end

"""
    unsafe_heapify_down!(o, A, i, x=A[i], n=lengh(A))

This method is a fast but *unsafe* version of
[`QuickHeaps.heapify_down!`](@ref) which assumes that all arguments are
correct, that is `A` implements 1-based linear indexing, `0 ≤ n ≤ lengh(A)`,
and `1 ≤ i ≤ n`.

"""
@inline function unsafe_heapify_down!(o::Ordering,
                                      A::AbstractArray{T},
                                      i::Int,
                                      x::T = (@inbounds A[i]),
                                      n::Int = length(A)) where {T}
    @inbounds begin
        while (l = heap_left(i)) ≤ n
            j = (r = heap_right(i)) > n || lt(o, A[l], A[r]) ? l : r
            lt(o, A[j], x) || break
            A[i] = A[j]
            i = j
        end
        A[i] = x
    end
end

"""
    heapify_up!(o, A, i, x=A[i])

stores the value `x` in the `i`-th node of the binary heap built into the
`n ≥ i` first elements of array `A` with ordering `o` and, if needed, moves
up the value to maintain the heap structure.

"""
function heapify_up!(o::Ordering, A::AbstractArray,
                     i::Integer, x = A[i])
    heapify_up!(o, A, to_int(i), to_eltype(A, x))
end

function heapify_up!(o::Ordering, A::AbstractArray{T}, i::Int, x::T) where {T}
    check_heap_storage(A)
    in_range(i, length(A)) || error("out of range index")
    unsafe_heapify_up!(o, A, i, x)
end

"""
    unsafe_heapify_up!(o, A, i, x=A[i])

This methods is a fast but *unsafe* version of [`QuickHeaps.heapify_up!`](@ref)
which assumes that all arguments are correct, that is `A` implements 1-based
linear indexing and `1 ≤ i ≤ length(A)`.

"""
@inline function unsafe_heapify_up!(o::Ordering,
                                    A::AbstractArray{T},
                                    i::Int,
                                    x::T = (@inbounds A[i])) where {T}
    @inbounds begin
        while (j = heap_parent(i)) ≥ 1 && lt(o, x, A[j])
            A[i] = A[j]
            i = j
        end
        A[i] = x
    end
end

"""
    check_heap_storage(A)

throws an exception if array `A` is not suitable for storing a binary heap,
that is if `A` does not have 1-based linear indexing.

    check_heap_storage(A, n)

throws an exception if the first elements of array `A` are not suitable for
storing a binary heap of size `n`.

"""
check_heap_storage(A::AbstractArray) = begin
    has_standard_linear_indexing(A) || throw(ArgumentError(
        "array storing a binary heap must have 1-based linear indexing"))
    nothing
end

check_heap_storage(A::AbstractArray, n::Int) = begin
    # Check that array has linear indexing and that 0 ≤ n ≤ length(A).
    check_heap_storage(A)
    (n % UInt) ≤ (length(A) % UInt) || throw_argument_error(
        "out of range heap size")
    nothing
end