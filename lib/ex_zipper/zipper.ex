defmodule ExZipper.Zipper do
  @moduledoc """
  An Elixir implementation of [Huet's Zipper][huet], with gratitude to Rich Hickey's
  [Clojure implementation][clojure].

  Zippers provide a method of navigating and editing a tree while maintaining
  enough state data to reconstruct the tree from the currently focused node.

  For the most part, functions defined on `ExZipper.Zipper` return either an
  `ExZipper.Zipper` struct or an error tuple of the form `{:error, :error_type}`,
  if the function tries to move to a point on the tree that doesn't exist.
  This allows easy chaining of functions with a quick failure mode if any function
  in the chain returns an error.

  [huet]: https://www.st.cs.uni-saarland.de/edu/seminare/2005/advanced-fp/docs/huet-zipper.pdf
  [clojure]: https://clojure.github.io/clojure/clojure.zip-api.html
  """

  defstruct [:focus, :crumbs, :functions]

  @type t :: %__MODULE__{focus: any(), crumbs: nil | map(), functions: map()}
  @type error :: {:error, atom}
  @type maybe_zipper :: t | error

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
  ) :: t
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
  @spec list_zipper(list()) :: t
  def list_zipper(list) when is_list(list) do
    zipper(
      &is_list/1,
      &(&1),
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
  @spec node(t) :: any
  def node(%__MODULE__{focus: focus}), do: focus

  @doc """
  Returns to the root of the zipper. Remains in place if already on the root.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.root |> Zipper.node
      [1,[],[2,3,[4,5]]]
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.down |> Zipper.root |> Zipper.node
      [1,[],[2,3,[4,5]]]

  """
  @spec root(t) :: t
  def root(zipper = %__MODULE__{crumbs: nil}), do: zipper
  def root(zipper = %__MODULE__{}), do: zipper |> up |> root

  @doc """
  Returns all left siblings of the current focus. Returns an error if called
  on the root.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.lefts(zipper)
      {:error, :lefts_of_root}
      iex> zipper |> Zipper.down |> Zipper.lefts
      []
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.lefts
      [1,[]]

  """
  @spec lefts(t) :: [any()] | error
  def lefts(%__MODULE__{crumbs: nil}), do: {:error, :lefts_of_root}
  def lefts(%__MODULE__{crumbs: %{left: left}}), do: Enum.reverse(left)

  @doc """
  Returns all left right of the current focus. Returns an error if called
  on the root.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.rights(zipper)
      {:error, :rights_of_root}
      iex> zipper |> Zipper.down |> Zipper.rights
      [[],[2,3,[4,5]]]
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.rights
      []

  """
  @spec rights(t) :: [any()] | error
  def rights(%__MODULE__{crumbs: nil}), do: {:error, :rights_of_root}
  def rights(%__MODULE__{crumbs: %{right: right}}), do: right

  @doc """
  Returns a path of nodes leading from the root to, but excluding, the current
  focus. Returns an empty list at the root.

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
  @spec path(t) :: [any()]
  def path(%__MODULE__{crumbs: nil}), do: []
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
  @spec branch?(t) :: boolean
  def branch?(zipper = %__MODULE__{}) do
    zipper.functions.branch?.(zipper.focus)
  end

  @doc """
  Returns the children of the current focus, or an error if called on a leaf.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.children(zipper)
      [1,[],[2,3,[4,5]]]
      iex> zipper |> Zipper.down |> Zipper.children
      {:error, :children_of_leaf}
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.children
      []

  """
  @spec children(t) :: [any()] | error
  def children(zipper = %__MODULE__{}) do
    case branch?(zipper) do
      true -> zipper.functions.children.(zipper.focus)
      false -> {:error, :children_of_leaf}
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
  @spec make_node(t, any(), [any()]) :: any()
  def make_node(zipper = %__MODULE__{}, node, children) do
    zipper.functions.make_node.(node, children)
  end


  @doc """
  Returns true if a depth-first walkthrough of the zipper has been exhausted.

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
  @spec end?(t) :: boolean
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
  @spec to_list(t) :: [any()]
  def to_list(zipper = %__MODULE__{}), do: _to_list(zipper, [])

  defdelegate down(zipper), to: ExZipper.Zipper.Navigation
  defdelegate up(zipper), to: ExZipper.Zipper.Navigation
  defdelegate right(zipper), to: ExZipper.Zipper.Navigation
  defdelegate left(zipper), to: ExZipper.Zipper.Navigation
  defdelegate rightmost(zipper), to: ExZipper.Zipper.Navigation
  defdelegate leftmost(zipper), to: ExZipper.Zipper.Navigation
  defdelegate next(zipper), to: ExZipper.Zipper.Navigation
  defdelegate prev(zipper), to: ExZipper.Zipper.Navigation

  defdelegate insert_right(zipper, node), to: ExZipper.Zipper.Editing
  defdelegate insert_left(zipper, node), to: ExZipper.Zipper.Editing
  defdelegate insert_child(zipper, node), to: ExZipper.Zipper.Editing
  defdelegate append_child(zipper, node), to: ExZipper.Zipper.Editing
  defdelegate replace(zipper, node), to: ExZipper.Zipper.Editing
  defdelegate edit(zipper, node), to: ExZipper.Zipper.Editing
  defdelegate remove(zipper), to: ExZipper.Zipper.Editing

  ## Private

  defp _to_list(zipper, acc) do
    case end?(zipper) do
      true -> Enum.reverse(acc)
      false -> _to_list(next(zipper), [__MODULE__.node(zipper)|acc])
    end
  end
end
