# User visible changes in QuickHeaps

## Version 0.2.0

- Provide `dequeue_node!` which removes the root node from a priority queue and
  returns it. This is similar to `dequeue_pair!` or `pop!` which both return a
  `Pair`. The syntax `dequeue(T,pq)!` to remove the root node from `pq` and
  return it converted to type `T` is no longer supported; call
  `T(dequeue_node!(pq))` or `convert(T, dequeue_node!(pq))` instead.

- The noun *node* is replaced by *value* for a binary-heap. The non-exported
  method `QuickHeaps.nodes(h)` has been renamed as `QuickHeaps.storage(h)` to
  retrieve the object backing the storage of the binary heap `h`.

- Change parameters of priority queue types which are now
  `AbstractPriorityQueue{K,V,O}`, `PriorityQueue{K,V,O,T}`, and
  `FastPriorityQueue{V,N,O,T}` with `K` the type of the keys, `V` the type of
  the priority values, `O` the type of the ordering, `T<:AbstractNode{K,V}` the
  type of the nodes, and `N` the number of dimensions.

- `get(pq,key,def)` yields the value (was the node) associated with `key` in
  priority queue `pq` or `def` if such a key does not exist.

- `heapify_down!` and `heapify_up!` return the array.

- Remove unused non-exported methods `unsafe_heapify!`,
  `require_one_based_indexing`, ...


## Version 0.1.2

- Fix a few bugs.
- provide docs.
- Extend tests.