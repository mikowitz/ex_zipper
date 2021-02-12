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
      iex> zipper |> Zipper.down |> Zipper.down
      {:error, :down_from_leaf}
      iex> zipper |> Zipper.down |> Zipper.right |> Zipper.down
      {:error, :down_from_empty_branch}

  """
  @spec down(Zipper.t) :: Zipper.maybe_zipper
  def down(zipper = %Zipper{}) do
    case Zipper.branch?(zipper) do
      false ->
        {:error, :down_from_leaf}

      true ->
        case Zipper.children(zipper) do
          [] ->
            {:error, :down_from_empty_branch}

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
  def up(%Zipper{crumbs: nil}), do: {:error, :up_from_root}
  def up(zipper = %Zipper{}) do
    new_children = Enum.reverse(zipper.crumbs.left) ++
      [zipper.focus | zipper.crumbs.right]
    [new_focus | _] = zipper.crumbs.ppath
    new_focus = Zipper.make_node(zipper, new_focus, new_children)
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
  def right(%Zipper{crumbs: nil}), do: {:error, :right_from_root}
  def right(%Zipper{crumbs: %{right: []}}) do
    {:error, :right_from_rightmost}
  end
  def right(zipper = %Zipper{}) do
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
  def left(%Zipper{crumbs: nil}), do: {:error, :left_from_root}
  def left(%Zipper{crumbs: %{left: []}}), do: {:error, :left_from_leftmost}
  def left(zipper = %Zipper{}) do
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
  def rightmost(%Zipper{crumbs: nil}), do: {:error, :rightmost_from_root}
  def rightmost(zipper = %Zipper{crumbs: %{right: []}}), do: zipper
  def rightmost(zipper = %Zipper{}) do
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
  def leftmost(%Zipper{crumbs: nil}), do: {:error, :leftmost_from_root}
  def leftmost(zipper = %Zipper{crumbs: %{left: []}}), do: zipper
  def leftmost(zipper = %Zipper{}) do
    {new_focus, old_left} = List.pop_at(zipper.crumbs.left, -1)
    new_right = Enum.reverse(old_left) ++ [zipper.focus | zipper.crumbs.right]
    %{zipper |
      focus: new_focus,
      crumbs: %{zipper.crumbs | right: new_right, left: []}
    }
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
  @spec next(Zipper.t) :: Zipper.t
  def next(zipper = %Zipper{}) do
    case Zipper.end?(zipper) do
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
  def prev(%Zipper{crumbs: :end}), do: {:error, :prev_of_end}
  def prev(zipper = %Zipper{crumbs: nil}), do: zipper
  def prev(zipper = %Zipper{}) do
    case left(zipper) do
      {:error, _} -> up(zipper)
      left_zipper -> recur_prev(left_zipper)
    end
  end

  defp recur_prev(zipper = %Zipper{}) do
    case down(zipper) do
      {:error, _} -> zipper
      child -> child |> rightmost |> recur_prev
    end
  end

  defp recur_next(zipper = %Zipper{}) do
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
