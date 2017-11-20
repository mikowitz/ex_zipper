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
      false ->
        {:error, :down_from_leaf}

      true ->
        case zipper.functions.children.(zipper.focus) do
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

  def up(%__MODULE__{crumbs: nil}), do: {:error, :up_from_root}

  def up(zipper = %__MODULE__{}) do
    new_children = Enum.reverse(zipper.crumbs.left) ++ [zipper.focus | zipper.crumbs.right]
    [new_focus | _] = zipper.crumbs.ppath
    new_focus = zipper.functions.make_node.(new_focus, new_children)
    %{zipper | focus: new_focus, crumbs: zipper.crumbs.pnodes}
  end

  def right(%__MODULE__{crumbs: nil}), do: {:error, :right_from_root}
  def right(%__MODULE__{crumbs: %{right: []}}), do: {:error, :right_from_rightmost}

  def right(zipper = %__MODULE__{}) do
    [new_focus | new_right] = zipper.crumbs.right
    new_left = [zipper.focus | zipper.crumbs.left]
    %{zipper | focus: new_focus, crumbs: %{zipper.crumbs | left: new_left, right: new_right}}
  end

  def left(%__MODULE__{crumbs: nil}), do: {:error, :left_from_root}
  def left(%__MODULE__{crumbs: %{left: []}}), do: {:error, :left_from_leftmost}

  def left(zipper = %__MODULE__{}) do
    [new_focus | new_left] = zipper.crumbs.left
    new_right = [zipper.focus | zipper.crumbs.right]
    %{zipper | focus: new_focus, crumbs: %{zipper.crumbs | left: new_left, right: new_right}}
  end

  def rightmost(%__MODULE__{crumbs: nil}), do: {:error, :rightmost_from_root}
  def rightmost(zipper = %__MODULE__{crumbs: %{right: []}}), do: zipper

  def rightmost(zipper = %__MODULE__{}) do
    {new_focus, old_right} = List.pop_at(zipper.crumbs.right, -1)
    new_left = Enum.reverse(old_right) ++ [zipper.focus | zipper.crumbs.left]
    %{zipper | focus: new_focus, crumbs: %{zipper.crumbs | left: new_left, right: []}}
  end

  def leftmost(%__MODULE__{crumbs: nil}), do: {:error, :leftmost_from_root}
  def leftmost(zipper = %__MODULE__{crumbs: %{left: []}}), do: zipper

  def leftmost(zipper = %__MODULE__{}) do
    {new_focus, old_left} = List.pop_at(zipper.crumbs.left, -1)
    new_right = Enum.reverse(old_left) ++ [zipper.focus | zipper.crumbs.right]
    %{zipper | focus: new_focus, crumbs: %{zipper.crumbs | right: new_right, left: []}}
  end

  def root(zipper = %__MODULE__{crumbs: nil}), do: zipper
  def root(zipper = %__MODULE__{}), do: zipper |> up |> root

  def lefts(%__MODULE__{crumbs: nil}), do: {:error, :lefts_of_root}
  def lefts(%__MODULE__{crumbs: %{left: left}}), do: Enum.reverse(left)

  def rights(%__MODULE__{crumbs: nil}), do: {:error, :rights_of_root}
  def rights(%__MODULE__{crumbs: %{right: right}}), do: right

  def path(%__MODULE__{crumbs: nil}), do: []
  def path(%__MODULE__{crumbs: %{ppath: paths}}), do: Enum.reverse(paths)

  def branch?(zipper = %__MODULE__{}) do
    zipper.functions.branch?.(zipper.focus)
  end

  def children(zipper = %__MODULE__{}) do
    case branch?(zipper) do
      true -> zipper.functions.children.(zipper.focus)
      false -> {:error, :children_of_leaf}
    end
  end

  def make_node(zipper = %__MODULE__{}, node, children) do
    zipper.functions.make_node.(node, children)
  end

  def replace(zipper = %__MODULE__{}, new_focus) do
    %{zipper | focus: new_focus}
  end

  def edit(zipper = %__MODULE__{}, func) do
    replace(zipper, func.(zipper.focus))
  end

  def insert_left(%__MODULE__{crumbs: nil}, _), do: {:error, :insert_left_of_root}

  def insert_left(zipper = %__MODULE__{}, node) do
    %{zipper | crumbs: %{zipper.crumbs | left: [node | zipper.crumbs.left]}}
  end

  def insert_right(%__MODULE__{crumbs: nil}, _), do: {:error, :insert_right_of_root}

  def insert_right(zipper = %__MODULE__{}, node) do
    %{zipper | crumbs: %{zipper.crumbs | right: [node | zipper.crumbs.right]}}
  end

  def insert_child(zipper = %__MODULE__{}, new_child) do
    case branch?(zipper) do
      false ->
        {:error, :insert_child_of_leaf}

      true ->
        new_focus =
          zipper.functions.make_node.(zipper.focus, [
            new_child | zipper.functions.children.(zipper.focus)
          ])

        %{zipper | focus: new_focus}
    end
  end

  def append_child(zipper = %__MODULE__{}, new_child) do
    case branch?(zipper) do
      false ->
        {:error, :append_child_of_leaf}

      true ->
        new_focus =
          zipper.functions.make_node.(
            zipper.focus,
            zipper.functions.children.(zipper.focus) ++ [new_child]
          )

        %{zipper | focus: new_focus}
    end
  end

  def end?(%__MODULE__{crumbs: :end}), do: true
  def end?(%__MODULE__{}), do: false

  def next(zipper = %__MODULE__{}) do
    case end?(zipper) do
      true ->
        zipper

      false ->
        case down(zipper) do
          {:error, _} ->
            case right(zipper) do
              {:error, _} -> recur_next(zipper)
              next_zipper -> next_zipper
            end

          next_zipper ->
            next_zipper
        end
    end
  end

  def recur_next(zipper = %__MODULE__{}) do
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

  def prev(%__MODULE__{crumbs: :end}), do: {:error, :prev_of_end}

  def prev(zipper = %__MODULE__{}) do
    case left(zipper) do
      {:error, _} -> up(zipper)
      left_zipper -> recur_prev(left_zipper)
    end
  end

  def recur_prev(zipper = %__MODULE__{}) do
    case down(zipper) do
      {:error, _} -> zipper
      child -> child |> rightmost |> recur_prev
    end
  end

  def remove(%__MODULE__{crumbs: nil}), do: {:error, :remove_root}

  def remove(zipper = %__MODULE__{}) do
    case left(zipper) do
      {:error, _} ->
        parent_zipper = up(zipper)
        [_ | new_children] = parent_zipper.functions.children.(parent_zipper.focus)

        %{
          parent_zipper
          | focus: parent_zipper.functions.make_node.(parent_zipper.focus, new_children)
        }

      left_zipper ->
        [_ | new_right] = left_zipper.crumbs.right
        %{left_zipper | crumbs: %{left_zipper.crumbs | right: new_right}}
    end
  end
end
