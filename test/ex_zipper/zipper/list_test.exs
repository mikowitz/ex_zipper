defmodule ExZipper.Zipper.ListTest do
  use ExUnit.Case, async: true
  alias ExZipper.Zipper, as: Z

  setup do
    list = [1,[],2,[3,4,[5, 6], [7]], 8]
    zipper = Z.zipper(
      &is_list/1,
      &(&1),
      fn _node, children -> children end,
      list
    )
    {:ok, %{list: list, zipper: zipper}}
  end

  describe "node/1" do
    test "returns the current focus of the zipper", context do
      assert Z.node(context.zipper) == context.list
    end
  end

  describe "down/1" do
    test "returns an error if called on a leaf", context do
      zipper = %{context.zipper | focus: 11}
      assert Z.down(zipper) == {:error, :down_from_leaf}
    end

    test "returns an error if called on an empty branch", context do
      zipper = %{context.zipper | focus: []}
      assert Z.down(zipper) == {:error, :down_from_empty_branch}
    end

    test "moves focus to the first child of the current focus", context do
      zipper = Z.down(context.zipper)
      assert Z.node(zipper) == 1
      assert zipper.crumbs == %{
        left: [],
        right: [[],2,[3,4,[5, 6], [7]], 8],
        pnodes: nil,
        ppath: [context.list]
      }
    end
  end

  describe "right/1" do
    test "returns an error if called on the root", context do
      assert Z.right(context.zipper) == {:error, :right_from_root}
    end

    test "returns an error if called on the rightmost sibling", context do
      zipper = context.zipper |> Z.down |> Z.right |> Z.right |> Z.right |> Z.right
      assert Z.right(zipper) == {:error, :right_from_rightmost}
    end

    test "moves focus to the sibling to the right of the current focus", context do
      zipper = Z.down(context.zipper)
      zipper = Z.right(zipper)
      assert zipper.focus == []
      assert zipper.crumbs == %{
        left: [1],
        right: [2,[3,4,[5, 6], [7]], 8],
        pnodes: nil,
        ppath: [context.list]
      }
    end
  end

  describe "left" do
    test "returns an error if called on the root", context do
      assert Z.left(context.zipper) == {:error, :left_from_root}
    end

    test "returns an error if called on the leftmost sibling", context do
      zipper = Z.down(context.zipper)
      assert Z.left(zipper) == {:error, :left_from_leftmost}
    end

    test "moves focus to the sibling to the left of the current focus", context do
      zipper = Z.down(context.zipper)
      zipper = zipper |> Z.right |> Z.right |> Z.right
      zipper = Z.left(zipper)

      assert zipper.focus == 2
      assert zipper.crumbs == %{
        left: [[], 1],
        right: [[3,4,[5, 6], [7]], 8],
        pnodes: nil,
        ppath: [context.list]
      }
    end
  end

  describe "up" do
    test "returns an error if called on root", context do
      assert Z.up(context.zipper) == {:error, :up_from_root}
    end

    test "moves focus to the current focus' parent", context do
      zipper = context.zipper |> Z.down |> Z.right |> Z.right |> Z.right |> Z.down
               |> Z.right |> Z.right |> Z.down

      zipper = Z.up(zipper)

      assert zipper.focus == [5,6]
      assert zipper.crumbs == %{
        left: [4,3],
        right: [[7]],
        pnodes: %{
          left: [2,[],1],
          right: [8],
          pnodes: nil,
          ppath: [context.list]
        },
        ppath: [[3,4,[5,6],[7]], context.list]
      }
    end
  end

  describe "rightmost" do
    test "returns an error if called on the root", context do
      assert Z.rightmost(context.zipper) == {:error, :rightmost_from_root}
    end

    test "moves focus to the rightmost sibling of the current focus", context do
      zipper = Z.down(context.zipper)
      zipper = Z.rightmost(zipper)

      assert zipper.focus == 8
      assert zipper.crumbs == %{
        left: [[3,4,[5,6],[7]],2,[],1],
        right: [],
        pnodes: nil,
        ppath: [context.list]
      }
    end

    test "remains in place if called on the rightmost sibling", context do
      zipper = context.zipper |> Z.down |> Z.rightmost
      assert Z.rightmost(zipper) == zipper
    end
  end

  describe "leftmost" do
    test "returns an error if called on the root", context do
      assert Z.leftmost(context.zipper) == {:error, :leftmost_from_root}
    end

    test "moves focus to the leftmost sibling of the current focus", context do
      zipper = context.zipper |> Z.down |> Z.right |> Z.right
      zipper = Z.leftmost(zipper)

      assert zipper.focus == 1
      assert zipper.crumbs == %{
        left: [],
        right: [[],2,[3,4,[5,6],[7]],8],
        pnodes: nil,
        ppath: [context.list]
      }
    end

    test "remains in place if called on the leftmost sibling", context do
      zipper = context.zipper |> Z.down
      assert Z.leftmost(zipper) == zipper
    end
  end
end