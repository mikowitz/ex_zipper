defmodule ExZipper.Zipper do
  @moduledoc """
  An Elixir implementation of Huet's Zipper[1], with gratitude to Rich Hickey's
  Clojure implementation[2].

  Zippers provide a method of navigating and editing a tree while maintaining
  enough state data to reconstruct the tree from the currently focused node.

  For the most part, functions defined on `ExZipper.Zipper` return either an
  `ExZipper.Zipper` struct or an error tuple of the form `{:error, :error_type}`,
  if the function tries to move to a point on the tree that doesn't exist.
  This allows easy chaining of functions with a quick failure mode if any function
  in the chain returns an error.

  [1]: https://www.st.cs.uni-saarland.de/edu/seminare/2005/advanced-fp/docs/huet-zipper.pdf
  [2]: https://clojure.github.io/clojure/clojure.zip-api.html
  """

  defstruct [:focus, :crumbs, :functions]

  @type t :: %__MODULE__{focus: any(), crumbs: nil | map(), functions: map()}
  @type error :: {:error, atom}
  @type maybe_zipper :: Zipper.t | Zipper.error

  @doc """
  Returns a new zipper with `root` as the root tree of the zipper, and
  `is_branch`, `children` and `make_node` as the internal functions that
  define construction parameters for the tree.

  In order, the arguments are

  1. a function to determine whether a node is a branch
  1. a function to return the children of a branch node
  1. a function to create a new node from an existing node and a new set of children
  1. the root node of the zipper

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
  ) :: Zipper.t
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
  @spec list_zipper(list()) :: Zipper.t
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
  @spec node(Zipper.t) :: any
  def node(%__MODULE__{focus: focus}), do: focus

  @doc """
  Moves to the leftmost child of the current focus, or returns an error if
  the current focus is a leaf or an empty branch.

  ## Example

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.node
      1
      iex> zipper |> Zipper.down |> Zipper.down
      {:error, :down_from_leaf}
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.down
      {:error, :down_from_empty_branch}

  """
  @spec down(Zipper.t) :: Zipper.maybe_zipper
  def down(zipper = %__MODULE__{}) do
    case branch?(zipper) do
      false ->
        {:error, :down_from_leaf}

      true ->
        case children(zipper) do
          [] ->
            {:error, :down_from_empty_branch}

          [new_focus | new_right] ->
            %__MODULE__{
              focus: new_focus,
              crumbs: %{
                left: [],
                right: new_right,
                pnodes: zipper.crumbs,
                ppath:
                  case zipper.crumbs do
                    nil -> [zipper.focus]
                    crumbs -> [zipper.focus | crumbs.ppath]
                  end
              },
              functions: zipper.functions
            }
        end
    end
  end

  @doc """
  Moves up to the parent of the current focus, or returns an error if already
  at the root of the zipper

  ## Example

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.up(zipper)
      {:error, :up_from_root}
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.up |> Zipper.node
      [1,[],[2,3,[4,5]]]

  """
  @spec up(Zipper.t) :: Zipper.maybe_zipper
  def up(%__MODULE__{crumbs: nil}), do: {:error, :up_from_root}
  def up(zipper = %__MODULE__{}) do
    new_children = Enum.reverse(zipper.crumbs.left) ++
      [zipper.focus | zipper.crumbs.right]
    [new_focus | _] = zipper.crumbs.ppath
    new_focus = make_node(zipper, new_focus, new_children)
    %{zipper | focus: new_focus, crumbs: zipper.crumbs.pnodes}
  end

  @doc """
  Moves to the next sibling to the right of the current focus. Returns an error
  if at the root or already at the rightmost sibling at its depth in the tree.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.right(zipper)
      {:error, :right_from_root}
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.node
      []
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.right |> Zipper.right
      {:error, :right_from_rightmost}

  """
  @spec right(Zipper.t) :: Zipper.maybe_zipper
  def right(%__MODULE__{crumbs: nil}), do: {:error, :right_from_root}
  def right(%__MODULE__{crumbs: %{right: []}}) do
    {:error, :right_from_rightmost}
  end
  def right(zipper = %__MODULE__{}) do
    [new_focus | new_right] = zipper.crumbs.right
    new_left = [zipper.focus | zipper.crumbs.left]
    %{zipper |
      focus: new_focus,
      crumbs: %{zipper.crumbs |
        left: new_left,
        right: new_right
      }
    }
  end

  @doc """
  Moves to the next sibling to the left of the current focus. Returns an error
  if at the root or already at the leftmost sibling at its depth in the tree.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.left(zipper)
      {:error, :left_from_root}
      iex> zipper |> Zipper.down |> Zipper.left
      {:error, :left_from_leftmost}
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.right |> Zipper.left |> Zipper.node
      []

  """
  @spec left(Zipper.t) :: Zipper.maybe_zipper
  def left(%__MODULE__{crumbs: nil}), do: {:error, :left_from_root}
  def left(%__MODULE__{crumbs: %{left: []}}), do: {:error, :left_from_leftmost}
  def left(zipper = %__MODULE__{}) do
    [new_focus | new_left] = zipper.crumbs.left
    new_right = [zipper.focus | zipper.crumbs.right]
    %{zipper |
      focus: new_focus,
      crumbs: %{zipper.crumbs |
        left: new_left,
        right: new_right
      }
    }
  end

  @doc """
  Moves to the leftmost sibling at the same depth as the current focus. Remains
  in place if already focused on the leftmost sibling. Returns an error if
  called on the root.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.rightmost(zipper)
      {:error, :rightmost_from_root}
      iex> zipper |> Zipper.down |> Zipper.rightmost|> Zipper.node
      [2,3,[4,5]]
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.rightmost |> Zipper.node
      [2,3,[4,5]]

  """
  @spec rightmost(Zipper.t) :: Zipper.maybe_zipper
  def rightmost(%__MODULE__{crumbs: nil}), do: {:error, :rightmost_from_root}
  def rightmost(zipper = %__MODULE__{crumbs: %{right: []}}), do: zipper
  def rightmost(zipper = %__MODULE__{}) do
    {new_focus, old_right} = List.pop_at(zipper.crumbs.right, -1)
    new_left = Enum.reverse(old_right) ++ [zipper.focus | zipper.crumbs.left]
    %{zipper |
      focus: new_focus,
      crumbs: %{zipper.crumbs | left: new_left, right: []}
    }
  end

  @doc """
  Moves to the leftmost sibling at the same depth as the current focus. Remains
  in place if already focused on the leftmost sibling. Returns an error if
  called on the root.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.leftmost(zipper)
      {:error, :leftmost_from_root}
      iex> zipper |> Zipper.down |> Zipper.leftmost |> Zipper.node
      1
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.right |> Zipper.leftmost |> Zipper.node
      1

  """
  @spec leftmost(Zipper.t) :: Zipper.maybe_zipper
  def leftmost(%__MODULE__{crumbs: nil}), do: {:error, :leftmost_from_root}
  def leftmost(zipper = %__MODULE__{crumbs: %{left: []}}), do: zipper
  def leftmost(zipper = %__MODULE__{}) do
    {new_focus, old_left} = List.pop_at(zipper.crumbs.left, -1)
    new_right = Enum.reverse(old_left) ++ [zipper.focus | zipper.crumbs.right]
    %{zipper |
      focus: new_focus,
      crumbs: %{zipper.crumbs | right: new_right, left: []}
    }
  end

  @doc """
  Returns to the root of the zipper. Remains in place if already on the root.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.root |> Zipper.node
      [1,[],[2,3,[4,5]]]
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.down |> Zipper.root |> Zipper.node
      [1,[],[2,3,[4,5]]]

  """
  @spec root(Zipper.t) :: Zipper.t
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
  @spec lefts(Zipper.t) :: [any()] | Zipper.error
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
  @spec rights(Zipper.t) :: [any()] | Zipper.error
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
  @spec path(Zipper.t) :: [any()]
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
  @spec branch?(Zipper.t) :: boolean
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
  @spec children(Zipper.t) :: [any()] | Zipper.error
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
  @spec make_node(Zipper.t, any(), [any()]) :: any()
  def make_node(zipper = %__MODULE__{}, node, children) do
    zipper.functions.make_node.(node, children)
  end

  @doc """
  Replaces the current focus with the node passed as the second argument.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper = Zipper.down(zipper)
      iex> Zipper.node(zipper)
      1
      iex> zipper = Zipper.replace(zipper, 10)
      iex> Zipper.node(zipper)
      10

  """
  @spec replace(Zipper.t, any()) :: Zipper.t
  def replace(zipper = %__MODULE__{}, new_focus) do
    %{zipper | focus: new_focus}
  end

  @doc """
  Replaces the current focus with the result of applying the given function
  to the current focus

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper = Zipper.down(zipper)
      iex> Zipper.node(zipper)
      1
      iex> zipper = Zipper.edit(zipper, &(&1 * 10))
      iex> Zipper.node(zipper)
      10

  """
  @spec edit(Zipper.t, (any() -> any())) :: Zipper.t
  def edit(zipper = %__MODULE__{}, func) do
    replace(zipper, func.(zipper.focus))
  end

  @doc """
  Inserts a new node as a new sibling to the immediate left of the current focus.
  Does not change focus. Returns an error if called on the root.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.insert_left(zipper, 0)
      {:error, :insert_left_of_root}
      iex> zipper |> Zipper.down |> Zipper.insert_left(0) |> Zipper.root |> Zipper.node
      [0,1,[],[2,3,[4,5]]]

  """
  @spec insert_left(Zipper.t, any()) :: Zipper.maybe_zipper
  def insert_left(%__MODULE__{crumbs: nil}, _) do
    {:error, :insert_left_of_root}
  end
  def insert_left(zipper = %__MODULE__{}, node) do
    %{zipper | crumbs: %{zipper.crumbs | left: [node | zipper.crumbs.left]}}
  end

  @doc """
  Inserts a new node as a new sibling to the immediate right of the current focus.
  Does not change focus. Returns an error if called on the root.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.insert_right(zipper, 0)
      {:error, :insert_right_of_root}
      iex> zipper |> Zipper.down |> Zipper.insert_right(0) |> Zipper.root |> Zipper.node
      [1,0,[],[2,3,[4,5]]]

  """
  @spec insert_right(Zipper.t, any()) :: Zipper.maybe_zipper
  def insert_right(%__MODULE__{crumbs: nil}, _) do
    {:error, :insert_right_of_root}
  end
  def insert_right(zipper = %__MODULE__{}, node) do
    %{zipper | crumbs: %{zipper.crumbs | right: [node | zipper.crumbs.right]}}
  end

  @doc """
  Inserts a child as the leftmost child of the current focus. Returns an error
  if called on a leaf.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.insert_child(6) |> Zipper.node
      [6,1,[],[2,3,[4,5]]]
      iex> zipper |> Zipper.down |> Zipper.insert_child(6)
      {:error, :insert_child_of_leaf}

  """
  @spec insert_child(Zipper.t, any()) :: Zipper.maybe_zipper
  def insert_child(zipper = %__MODULE__{}, new_child) do
    case branch?(zipper) do
      false ->
        {:error, :insert_child_of_leaf}

      true ->
        new_focus =
          make_node(zipper, zipper.focus, [new_child|children(zipper)])
        %{zipper | focus: new_focus}
    end
  end

  @doc """
  Appends a child as the rightmost child of the current focus. Returns an error
  if called on a leaf.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.append_child(6) |> Zipper.node
      [1,[],[2,3,[4,5]],6]
      iex> zipper |> Zipper.down |> Zipper.append_child(6)
      {:error, :append_child_of_leaf}

  """
  @spec append_child(Zipper.t, any()) :: Zipper.maybe_zipper
  def append_child(zipper = %__MODULE__{}, new_child) do
    case branch?(zipper) do
      false ->
        {:error, :append_child_of_leaf}
      true ->
        new_children = children(zipper) ++ [new_child]
        new_focus = make_node(zipper, zipper.focus, new_children)
        %{zipper | focus: new_focus}
    end
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
  @spec end?(Zipper.t) :: boolean
  def end?(%__MODULE__{crumbs: :end}), do: true
  def end?(%__MODULE__{}), do: false

  @doc """
  Moves to the next focus in a depth-first walk through the zipper. If it
  reaches the end, subsequent calls to `next` return the same focus

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
      iex> zipper |> Zipper.next |> Zipper.next |> Zipper.node
      [1,[],[2,3,[4,5]]]

  """
  @spec next(Zipper.t) :: Zipper.t
  def next(zipper = %__MODULE__{}) do
    case end?(zipper) do
      true ->
        zipper
      false ->
        case {down(zipper), right(zipper)} do
          {{:error, _}, {:error, _}} -> recur_next(zipper)
          {{:error, _}, right_zipper} -> right_zipper
          {down_zipper, _} -> down_zipper
        end
    end
  end

  @doc """
  Moves to the previous focus in a depth-first walk through the zipper. Returns
  an error if called on the end of the walk. Returns the root if called on
  the root.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.prev |> Zipper.node
      [1,[],[2,3,[4,5]]]
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.prev |> Zipper.node
      []
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.down |> Zipper.rightmost
      ...> |> Zipper.down |> Zipper.rightmost |> Zipper.next |> Zipper.prev
      {:error, :prev_of_end}

  """
  @spec prev(Zipper.t) :: Zipper.maybe_zipper
  def prev(%__MODULE__{crumbs: :end}), do: {:error, :prev_of_end}
  def prev(zipper = %__MODULE__{crumbs: nil}), do: zipper
  def prev(zipper = %__MODULE__{}) do
    case left(zipper) do
      {:error, _} -> up(zipper)
      left_zipper -> recur_prev(left_zipper)
    end
  end

  @doc """
  Removes the current focus from the zipper, moving focus to the node previous
  to the current focus in a depth-first walk. Will return an error if called on the root

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.remove(zipper)
      {:error, :remove_root}
      iex> zipper |> Zipper.down |> Zipper.remove |> Zipper.node
      [[],[2,3,[4,5]]]

  """
  @spec remove(Zipper.t) :: Zipper.maybe_zipper
  def remove(%__MODULE__{crumbs: nil}), do: {:error, :remove_root}
  def remove(zipper = %__MODULE__{}) do
    case left(zipper) do
      {:error, _} ->
        parent_zipper = up(zipper)
        [_ | new_children] = children(parent_zipper)
        new_focus = make_node(zipper, parent_zipper.focus, new_children)
        %{parent_zipper | focus: new_focus}
      left_zipper ->
        [_ | new_right] = left_zipper.crumbs.right
        %{left_zipper | crumbs: %{left_zipper.crumbs | right: new_right}}
    end
  end

  ## Private

  defp recur_prev(zipper = %__MODULE__{}) do
    case down(zipper) do
      {:error, _} -> zipper
      child -> child |> rightmost |> recur_prev
    end
  end

  defp recur_next(zipper = %__MODULE__{}) do
    case up(zipper) do
      {:error, _} ->
        %{zipper | crumbs: :end}

      next_zipper ->
        case right(next_zipper) do
          {:error, _} -> recur_next(next_zipper)
          new_zipper -> new_zipper
        end
    end
  end
end
