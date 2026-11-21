defmodule ExZipper.Zipper.Traversal do
  @moduledoc """
  Utility module for functions that walk a zipper depth-first, as
  `ExZipper.Zipper.next/1` does

  Each walk starts at the current focus, not at the root. It visits the
  current focus, its descendants, and then every node that comes after it in
  a depth-first walk of the whole tree.
  """

  alias ExZipper.Zipper

  @doc """
  Walks the zipper depth-first from the current focus. Returns a zipper
  focused on the first node for which `fun` returns a truthy value. Returns
  `nil` if no node matches before the walk ends.

  The current focus is checked first, so to find the next match after the
  one you have, call `ExZipper.Zipper.next/1` first.

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
  @spec find(Zipper.t(), (any() -> as_boolean(any()))) :: Zipper.maybe_zipper()
  def find(zipper, fun) do
    recur_find(zipper, fun)
  end

  defp recur_find(zipper, fun) do
    if Zipper.end?(zipper) do
      nil
    else
      if fun.(Zipper.node(zipper)) do
        zipper
      else
        recur_find(Zipper.next(zipper), fun)
      end
    end
  end

  @doc """
  Replaces every node visited by a depth-first walk with the result of
  calling `fun` on it, and returns a zipper focused on the (updated) root.

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
  def map(zipper, fun), do: recur_map(zipper, fun)

  defp recur_map(zipper, fun) do
    if Zipper.end?(zipper) do
      %{zipper | crumbs: nil}
    else
      recur_map(
        Zipper.next(Zipper.edit(zipper, fun)),
        fun
      )
    end
  end

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
  def find_all(zipper, fun), do: recur_find_all(zipper, [], fun)

  defp recur_find_all(zipper, acc, fun) do
    if Zipper.end?(zipper) do
      Enum.reverse(acc)
    else
      if fun.(Zipper.node(zipper)) do
        recur_find_all(
          Zipper.next(zipper),
          [zipper | acc],
          fun
        )
      else
        recur_find_all(
          Zipper.next(zipper),
          acc,
          fun
        )
      end
    end
  end
end
