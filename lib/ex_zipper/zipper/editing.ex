defmodule ExZipper.Zipper.Editing do
  @moduledoc """
  Utility module for functions that concern editing zippers
  """

  alias ExZipper.Zipper

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
  @spec replace(Zipper.t(), any()) :: Zipper.t()
  def replace(%Zipper{} = zipper, new_focus) do
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
  @spec edit(Zipper.t(), (any() -> any())) :: Zipper.t()
  def edit(%Zipper{} = zipper, func) do
    replace(zipper, func.(zipper.focus))
  end

  @doc """
  Inserts a new node as a new sibling to the immediate left of the current focus.
  Does not change focus. Raises an `ExZipper.Error` if called on the root.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.insert_left(0) |> Zipper.root |> Zipper.node
      [0,1,[],[2,3,[4,5]]]

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.insert_left(zipper, 0)
      ** (ExZipper.Error) Cannot insert to the left of the root

  """
  @spec insert_left(Zipper.t(), any()) :: Zipper.t()
  def insert_left(%Zipper{crumbs: nil} = zipper, _) do
    ExZipper.raise_error(:insert_left_of_root, zipper)
  end

  def insert_left(%Zipper{} = zipper, node) do
    %{zipper | crumbs: %{zipper.crumbs | left: [node | zipper.crumbs.left]}}
  end

  @doc """
  Inserts a new node as a new sibling to the immediate right of the current focus.
  Does not change focus. Raises an `ExZipper.Error` if called on the root.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.insert_right(0) |> Zipper.root |> Zipper.node
      [1,0,[],[2,3,[4,5]]]

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.insert_right(zipper, 0)
      ** (ExZipper.Error) Cannot insert to the right of the root

  """
  @spec insert_right(Zipper.t(), any()) :: Zipper.t()
  def insert_right(%Zipper{crumbs: nil} = zipper, _) do
    ExZipper.raise_error(:insert_right_of_root, zipper)
  end

  def insert_right(%Zipper{} = zipper, node) do
    %{zipper | crumbs: %{zipper.crumbs | right: [node | zipper.crumbs.right]}}
  end

  @doc """
  Inserts a child as the leftmost child of the current focus. Raises an
  `ExZipper.Error` if called on a leaf.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.insert_child(6) |> Zipper.node
      [6,1,[],[2,3,[4,5]]]

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.insert_child(6)
      ** (ExZipper.Error) Cannot insert a child into a leaf

  """
  @spec insert_child(Zipper.t(), any()) :: Zipper.t()
  def insert_child(%Zipper{} = zipper, new_child) do
    case Zipper.branch?(zipper) do
      false ->
        ExZipper.raise_error(:insert_child_of_leaf, zipper)

      true ->
        new_focus =
          Zipper.make_node(zipper, zipper.focus, [new_child | Zipper.children(zipper)])

        %{zipper | focus: new_focus}
    end
  end

  @doc """
  Appends a child as the rightmost child of the current focus. Raises an
  `ExZipper.Error` if called on a leaf.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.append_child(6) |> Zipper.node
      [1,[],[2,3,[4,5]],6]

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.append_child(6)
      ** (ExZipper.Error) Cannot append a child to a leaf

  """
  @spec append_child(Zipper.t(), any()) :: Zipper.t()
  def append_child(%Zipper{} = zipper, new_child) do
    case Zipper.branch?(zipper) do
      false ->
        ExZipper.raise_error(:append_child_of_leaf, zipper)

      true ->
        new_children = Zipper.children(zipper) ++ [new_child]
        new_focus = Zipper.make_node(zipper, zipper.focus, new_children)
        %{zipper | focus: new_focus}
    end
  end

  @doc """
  Removes the current focus from the zipper, moving focus to the node previous
  to the current focus in a depth-first walk. Raises an `ExZipper.Error` if called on the root.

  ## Examples

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.remove |> Zipper.node
      [[],[2,3,[4,5]]]

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.remove(zipper)
      ** (ExZipper.Error) Cannot remove root

  """
  @spec remove(Zipper.t()) :: Zipper.t()
  def remove(%Zipper{crumbs: nil} = zipper), do: ExZipper.raise_error(:remove_root, zipper)

  def remove(%Zipper{} = zipper) do
    case Zipper.Navigation.left?(zipper) do
      false ->
        parent_zipper = Zipper.up(zipper)
        [_ | new_children] = Zipper.children(parent_zipper)
        new_focus = Zipper.make_node(zipper, parent_zipper.focus, new_children)
        %{parent_zipper | focus: new_focus}

      true ->
        zipper = Zipper.left(zipper)
        [_ | new_right] = zipper.crumbs.right
        %{zipper | crumbs: %{zipper.crumbs | right: new_right}}
    end
  end
end
