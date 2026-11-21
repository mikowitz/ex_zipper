defmodule ExZipper.Zipper.Navigation do
  @moduledoc false

  alias ExZipper.Zipper

  @spec down(Zipper.t()) :: Zipper.t()
  def down(%Zipper{crumbs: :end} = zipper), do: ExZipper.raise_error(:down_from_end, zipper)

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

  @doc false
  def down?(%Zipper{} = zipper) do
    Zipper.branch?(zipper) and Zipper.children(zipper) != []
  end

  @spec up(Zipper.t()) :: Zipper.t()
  def up(%Zipper{crumbs: nil} = zipper), do: ExZipper.raise_error(:up_from_root, zipper)
  def up(%Zipper{crumbs: :end} = zipper), do: ExZipper.raise_error(:up_from_end, zipper)

  def up(%Zipper{} = zipper) do
    new_children =
      Enum.reverse(zipper.crumbs.left) ++
        [zipper.focus | zipper.crumbs.right]

    [new_focus | _] = zipper.crumbs.ppath
    new_focus = Zipper.make_node(zipper, new_focus, new_children)
    %{zipper | focus: new_focus, crumbs: zipper.crumbs.pnodes}
  end

  @doc false
  def up?(%Zipper{crumbs: nil}), do: false
  def up?(_), do: true

  @spec right(Zipper.t()) :: Zipper.t()
  def right(%Zipper{crumbs: nil} = zipper), do: ExZipper.raise_error(:right_from_root, zipper)
  def right(%Zipper{crumbs: :end} = zipper), do: ExZipper.raise_error(:right_from_end, zipper)

  def right(%Zipper{crumbs: %{right: []}} = zipper) do
    ExZipper.raise_error(:right_from_rightmost, zipper)
  end

  def right(%Zipper{} = zipper) do
    [new_focus | new_right] = zipper.crumbs.right
    new_left = [zipper.focus | zipper.crumbs.left]
    %{zipper | focus: new_focus, crumbs: %{zipper.crumbs | left: new_left, right: new_right}}
  end

  @doc false
  def right?(%Zipper{crumbs: nil}), do: false
  def right?(%Zipper{crumbs: %{right: []}}), do: false
  def right?(_), do: true

  @spec left(Zipper.t()) :: Zipper.t()
  def left(%Zipper{crumbs: nil} = zipper), do: ExZipper.raise_error(:left_from_root, zipper)
  def left(%Zipper{crumbs: :end} = zipper), do: ExZipper.raise_error(:left_from_end, zipper)

  def left(%Zipper{crumbs: %{left: []}} = zipper),
    do: ExZipper.raise_error(:left_from_leftmost, zipper)

  def left(%Zipper{} = zipper) do
    [new_focus | new_left] = zipper.crumbs.left
    new_right = [zipper.focus | zipper.crumbs.right]
    %{zipper | focus: new_focus, crumbs: %{zipper.crumbs | left: new_left, right: new_right}}
  end

  @doc false
  def left?(%Zipper{crumbs: nil}), do: false
  def left?(%Zipper{crumbs: %{left: []}}), do: false
  def left?(_), do: true

  @spec rightmost(Zipper.t()) :: Zipper.t()
  def rightmost(%Zipper{crumbs: nil} = zipper),
    do: ExZipper.raise_error(:rightmost_from_root, zipper)

  def rightmost(%Zipper{crumbs: :end} = zipper),
    do: ExZipper.raise_error(:rightmost_from_end, zipper)

  def rightmost(%Zipper{crumbs: %{right: []}} = zipper), do: zipper

  def rightmost(%Zipper{} = zipper) do
    {new_focus, old_right} = List.pop_at(zipper.crumbs.right, -1)
    new_left = Enum.reverse(old_right) ++ [zipper.focus | zipper.crumbs.left]
    %{zipper | focus: new_focus, crumbs: %{zipper.crumbs | left: new_left, right: []}}
  end

  @spec leftmost(Zipper.t()) :: Zipper.t()
  def leftmost(%Zipper{crumbs: nil} = zipper),
    do: ExZipper.raise_error(:leftmost_from_root, zipper)

  def leftmost(%Zipper{crumbs: :end} = zipper),
    do: ExZipper.raise_error(:leftmost_from_end, zipper)

  def leftmost(%Zipper{crumbs: %{left: []}} = zipper), do: zipper

  def leftmost(%Zipper{} = zipper) do
    {new_focus, old_left} = List.pop_at(zipper.crumbs.left, -1)
    new_right = Enum.reverse(old_left) ++ [zipper.focus | zipper.crumbs.right]
    %{zipper | focus: new_focus, crumbs: %{zipper.crumbs | right: new_right, left: []}}
  end

  @spec next(Zipper.t()) :: Zipper.t()
  def next(%Zipper{crumbs: :end} = zipper), do: ExZipper.raise_error(:next_of_end, zipper)

  def next(%Zipper{} = zipper) do
    case {down?(zipper), right?(zipper)} do
      {false, false} -> recur_next(zipper)
      {false, true} -> right(zipper)
      {true, _} -> down(zipper)
    end
  end

  @spec prev(Zipper.t()) :: Zipper.t()
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
