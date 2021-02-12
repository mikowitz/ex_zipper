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
  @spec replace(Zipper.t, any()) :: Zipper.t
  def replace(zipper = %Zipper{}, new_focus) do
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
  def edit(zipper = %Zipper{}, func) do
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
  def insert_left(%Zipper{crumbs: nil}, _) do
    {:error, :insert_left_of_root}
  end
  def insert_left(zipper = %Zipper{}, node) do
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
  def insert_right(%Zipper{crumbs: nil}, _) do
    {:error, :insert_right_of_root}
  end
  def insert_right(zipper = %Zipper{}, node) do
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
  def insert_child(zipper = %Zipper{}, new_child) do
    case Zipper.branch?(zipper) do
      false ->
        {:error, :insert_child_of_leaf}

      true ->
        new_focus =
          Zipper.make_node(zipper, zipper.focus, [new_child|Zipper.children(zipper)])
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
  def append_child(zipper = %Zipper{}, new_child) do
    case Zipper.branch?(zipper) do
      false ->
        {:error, :append_child_of_leaf}
      true ->
        new_children = Zipper.children(zipper) ++ [new_child]
        new_focus = Zipper.make_node(zipper, zipper.focus, new_children)
        %{zipper | focus: new_focus}
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
  def remove(%Zipper{crumbs: nil}), do: {:error, :remove_root}
  def remove(zipper = %Zipper{}) do
    case Zipper.left(zipper) do
      {:error, _} ->
        parent_zipper = Zipper.up(zipper)
        [_ | new_children] = Zipper.children(parent_zipper)
        new_focus = Zipper.make_node(zipper, parent_zipper.focus, new_children)
        %{parent_zipper | focus: new_focus}
      left_zipper ->
        [_ | new_right] = left_zipper.crumbs.right
        %{left_zipper | crumbs: %{left_zipper.crumbs | right: new_right}}
    end
  end
end
