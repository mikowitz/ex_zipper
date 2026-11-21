defmodule ExZipper.Zipper.Navigation do
  @moduledoc """
  Utility module for functions that concern navigating through zippers
  """

  alias ExZipper.Zipper

  @doc """
  Moves to the leftmost child of the current focus, or returns an error if
  the current focus is a leaf or an empty branch.

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
  @spec down(Zipper.t()) :: Zipper.maybe_zipper()
  def down(%Zipper{} = zipper) do
    case Zipper.branch?(zipper) do
      false ->
        ExZipper.raise_error(:down_from_leaf, zipper)

      true ->
        case Zipper.children(zipper) do
          [] ->
            ExZipper.raise_error(:down_from_empty_branch, zipper)

          [new_focus | new_right] ->
            %Zipper{
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

  def down?(%Zipper{} = zipper) do
    Zipper.branch?(zipper) and Zipper.children(zipper) != []
  end

  @doc """
  Moves up to the parent of the current focus, or returns an error if already
  at the root of the zipper

  ## Example

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.up |> Zipper.node
      [1,[],[2,3,[4,5]]]

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> Zipper.up(zipper)
      ** (ExZipper.Error) Cannot move up from the root

  """
  @spec up(Zipper.t()) :: Zipper.maybe_zipper()
  def up(%Zipper{crumbs: nil} = zipper), do: ExZipper.raise_error(:up_from_root, zipper)

  def up(%Zipper{} = zipper) do
    new_children =
      Enum.reverse(zipper.crumbs.left) ++
        [zipper.focus | zipper.crumbs.right]

    [new_focus | _] = zipper.crumbs.ppath
    new_focus = Zipper.make_node(zipper, new_focus, new_children)
    %{zipper | focus: new_focus, crumbs: zipper.crumbs.pnodes}
  end

  def up?(%Zipper{crumbs: nil}), do: false
  def up?(_), do: true

  @doc """
  Moves to the next sibling to the right of the current focus. Returns an error
  if at the root or already at the rightmost sibling at its depth in the tree.

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
  @spec right(Zipper.t()) :: Zipper.maybe_zipper()
  def right(%Zipper{crumbs: nil} = zipper), do: ExZipper.raise_error(:right_from_root, zipper)

  def right(%Zipper{crumbs: %{right: []}} = zipper) do
    ExZipper.raise_error(:right_from_rightmost, zipper)
  end

  def right(%Zipper{} = zipper) do
    [new_focus | new_right] = zipper.crumbs.right
    new_left = [zipper.focus | zipper.crumbs.left]
    %{zipper | focus: new_focus, crumbs: %{zipper.crumbs | left: new_left, right: new_right}}
  end

  def right?(%Zipper{crumbs: nil}), do: false
  def right?(%Zipper{crumbs: %{right: []}}), do: false
  def right?(_), do: true

  @doc """
  Moves to the next sibling to the left of the current focus. Returns an error
  if at the root or already at the leftmost sibling at its depth in the tree.

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
  @spec left(Zipper.t()) :: Zipper.maybe_zipper()
  def left(%Zipper{crumbs: nil} = zipper), do: ExZipper.raise_error(:left_from_root, zipper)

  def left(%Zipper{crumbs: %{left: []}} = zipper),
    do: ExZipper.raise_error(:left_from_leftmost, zipper)

  def left(%Zipper{} = zipper) do
    [new_focus | new_left] = zipper.crumbs.left
    new_right = [zipper.focus | zipper.crumbs.right]
    %{zipper | focus: new_focus, crumbs: %{zipper.crumbs | left: new_left, right: new_right}}
  end

  def left?(%Zipper{crumbs: nil}), do: false
  def left?(%Zipper{crumbs: %{left: []}}), do: false
  def left?(_), do: true

  @doc """
  Moves to the leftmost sibling at the same depth as the current focus. Remains
  in place if already focused on the leftmost sibling. Returns an error if
  called on the root.

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
  @spec rightmost(Zipper.t()) :: Zipper.maybe_zipper()
  def rightmost(%Zipper{crumbs: nil} = zipper),
    do: ExZipper.raise_error(:rightmost_from_root, zipper)

  def rightmost(%Zipper{crumbs: %{right: []}} = zipper), do: zipper

  def rightmost(%Zipper{} = zipper) do
    {new_focus, old_right} = List.pop_at(zipper.crumbs.right, -1)
    new_left = Enum.reverse(old_right) ++ [zipper.focus | zipper.crumbs.left]
    %{zipper | focus: new_focus, crumbs: %{zipper.crumbs | left: new_left, right: []}}
  end

  @doc """
  Moves to the leftmost sibling at the same depth as the current focus. Remains
  in place if already focused on the leftmost sibling. Returns an error if
  called on the root.

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
  @spec leftmost(Zipper.t()) :: Zipper.maybe_zipper()
  def leftmost(%Zipper{crumbs: nil} = zipper),
    do: ExZipper.raise_error(:leftmost_from_root, zipper)

  def leftmost(%Zipper{crumbs: %{left: []}} = zipper), do: zipper

  def leftmost(%Zipper{} = zipper) do
    {new_focus, old_left} = List.pop_at(zipper.crumbs.left, -1)
    new_right = Enum.reverse(old_left) ++ [zipper.focus | zipper.crumbs.right]
    %{zipper | focus: new_focus, crumbs: %{zipper.crumbs | right: new_right, left: []}}
  end

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
  @spec next(Zipper.t()) :: Zipper.t()
  def next(%Zipper{} = zipper) do
    case Zipper.end?(zipper) do
      true ->
        zipper

      false ->
        case {down?(zipper), right?(zipper)} do
          {false, false} -> recur_next(zipper)
          {false, true} -> right(zipper)
          {true, _} -> down(zipper)
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

      iex> zipper = Zipper.list_zipper([1,[],[2,3,[4,5]]])
      iex> zipper |> Zipper.down |> Zipper.rightmost |> Zipper.down |> Zipper.rightmost
      ...> |> Zipper.down |> Zipper.rightmost |> Zipper.next |> Zipper.prev
      ** (ExZipper.Error) Cannot call previous from the end

  """
  @spec prev(Zipper.t()) :: Zipper.maybe_zipper()
  def prev(%Zipper{crumbs: :end} = zipper), do: ExZipper.raise_error(:prev_of_end, zipper)
  def prev(%Zipper{crumbs: nil} = zipper), do: zipper

  def prev(%Zipper{} = zipper) do
    case left?(zipper) do
      false -> up(zipper)
      true -> zipper |> left() |> recur_prev()
    end
  end

  defp recur_prev(%Zipper{} = zipper) do
    case down?(zipper) do
      false -> zipper
      true -> zipper |> down() |> rightmost() |> recur_prev()
    end
  end

  defp recur_next(%Zipper{} = zipper) do
    case up?(zipper) do
      false ->
        %{zipper | crumbs: :end}

      true ->
        zipper = up(zipper)

        case right?(zipper) do
          true -> right(zipper)
          false -> recur_next(zipper)
        end
    end
  end
end
