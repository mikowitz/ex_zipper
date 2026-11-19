defmodule ExZipper.Zipper.Traversal do
  alias ExZipper.Zipper

  def find(zipper, fun) do
    recur_find(zipper, fun)
  end

  defp recur_find(zipper, fun) do
    if Zipper.end?(zipper) do
      {:error, :not_found}
    else
      if fun.(Zipper.node(zipper)) do
        zipper
      else
        recur_find(Zipper.next(zipper), fun)
      end
    end
  end

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
