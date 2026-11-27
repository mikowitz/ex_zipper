defmodule ExZipper.TreeTest do
  use ExUnit.Case, async: true
  alias ExZipper.Zipper
  import ExZipper.TestHelpers

  defmodule MapTree do
    @moduledoc false
    @behaviour ExZipper.Tree

    @impl true
    def branch?(node), do: is_map(node) and Map.has_key?(node, :kids)

    @impl true
    def children(%{kids: kids}), do: kids

    @impl true
    def make_node(node, kids), do: %{node | kids: kids}
  end

  defmodule PartialTree do
    @moduledoc false
    def branch?(node), do: is_map(node)
  end

  defmodule UndeclaredTree do
    @moduledoc false
    def branch?(node), do: is_list(node)
    def children(node), do: node
    def make_node(_node, children), do: children
  end

  setup do
    tree = %{
      value: "top",
      kids: [
        %{value: "first"},
        %{value: "middle", kids: [%{value: "inner"}]},
        %{value: "last"}
      ]
    }

    [tree: tree, zipper: Zipper.new(MapTree, tree)]
  end

  describe "the ExZipper.Tree behaviour" do
    test "defines branch?/1, children/1 and make_node/2 callbacks" do
      assert ExZipper.Tree.behaviour_info(:callbacks) |> Enum.sort() ==
               [branch?: 1, children: 1, make_node: 2]
    end

    test "has no optional callbacks" do
      assert ExZipper.Tree.behaviour_info(:optional_callbacks) == []
    end
  end

  describe "Zipper.new/2" do
    test "returns a zipper focused on the given root", context do
      assert %Zipper{} = context.zipper
      assert Zipper.node(context.zipper) == context.tree
      assert Zipper.path(context.zipper) == []
      refute Zipper.end?(context.zipper)
    end

    test "uses the module's branch?/1", context do
      assert Zipper.branch?(context.zipper)
      refute context.zipper |> Zipper.down() |> Zipper.branch?()
    end

    test "uses the module's children/1", context do
      assert Zipper.children(context.zipper) == context.tree.kids
    end

    test "uses the module's make_node/2", context do
      assert Zipper.make_node(context.zipper, %{value: "x", kids: []}, [%{value: "y"}]) ==
               %{value: "x", kids: [%{value: "y"}]}
    end

    test "returns a zipper that can be navigated", context do
      zipper = context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.down()

      assert Zipper.node(zipper) == %{value: "inner"}
      assert zipper |> Zipper.up() |> Zipper.node() |> Map.get(:value) == "middle"
      assert zipper |> Zipper.root() |> Zipper.node() == context.tree
    end

    test "returns a zipper that rebuilds the tree with make_node/2 after edits", context do
      zipper =
        context.zipper
        |> Zipper.find(&match?(%{value: "middle"}, &1))
        |> Zipper.append_child(%{value: "new"})
        |> Zipper.root()

      assert Zipper.node(zipper) == %{
               value: "top",
               kids: [
                 %{value: "first"},
                 %{value: "middle", kids: [%{value: "inner"}, %{value: "new"}]},
                 %{value: "last"}
               ]
             }
    end

    test "returns a zipper that can be walked depth-first", context do
      values = context.zipper |> Zipper.to_list() |> Enum.map(& &1.value)

      assert values == ["top", "first", "middle", "inner", "last"]
    end

    test "returns a zipper that raises ExZipper.Error on invalid moves", context do
      assert_zipper_error(:down_from_leaf, fn ->
        context.zipper |> Zipper.down() |> Zipper.down()
      end)
    end

    test "raises an ArgumentError for a module that implements none of the callbacks" do
      error = assert_raise ArgumentError, fn -> Zipper.new(String, "root") end

      assert error.message =~ "String"
      assert error.message =~ "branch?/1"
      assert error.message =~ "children/1"
      assert error.message =~ "make_node/2"
    end

    test "raises an ArgumentError naming only the missing callbacks" do
      error = assert_raise ArgumentError, fn -> Zipper.new(PartialTree, %{}) end

      assert error.message =~ "ExZipper.TreeTest.PartialTree"
      refute error.message =~ "branch?/1"
      assert error.message =~ "children/1"
      assert error.message =~ "make_node/2"
    end

    test "raises an ArgumentError for a module that does not exist" do
      error = assert_raise ArgumentError, fn -> Zipper.new(NoSuchTreeModule, %{}) end

      assert error.message =~ "NoSuchTreeModule"
    end

    test "raises an ArgumentError when not given a module" do
      assert_raise ArgumentError, fn ->
        apply(Zipper, :new, [%{}, %{}])
      end

      assert_raise ArgumentError, fn ->
        apply(Zipper, :new, ["MapTree", %{}])
      end
    end

    test "accepts a module that exports the callbacks without declaring the behaviour" do
      zipper = Zipper.new(UndeclaredTree, [1, [2]])

      assert zipper |> Zipper.down() |> Zipper.right() |> Zipper.down() |> Zipper.node() == 2
    end

    test "behaves the same as Zipper.zipper/4 with the module's functions", context do
      by_module = Zipper.new(MapTree, context.tree)

      by_functions =
        Zipper.zipper(
          &MapTree.branch?/1,
          &MapTree.children/1,
          &MapTree.make_node/2,
          context.tree
        )

      edit = fn zipper ->
        zipper
        |> Zipper.find(&match?(%{value: "inner"}, &1))
        |> Zipper.insert_right(%{value: "sibling"})
        |> Zipper.root()
        |> Zipper.to_list()
      end

      assert edit.(by_module) == edit.(by_functions)
    end
  end
end
