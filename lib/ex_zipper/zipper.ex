defmodule ExZipper.Zipper do
  @moduledoc false

  defstruct [:focus, :crumbs, :functions]

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

  def node(%__MODULE__{focus: focus}), do: focus

  def down(zipper = %__MODULE__{}) do
    case zipper.functions.branch?.(zipper.focus) do
      false -> {:error, :down_from_leaf}
      true ->
        case zipper.functions.children.(zipper.focus) do
          [] -> {:error, :down_from_empty_branch}
          [new_focus|new_right] ->
            %__MODULE__{
              focus: new_focus,
              crumbs: %{
                left: [],
                right: new_right,
                pnodes: zipper.crumbs,
                ppath: case zipper.crumbs do
                  nil -> [zipper.focus]
                  crumbs -> [zipper.focus|crumbs.ppath]
                end
              },
              functions: zipper.functions
            }
        end
    end
  end

  def up(%__MODULE__{crumbs: nil}), do: {:error, :up_from_root}
  def up(zipper = %__MODULE__{}) do
    new_children = Enum.reverse(zipper.crumbs.left) ++ [zipper.focus|zipper.crumbs.right]
    [new_focus|_] = zipper.crumbs.ppath
    new_focus = zipper.functions.make_node.(new_focus, new_children)
    %{zipper |
      focus: new_focus,
      crumbs: zipper.crumbs.pnodes
    }
  end

  def right(%__MODULE__{crumbs: nil}), do: {:error, :right_from_root}
  def right(%__MODULE__{crumbs: %{right: []}}), do: {:error, :right_from_rightmost}
  def right(zipper = %__MODULE__{}) do
    [new_focus|new_right] = zipper.crumbs.right
    new_left = [zipper.focus|zipper.crumbs.left]
    %{zipper |
      focus: new_focus,
      crumbs: %{zipper.crumbs |
        left: new_left,
        right: new_right
      }
    }
  end

  def left(%__MODULE__{crumbs: nil}), do: {:error, :left_from_root}
  def left(%__MODULE__{crumbs: %{left: []}}), do: {:error, :left_from_leftmost}
  def left(zipper = %__MODULE__{}) do
    [new_focus|new_left] = zipper.crumbs.left
    new_right = [zipper.focus|zipper.crumbs.right]
    %{zipper |
      focus: new_focus,
      crumbs: %{zipper.crumbs |
        left: new_left,
        right: new_right
      }
    }
  end

  def rightmost(%__MODULE__{crumbs: nil}), do: {:error, :rightmost_from_root}
  def rightmost(zipper = %__MODULE__{crumbs: %{right: []}}), do: zipper
  def rightmost(zipper = %__MODULE__{}) do
    {new_focus, old_right} = List.pop_at(zipper.crumbs.right, -1)
    new_left = Enum.reverse(old_right) ++ [zipper.focus|zipper.crumbs.left]
    %{zipper |
      focus: new_focus,
      crumbs: %{zipper.crumbs |
        left: new_left,
        right: []
      }
    }
  end

  def leftmost(%__MODULE__{crumbs: nil}), do: {:error, :leftmost_from_root}
  def leftmost(zipper = %__MODULE__{crumbs: %{left: []}}), do: zipper
  def leftmost(zipper = %__MODULE__{}) do
    {new_focus, old_left} = List.pop_at(zipper.crumbs.left, -1)
    new_right = Enum.reverse(old_left) ++ [zipper.focus|zipper.crumbs.right]
    %{zipper |
      focus: new_focus,
      crumbs: %{zipper.crumbs |
        right: new_right,
        left: []
      }
    }
  end

  def root(zipper = %__MODULE__{crumbs: nil}), do: zipper
  def root(zipper = %__MODULE__{}), do: zipper |> up |> root

  def lefts(%__MODULE__{crumbs: nil}), do: {:error, :lefts_of_root}
  def lefts(%__MODULE__{crumbs: %{left: left}}), do: Enum.reverse(left)

  def rights(%__MODULE__{crumbs: nil}), do: {:error, :rights_of_root}
  def rights(%__MODULE__{crumbs: %{right: right}}), do: right
end
