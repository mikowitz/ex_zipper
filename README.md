# ExZipper

An Elixir implementation of Huet's Zipper[1], with gratitude to Rich Hickey's
Clojure implementation[2].

[1]: https://www.st.cs.uni-saarland.de/edu/seminare/2005/advanced-fp/docs/huet-zipper.pdf
[2]: https://clojure.github.io/clojure/clojure.zip-api.html

## Installation

```elixir
@deps [
  ex_zipper: "~> 0.1.2"
]
```

## Usage

Below is an outline of the API provided by `ExZipper.Zipper`. See the full
documentation [here](http://hexdocs.pm/ex_zipper/ExZipper.Zipper.html) for usage examples

### Creating zippers

`ExZipper` provides one zipper construction function for working with plain lists,
`ExZipper.Zipper.list_zipper/1`

    iex> Zipper.list_zipper([1,[],2,[3,[4,5]]])

For more complex cases, `ExZipper.Zipper.zipper/4` provides a mechanism to
define your own zipper, passing for its first three arguments functions to

1. determine whether a node is a branch
1. return the children of a branch node
1. create a new node from an existing node and a new set of children

and your root data structure as its fourth argument.

For example, to create a zipper for a data structure of nested maps,
where a branch's children are defined under the `:kids` key:

      iex> Zipper.zipper(
      ...>   fn node -> is_map(node) and Map.has_key?(node, :kids) end,
      ...>   fn %{kids: kids} -> kids end,
      ...>   fn node, new_kids -> %{node | kids: new_kids} end,
      ...>   %{ value: "top", kids: [%{value: "first inner"}, %{value: "last inner}]}
      ...> )

### Navigating zippers

The following functions move through a zipper and return either a new zipper,
or an error of the form `{:error, :atom_describing_the_error}`

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
  walk. At this point, the walk has been exhausted, and cannot be reversed.

### Editing zippers

The following functions modify the zipper without shifting focus away
from the current node. They will return a zipper, or an error, if called
with an invalid zipper as input (for example, trying to insert a child into
a leaf node)

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
* `Zipper.lefts` returns a list of the current node's left siblings
* `Zipper.rights` returns a list of the current node's right siblings
* `Zipper.path` returns a list of nodes creating a path from the root down to,
  but excluding, the current node

* `Zipper.branch?` returns true if the current node is a branch (that is, if it
  can have children, even if it currently does not have any)
* `Zipper.children` returns a list of the current node's children, or an error
  if called on a leaf
* `Zipper.make_node` takes a zipper, a node, and a list of children and returns
  a new node constructed from the second and third arguments. The first argument,
  the zipper, is passed only to provide context on how to construct the new node.

## License

Standard MIT. See LICENSE.md

----
Created:  2017-11-16Z
