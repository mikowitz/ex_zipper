defmodule ExZipper.Tree do
  @moduledoc """
  A behaviour for modules that describe how to navigate and rebuild a tree.

  `ExZipper.Zipper.zipper/4` takes the three functions a zipper needs as
  arguments. When the same kind of tree is zipped in several places, it can be
  clearer to define those functions once in a module that implements this
  behaviour and pass the module to `ExZipper.Zipper.new/2`.

  ## Example

  A tree of maps, where a branch stores its children under `:kids`:

      defmodule MapTree do
        @behaviour ExZipper.Tree

        @impl true
        def branch?(node), do: is_map(node) and Map.has_key?(node, :kids)

        @impl true
        def children(%{kids: kids}), do: kids

        @impl true
        def make_node(node, kids), do: %{node | kids: kids}
      end

      ExZipper.Zipper.new(MapTree, %{value: "root", kids: [%{value: "leaf"}]})

  The callbacks are not checked at runtime. Declaring `@behaviour
  ExZipper.Tree` lets the compiler warn about missing callbacks. Without that,
  a missing callback raises an `UndefinedFunctionError` the first time the
  zipper calls it.
  """

  @doc """
  Returns whether `node` is a branch, that is, a node that can have children.

  A branch with no children is still a branch: return `true` for it, and
  `children/1` should return an empty list.
  """
  @callback branch?(node :: any()) :: boolean()

  @doc """
  Returns the children of `node`, in order.

  The zipper only calls this on nodes for which `branch?/1` returned `true`.
  """
  @callback children(node :: any()) :: list(any())

  @doc """
  Returns a new node built from an existing `node` and a new list of
  `children`.

  The zipper calls this when rebuilding the tree after an edit. `node` is the
  branch being rebuilt, and `children` is its updated list of children.

  The result must be a branch whose children are `children`, in order: for
  any branch `node`, `children(make_node(node, kids))` must equal `kids`.
  Otherwise edits made through the zipper are lost or misplaced when the tree
  is rebuilt.
  """
  @callback make_node(node :: any(), children :: list(any())) :: any()
end
