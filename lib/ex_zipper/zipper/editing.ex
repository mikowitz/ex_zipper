defmodule ExZipper.Zipper.Editing do
  @moduledoc false

  alias ExZipper.Zipper

  @spec replace(Zipper.t(), any()) :: Zipper.t()
  def replace(%Zipper{crumbs: :end} = zipper, _), do: ExZipper.raise_error(:replace_end, zipper)

  def replace(%Zipper{} = zipper, new_focus) do
    %{zipper | focus: new_focus}
  end

  @spec edit(Zipper.t(), (any() -> any())) :: Zipper.t()
  def edit(%Zipper{crumbs: :end} = zipper, _), do: ExZipper.raise_error(:edit_end, zipper)

  def edit(%Zipper{} = zipper, func) do
    replace(zipper, func.(zipper.focus))
  end

  @spec insert_left(Zipper.t(), any()) :: Zipper.t()
  def insert_left(%Zipper{crumbs: nil} = zipper, _) do
    ExZipper.raise_error(:insert_left_of_root, zipper)
  end

  def insert_left(%Zipper{crumbs: :end} = zipper, _) do
    ExZipper.raise_error(:insert_left_of_end, zipper)
  end

  def insert_left(%Zipper{} = zipper, node) do
    %{zipper | crumbs: %{zipper.crumbs | left: [node | zipper.crumbs.left]}}
  end

  @spec insert_right(Zipper.t(), any()) :: Zipper.t()
  def insert_right(%Zipper{crumbs: nil} = zipper, _) do
    ExZipper.raise_error(:insert_right_of_root, zipper)
  end

  def insert_right(%Zipper{crumbs: :end} = zipper, _) do
    ExZipper.raise_error(:insert_right_of_end, zipper)
  end

  def insert_right(%Zipper{} = zipper, node) do
    %{zipper | crumbs: %{zipper.crumbs | right: [node | zipper.crumbs.right]}}
  end

  @spec insert_child(Zipper.t(), any()) :: Zipper.t()
  def insert_child(%Zipper{crumbs: :end} = zipper, _),
    do: ExZipper.raise_error(:insert_child_of_end, zipper)

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

  @spec append_child(Zipper.t(), any()) :: Zipper.t()
  def append_child(%Zipper{crumbs: :end} = zipper, _),
    do: ExZipper.raise_error(:append_child_of_end, zipper)

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

  @spec remove(Zipper.t()) :: Zipper.t()
  def remove(%Zipper{crumbs: nil} = zipper), do: ExZipper.raise_error(:remove_root, zipper)
  def remove(%Zipper{crumbs: :end} = zipper), do: ExZipper.raise_error(:remove_end, zipper)

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
        %{zipper | crumbs: %{zipper.crumbs | right: new_right}} |> rightmost_descendant()
    end
  end

  defp rightmost_descendant(%Zipper{} = zipper) do
    case ExZipper.Zipper.Navigation.down?(zipper) do
      false -> zipper
      true -> zipper |> Zipper.down() |> Zipper.rightmost() |> rightmost_descendant()
    end
  end
end
