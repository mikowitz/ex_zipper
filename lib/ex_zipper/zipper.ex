defmodule ExZipper.Zipper do
  @moduledoc """
  An Elixir implementation of [Huet's Zipper][huet], with gratitude to Rich Hickey's
  [Clojure implementation][clojure].

  Zippers provide a method of navigating and editing a tree while maintaining
  enough state data to reconstruct the tree from the currently focused node.

  Navigation and editing functions return a new `ExZipper.Zipper` struct, so
  they can be chained with `|>`. If a function can't be performed on the
  current focus (for example, moving down from a leaf or inserting a sibling
  next to the root), it raises an `ExZipper.Error` whose `:reason` says what
  went wrong. A chain stops at the first step that fails.

  [huet]: https://www.st.cs.uni-saarland.de/edu/seminare/2005/advanced-fp/docs/huet-zipper.pdf
  [clojure]: https://clojure.github.io/clojure/clojure.zip-api.html
  """

  alias ExZipper.Zipper

  defstruct [:focus, :crumbs, :functions]

  @type t :: %__MODULE__{focus: any(), crumbs: nil | :end | map(), functions: map()}

  @doc """
  Returns a new zipper with `root` as the root tree of the zipper, and
  `is_branch`, `children` and `make_node` as the internal functions that
  define construction parameters for the tree.

  In order, the arguments are

  1. a function to determine whether a node is a branch
  2. a function to return the children of a branch node
  3. a function to create a new node from an existing node and a new set of children
  4. the root node of the zipper

  ## Example

      iex> zipper = Zipper.zipper(               # zipper for nested lists
      ...>   &is_list/1,                         # a branch can have children, so, a list
      ...>   &(&1),                              # the children of a list is the list itself
      ...>   fn _node, children -> children end, # a new node is just the new list
      ...>   [1,[2,3,[4,5]]]
      ...> )
      iex> zipper.focus
      [1,[2,3,[4,5]]]

  """
  @spec zipper(
          (any() -> boolean),
          (any() -> [any()]),
          (any(), [any()] -> any()),
          any()
        ) :: Zipper.t()
  def zipper(is_branch, children, make_node, root) do
    %__MODULE__{
      focus: root,
      crumbs: nil,
      functions: %{
        branch?: is_branch,
        children: children,
        make_node: make_node
      }
    }
  end

  @doc """
  Returns a new zipper built from the given list

  ## Example

      iex> zipper = Zipper.list_zipper([1,[2,3,[4,5]]])
      iex> zipper.focus
      [1,[2,3,[4,5]]]

  """
  @spec list_zipper(list()) :: Zipper.t()
  def list_zipper(list) when is_list(list) do
    zipper(
      &is_list/1,
      & &1,
      fn _node, children -> children end,
      list
    )
  end

  @doc """
  Returns the current focus of the zipper

  ## Example

      iex> zipper = Zipper.list_zipper([1,[2,3,[4,5]]])
      iex> Zipper.node(zipper)
      [1,[2,3,[4,5]]]
      iex> zipper |> Zipper.down |> Zipper.node
      1

  """
  @spec node(Zipper.t()) :: any
  def node(%__MODULE__{focus: focus}), do: focus

  @doc """
  Returns to the root of the zipper. Remains in place if already on the root.

  This is also the only way to leave the end of a depth-first walk (see
  `end?/1`). Once a walk is exhausted, every function that moves or changes
  the zipper raises an `ExZipper.Error` until `root/1` is called.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.root |> Zipper.node
      [1,[],[2,3,[4,5]]]
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.down |> Zipper.root |> Zipper.node
      [1,[],[2,3,[4,5]]]
      iex> walked = Enum.reduce(1..9, zipper, fn _, z -> Zipper.next(z) end)
      iex> Zipper.end?(walked)
      true
      iex> walked |> Zipper.root |> Zipper.down |> Zipper.node
      1

  """
  @spec root(Zipper.t()) :: Zipper.t()
  def root(%__MODULE__{crumbs: nil} = zipper), do: zipper
  def root(%__MODULE__{crumbs: :end} = zipper), do: %{zipper | crumbs: nil}
  def root(%__MODULE__{} = zipper), do: zipper |> up |> root

  @doc """
  Returns all left siblings of the current focus. Raises an `ExZipper.Error`
  if called on the root or at the end of a walk.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.lefts
      []
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.lefts
      [1,[]]

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.lefts(zipper)
      ** (ExZipper.Error) Cannot query lefts of the root

  """
  @spec lefts(Zipper.t()) :: [any()]
  def lefts(%__MODULE__{crumbs: nil} = zipper), do: ExZipper.raise_error(:lefts_of_root, zipper)
  def lefts(%__MODULE__{crumbs: :end} = zipper), do: ExZipper.raise_error(:lefts_of_end, zipper)
  def lefts(%__MODULE__{crumbs: %{left: left}}), do: Enum.reverse(left)

  @doc """
  Returns all right siblings of the current focus. Raises an `ExZipper.Error`
  if called on the root or at the end of a walk.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.rights
      [[],[2,3,[4,5]]]
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.rights
      []

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.rights(zipper)
      ** (ExZipper.Error) Cannot query rights of the root

  """
  @spec rights(Zipper.t()) :: [any()]
  def rights(%__MODULE__{crumbs: nil} = zipper), do: ExZipper.raise_error(:rights_of_root, zipper)
  def rights(%__MODULE__{crumbs: :end} = zipper), do: ExZipper.raise_error(:rights_of_end, zipper)
  def rights(%__MODULE__{crumbs: %{right: right}}), do: right

  @doc """
  Returns a path of nodes leading from the root to, but excluding, the current
  focus. Returns an empty list at the root. Raises an `ExZipper.Error` at the
  end of a walk.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.path(zipper)
      []
      iex> zipper = zipper |> Zipper.down |> Zipper.rightmost |> Zipper.down
      iex> zipper.focus
      2
      iex> Zipper.path(zipper)
      [[1,[],[2,3,[4,5]]],[2,3,[4,5]]]

  """
  @spec path(Zipper.t()) :: [any()]
  def path(%__MODULE__{crumbs: nil}), do: []
  def path(%__MODULE__{crumbs: :end} = zipper), do: ExZipper.raise_error(:path_of_end, zipper)
  def path(%__MODULE__{crumbs: %{ppath: paths}}), do: Enum.reverse(paths)

  @doc """
  Returns true if the current focus of the zipper is a branch, even if it has
  no children, false otherwise.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.branch?(zipper)
      true
      iex> zipper |> Zipper.down |> Zipper.branch?
      false
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.branch?
      true

  """
  @spec branch?(Zipper.t()) :: boolean
  def branch?(%__MODULE__{} = zipper) do
    zipper.functions.branch?.(zipper.focus)
  end

  @doc """
  Returns the children of the current focus. Raises an `ExZipper.Error` if
  called on a leaf.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.children(zipper)
      [1,[],[2,3,[4,5]]]

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.children
      []

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.children
      ** (ExZipper.Error) Cannot query children of a leaf

  """
  @spec children(Zipper.t()) :: [any()]
  def children(%__MODULE__{} = zipper) do
    case branch?(zipper) do
      true -> zipper.functions.children.(zipper.focus)
      false -> ExZipper.raise_error(:children_of_leaf, zipper)
    end
  end

  @doc """
  Returns a new node created from `node` and `children`. The `zipper` first argument
  is to provide the context from which to determine how to create a new node.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.make_node(zipper, [8,9], [10,11,12])
      [10,11,12]

  """
  @spec make_node(Zipper.t(), any(), [any()]) :: any()
  def make_node(%__MODULE__{} = zipper, node, children) do
    zipper.functions.make_node.(node, children)
  end

  @doc """
  Returns true if a depth-first walkthrough of the zipper has been exhausted.

  A zipper at the end of a walk is focused on the root. Every function that
  moves or changes the zipper raises an `ExZipper.Error`, including `next/1`,
  `prev/1`, the editing functions and `map/2`. So do `lefts/1`, `rights/1` and
  `path/1`, which describe a position the end of a walk does not have. These
  still work: `node/1`, `branch?/1`, `children/1`, `end?/1`, `to_list/1`,
  `find/2` and `find_all/2`. Call `root/1` to start again.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper = zipper |> Zipper.next |> Zipper.next |> Zipper.next
      iex> Zipper.node(zipper)
      [2,3,[4,5]]
      iex> Zipper.end?(zipper)
      false
      iex> zipper = zipper |> Zipper.next |> Zipper.next |> Zipper.next |> Zipper.next |> Zipper.next |> Zipper.next
      iex> Zipper.node(zipper)
      [1,[],[2,3,[4,5]]]
      iex> Zipper.end?(zipper)
      true

  """
  @spec end?(Zipper.t()) :: boolean
  def end?(%__MODULE__{crumbs: :end}), do: true
  def end?(%__MODULE__{}), do: false

  @doc """
  Returns a flat list of all the elements in the zipper, ordered via a
  depth-first walk, including the root

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.to_list(zipper)
      [[1,[],[2,3,[4,5]]], 1, [], [2,3,[4,5]], 2, 3, [4,5], 4, 5]

  """
  @spec to_list(Zipper.t()) :: [any()]
  def to_list(%__MODULE__{} = zipper), do: _to_list(zipper, [])

  @doc """
  Moves to the leftmost child of the current focus. Raises an `ExZipper.Error`
  if the current focus is a leaf or an empty branch, or at the end of a walk.

  ## Example

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.node
      1

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.down
      ** (ExZipper.Error) Cannot move down into a leaf

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.down
      ** (ExZipper.Error) Cannot move down onto an empty branch

  """
  @spec down(Zipper.t()) :: Zipper.t()
  defdelegate down(zipper), to: ExZipper.Zipper.Navigation

  @doc """
  Moves up to the parent of the current focus. Raises an `ExZipper.Error` if
  already at the root of the zipper, or at the end of a walk.

  ## Example

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.up |> Zipper.node
      [1,[],[2,3,[4,5]]]

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.up(zipper)
      ** (ExZipper.Error) Cannot move up from the root

  """
  @spec up(Zipper.t()) :: Zipper.t()
  defdelegate up(zipper), to: ExZipper.Zipper.Navigation

  @doc """
  Moves to the next sibling to the right of the current focus. Raises an
  `ExZipper.Error` if at the root, already at the rightmost sibling at its
  depth in the tree, or at the end of a walk.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.node
      []

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.right |> Zipper.right
      ** (ExZipper.Error) Cannot move right from the rightmost member

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.right(zipper)
      ** (ExZipper.Error) Cannot move right from the root

  """
  @spec right(Zipper.t()) :: Zipper.t()
  defdelegate right(zipper), to: ExZipper.Zipper.Navigation

  @doc """
  Moves to the next sibling to the left of the current focus. Raises an
  `ExZipper.Error` if at the root, already at the leftmost sibling at its
  depth in the tree, or at the end of a walk.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.left
      ** (ExZipper.Error) Cannot move left from the leftmost member

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.right |> Zipper.left |> Zipper.node
      []

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.left(zipper)
      ** (ExZipper.Error) Cannot move left from the root

  """
  @spec left(Zipper.t()) :: Zipper.t()
  defdelegate left(zipper), to: ExZipper.Zipper.Navigation

  @doc """
  Moves to the rightmost sibling at the same depth as the current focus. Remains
  in place if already focused on the rightmost sibling. Raises an
  `ExZipper.Error` if called on the root or at the end of a walk.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.rightmost|> Zipper.node
      [2,3,[4,5]]
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.rightmost |> Zipper.node
      [2,3,[4,5]]

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.rightmost(zipper)
      ** (ExZipper.Error) Cannot call rightmost from the root

  """
  @spec rightmost(Zipper.t()) :: Zipper.t()
  defdelegate rightmost(zipper), to: ExZipper.Zipper.Navigation

  @doc """
  Moves to the leftmost sibling at the same depth as the current focus. Remains
  in place if already focused on the leftmost sibling. Raises an
  `ExZipper.Error` if called on the root or at the end of a walk.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.leftmost |> Zipper.node
      1
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.right |> Zipper.leftmost |> Zipper.node
      1

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.leftmost(zipper)
      ** (ExZipper.Error) Cannot call leftmost from the root

  """
  @spec leftmost(Zipper.t()) :: Zipper.t()
  defdelegate leftmost(zipper), to: ExZipper.Zipper.Navigation

  @doc """
  Moves to the next focus in a depth-first walk through the zipper. After the
  last node, `next` returns a zipper at the end of the walk, focused on the
  root (see `end?/1`). Calling `next` again, or any other function that moves
  or changes the zipper, raises an `ExZipper.Error`. Call `root/1` to start
  again.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.next |> Zipper.node
      1
      iex> zipper |> Zipper.next |> Zipper.next |> Zipper.node
      []
      iex> zipper |> Zipper.next |> Zipper.next
      ...> |> Zipper.next |> Zipper.next |> Zipper.node
      2
      iex> zipper = zipper |> Zipper.down |> Zipper.rightmost
      ...> |> Zipper.down |> Zipper.rightmost
      ...> |> Zipper.down |> Zipper.rightmost
      iex> zipper |> Zipper.next |> Zipper.node
      [1,[],[2,3,[4,5]]]
      iex> zipper |> Zipper.next |> Zipper.next
      ** (ExZipper.Error) Cannot call next from the end

  """
  @spec next(Zipper.t()) :: Zipper.t()
  defdelegate next(zipper), to: ExZipper.Zipper.Navigation

  @doc """
  Moves to the previous focus in a depth-first walk through the zipper. Raises
  an `ExZipper.Error` if called at the end of the walk. Returns the root if
  called on the root.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.prev |> Zipper.node
      [1,[],[2,3,[4,5]]]
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.prev |> Zipper.node
      []

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.down |> Zipper.rightmost
      ...> |> Zipper.down |> Zipper.rightmost |> Zipper.next |> Zipper.prev
      ** (ExZipper.Error) Cannot call previous from the end

  """
  @spec prev(Zipper.t()) :: Zipper.t()
  defdelegate prev(zipper), to: ExZipper.Zipper.Navigation

  @doc """
  Inserts a new node as a new sibling to the immediate right of the current focus.
  Does not change focus. Raises an `ExZipper.Error` if called on the root or
  at the end of a walk.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.insert_right(0) |> Zipper.root |> Zipper.node
      [1,0,[],[2,3,[4,5]]]

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.insert_right(zipper, 0)
      ** (ExZipper.Error) Cannot insert to the right of the root

  """
  @spec insert_right(Zipper.t(), any()) :: Zipper.t()
  defdelegate insert_right(zipper, node), to: ExZipper.Zipper.Editing

  @doc """
  Inserts a new node as a new sibling to the immediate left of the current focus.
  Does not change focus. Raises an `ExZipper.Error` if called on the root or
  at the end of a walk.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.insert_left(0) |> Zipper.root |> Zipper.node
      [0,1,[],[2,3,[4,5]]]

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.insert_left(zipper, 0)
      ** (ExZipper.Error) Cannot insert to the left of the root

  """
  @spec insert_left(Zipper.t(), any()) :: Zipper.t()
  defdelegate insert_left(zipper, node), to: ExZipper.Zipper.Editing

  @doc """
  Inserts a child as the leftmost child of the current focus. Raises an
  `ExZipper.Error` if called on a leaf or at the end of a walk.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.insert_child(6) |> Zipper.node
      [6,1,[],[2,3,[4,5]]]

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.insert_child(6)
      ** (ExZipper.Error) Cannot insert a child into a leaf

  """
  @spec insert_child(Zipper.t(), any()) :: Zipper.t()
  defdelegate insert_child(zipper, node), to: ExZipper.Zipper.Editing

  @doc """
  Appends a child as the rightmost child of the current focus. Raises an
  `ExZipper.Error` if called on a leaf or at the end of a walk.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.append_child(6) |> Zipper.node
      [1,[],[2,3,[4,5]],6]

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.append_child(6)
      ** (ExZipper.Error) Cannot append a child to a leaf

  """
  @spec append_child(Zipper.t(), any()) :: Zipper.t()
  defdelegate append_child(zipper, node), to: ExZipper.Zipper.Editing

  @doc """
  Replaces the current focus with the node passed as the second argument.
  Raises an `ExZipper.Error` at the end of a walk.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper = Zipper.down(zipper)
      iex> Zipper.node(zipper)
      1
      iex> zipper = Zipper.replace(zipper, 10)
      iex> Zipper.node(zipper)
      10

  """
  @spec replace(Zipper.t(), any()) :: Zipper.t()
  defdelegate replace(zipper, node), to: ExZipper.Zipper.Editing

  @doc """
  Replaces the current focus with the result of applying the given function
  to the current focus. Raises an `ExZipper.Error` at the end of a walk.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper = Zipper.down(zipper)
      iex> Zipper.node(zipper)
      1
      iex> zipper = Zipper.edit(zipper, &(&1 * 10))
      iex> Zipper.node(zipper)
      10

  """
  @spec edit(Zipper.t(), (any() -> any())) :: Zipper.t()
  defdelegate edit(zipper, node), to: ExZipper.Zipper.Editing

  @doc """
  Removes the current focus from the zipper, moving focus to the node previous
  to the current focus in a depth-first walk. Raises an `ExZipper.Error` if
  called on the root or at the end of a walk.

  If the removed node has a left sibling, focus moves to the deepest rightmost
  descendant of that sibling, or to the sibling itself if it is a leaf or an
  empty branch. Otherwise focus moves to the parent, which no longer contains
  the removed node.

  ## Examples

  Removing the leftmost child moves focus to the parent, without that child:

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.remove |> Zipper.node
      [[],[2,3,[4,5]]]

  Removing a node whose left sibling is a branch moves focus to the last node
  inside that branch:

      iex> zipper = Zipper.list_zipper([1,[2,[3,4]],5])
      iex> zipper = zipper |> Zipper.down |> Zipper.rightmost |> Zipper.remove
      iex> Zipper.node(zipper)
      4
      iex> zipper |> Zipper.root |> Zipper.node
      [1,[2,[3,4]]]

  Removing a node whose left sibling is a leaf or an empty branch moves focus
  to that sibling:

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.remove |> Zipper.node
      []

  Removing the root raises:

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.remove(zipper)
      ** (ExZipper.Error) Cannot remove root

  """
  @spec remove(Zipper.t()) :: Zipper.t()
  defdelegate remove(zipper), to: ExZipper.Zipper.Editing

  @doc """
  Walks the zipper depth-first from the current focus. Returns a zipper
  focused on the first node for which `fun` returns a truthy value. Returns
  `nil` if no node matches before the walk ends.

  The current focus is checked first, so to find the next match after the
  one you have, call `next/1` first.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.find(&(is_integer(&1) and &1 > 2)) |> Zipper.node
      3
      iex> zipper |> Zipper.find(&(&1 == [4,5])) |> Zipper.path
      [[1,[],[2,3,[4,5]]],[2,3,[4,5]]]
      iex> Zipper.find(zipper, &(&1 == 6))
      nil

  The search starts at the current focus, so it finds the focus itself if it
  matches. Nodes that come before the focus in the walk are not checked:

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper = Zipper.find(zipper, &is_integer/1)
      iex> Zipper.node(zipper)
      1
      iex> zipper |> Zipper.find(&is_integer/1) |> Zipper.node
      1
      iex> zipper |> Zipper.next |> Zipper.find(&is_integer/1) |> Zipper.node
      2
      iex> zipper |> Zipper.next |> Zipper.find(&(&1 == 1))
      nil

  """
  @spec find(Zipper.t(), (any() -> as_boolean(any()))) :: Zipper.t() | nil
  defdelegate find(zipper, fun), to: ExZipper.Zipper.Traversal

  @doc """
  Walks the zipper depth-first from the current focus. Returns a list of
  zippers, one focused on each node for which `fun` returns a truthy value,
  in walk order. Returns an empty list if nothing matches.

  Each zipper in the list is a separate snapshot of the tree. Editing one
  does not change the others.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.find_all(&is_integer/1) |> Enum.map(&Zipper.node/1)
      [1,2,3,4,5]
      iex> zipper |> Zipper.find_all(&is_list/1) |> Enum.map(&Zipper.node/1)
      [[1,[],[2,3,[4,5]]],[],[2,3,[4,5]],[4,5]]
      iex> Zipper.find_all(zipper, &(&1 == 6))
      []

  The walk starts at the current focus:

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper
      ...> |> Zipper.find(&(&1 == 3))
      ...> |> Zipper.find_all(&is_integer/1)
      ...> |> Enum.map(&Zipper.node/1)
      [3,4,5]

  """
  @spec find_all(Zipper.t(), (any() -> as_boolean(any()))) :: [Zipper.t()]
  defdelegate find_all(zipper, fun), to: ExZipper.Zipper.Traversal

  @doc """
  Replaces every node visited by a depth-first walk with the result of
  calling `fun` on it, and returns a zipper focused on the (updated) root.
  Raises an `ExZipper.Error` if called at the end of a walk. A walk that
  starts before the end runs to completion.

  `fun` is called on branches as well as leaves, so it must handle every kind
  of node in the tree. A branch is updated before its children are visited,
  so the walk goes into the children of the branch `fun` returns, not the
  original one.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper
      ...> |> Zipper.map(fn
      ...>   n when is_integer(n) -> n * 10
      ...>   list -> list
      ...> end)
      ...> |> Zipper.node
      [10,[],[20,30,[40,50]]]

  Because branches are updated first, `fun` can change which children get
  visited:

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper
      ...> |> Zipper.map(fn
      ...>   n when is_integer(n) -> n * 10
      ...>   list -> Enum.reverse(list)
      ...> end)
      ...> |> Zipper.node
      [[[50,40],30,20],[],10]

  The walk starts at the current focus, so nodes before it are left alone:

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper
      ...> |> Zipper.find(&(&1 == 3))
      ...> |> Zipper.map(fn
      ...>   n when is_integer(n) -> n * 10
      ...>   list -> list
      ...> end)
      ...> |> Zipper.node
      [1,[],[2,30,[40,50]]]

  """
  @spec map(Zipper.t(), (any() -> any())) :: Zipper.t()
  defdelegate map(zipper, fun), to: ExZipper.Zipper.Traversal

  ## Private

  defp _to_list(zipper, acc) do
    case end?(zipper) do
      true -> Enum.reverse(acc)
      false -> _to_list(next(zipper), [__MODULE__.node(zipper) | acc])
    end
  end
end
