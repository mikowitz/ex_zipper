# ExZipper

An Elixir implementation of [Huet's Zipper][huet], with gratitude to Rich Hickey's
[Clojure implementation][clojure].

## Installation

```elixir
@deps [
  ex_zipper: "~> 1.0"
]
```

## Usage

Below is an outline of the API provided by `ExZipper.Zipper`. See the full
documentation [here](https://hexdocs.pm/ex_zipper/ExZipper.Zipper.html) for usage examples

### Creating zippers

`ExZipper.Zipper` provides one zipper construction function for working with plain lists,
`ExZipper.Zipper.list_zipper/1`

    iex> Zipper.list_zipper([1,[],2,[3,[4,5]]])

For more complex cases, `ExZipper.Zipper.zipper/4` provides a mechanism to
define your own zipper, passing for its first three arguments functions to

1. determine whether a node is a branch
2. return the children of a branch node
3. create a new node from an existing node and a new set of children

and your root data structure as its fourth argument.

For example, to create a zipper for a data structure of nested maps,
where a branch's children are defined under the `:kids` key:

      iex> Zipper.zipper(
      ...>   fn node -> is_map(node) and Map.has_key?(node, :kids) end,
      ...>   fn %{kids: kids} -> kids end,
      ...>   fn node, new_kids -> %{node | kids: new_kids} end,
      ...>   %{ value: "top", kids: [%{value: "first inner"}, %{value: "last inner"}]}
      ...> )

### Navigating zippers

The following functions move through a zipper and return a new zipper. If the
move is impossible (for example, moving down from a leaf), they raise an
`ExZipper.Error` whose `:reason` field describes what went wrong.

* `Zipper.down` moves to the first (leftmost) child of the current node
* `Zipper.up` moves to the parent of the current node
* `Zipper.right` moves to the next sibling on the right of the current node
* `Zipper.left` moves to the next sibling on the left of the current node
* `Zipper.rightmost` moves to the furthest right sibling of the current node,
  or remains in place if already focused on the rightmost sibling
* `Zipper.leftmost` moves to the furthest left sibling of the current node,
  or remains in place if already focused on the leftmost sibling
* `Zipper.root` traverses the zipper all the way back to the root node, or
  remains in place if already focused on the root

The following functions move through a zipper via a depth-first walk. That is,
moving as deep down one branch of the tree before moving laterally.

* `Zipper.next` moves to the next node, preferring to move to a child over a sibling
* `Zipper.prev` moves back up through a depth-first ordering of the tree
* `Zipper.end?` returns `true` if the zipper has reached the end of a depth-first
  walk. At this point, the walk has been exhausted: it cannot be reversed with
  `Zipper.prev`, and other navigation functions raise an `ExZipper.Error`.
  Call `Zipper.root` to start navigating again.

### Searching and transforming zippers

The following functions walk the zipper depth-first, like `Zipper.next`. Each
walk starts at the current focus, not at the root, and visits the current
focus, its descendants, and every node after it in the walk.

* `Zipper.find/2` returns a zipper focused on the first node for which the
  given function returns a truthy value, or `nil` if nothing matches. The
  current focus is checked first, so call `Zipper.next` before searching again
  to find the following match
* `Zipper.find_all/2` returns a list of zippers, one focused on each matching
  node, in walk order. Each is a separate snapshot, so editing one does not
  change the others
* `Zipper.map/2` replaces every node in the walk with the result of calling
  the given function on it, and returns a zipper focused on the root. The
  function is called on branches as well as leaves, and a branch is updated
  before its children are visited

```elixir
iex> zipper = Zipper.list_zipper([1, [], [2, 3, [4, 5]]])
iex> zipper |> Zipper.find(&(is_integer(&1) and &1 > 2)) |> Zipper.node
3
iex> zipper |> Zipper.find_all(&is_integer/1) |> Enum.map(&Zipper.node/1)
[1, 2, 3, 4, 5]
iex> zipper |> Zipper.map(fn n when is_integer(n) -> -n; list -> list end) |> Zipper.node()
[-1, [], [-2, -3, [-4, -5]]]
```

### Editing zippers

The following functions modify the zipper without shifting focus away
from the current node. They return a zipper, or raise an `ExZipper.Error` if
the edit is impossible (for example, trying to insert a child into a leaf node)

* `Zipper.insert_child` inserts a new child as the first (leftmost) child
  of the current node, without moving focus from the current node
* `Zipper.append_child` inserts a new child as the last (rightmost) child
  of the current node, without moving focus from the current node
* `Zipper.insert_left` inserts a new node as the sibling immediately to
  the left of the current node, without moving focus from the current node
* `Zipper.insert_right` inserts a new node as the sibling immediately to
  the right of the current node, without moving focus from the current node
* `Zipper.replace/2` replaces the zipper's current node with the new node passed
  to this function as the second argument
* `Zipper.edit/2` replaces the zipper's current node with the result of calling
  the function passed as a second argument on the current node
* `Zipper.remove/1` removes the current node from the zipper, returning a zipper
  focused on the previous node (via a depth-first walk)

### Helper functions

* `Zipper.node/1` returns the zipper's current node
* `Zipper.lefts/1` returns a list of the current node's left siblings
* `Zipper.rights/1` returns a list of the current node's right siblings
* `Zipper.path/1` returns a list of nodes creating a path from the root down to,
  but excluding, the current node
* `Zipper.to_list/1` returns a depth-first walk ordered list of a zipper's elements

* `Zipper.branch?` returns true if the current node is a branch (that is, if it
  can have children, even if it currently does not have any)
* `Zipper.children` returns a list of the current node's children, or raises an
  `ExZipper.Error` if called on a leaf
* `Zipper.make_node` takes a zipper, a node, and a list of children and returns
  a new node constructed from the second and third arguments. The first argument,
  the zipper, is passed only to provide context on how to construct the new node.

## License

This library is released under the [UNLICENSE](https://github.com/mikowitz/ex_zipper/blob/main/UNLICENSE).

[huet]: https://www.st.cs.uni-saarland.de/edu/seminare/2005/advanced-fp/docs/huet-zipper.pdf
[clojure]: https://clojure.github.io/clojure/clojure.zip-api.html
