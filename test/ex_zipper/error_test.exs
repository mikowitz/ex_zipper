defmodule ExZipper.ErrorTest do
  use ExUnit.Case, async: true
  alias ExZipper.Zipper
  import ExZipper.TestHelpers

  @reasons [
    :down_from_leaf,
    :down_from_empty_branch,
    :up_from_root,
    :right_from_root,
    :right_from_rightmost,
    :left_from_root,
    :left_from_leftmost,
    :rightmost_from_root,
    :leftmost_from_root,
    :prev_of_end,
    :lefts_of_root,
    :rights_of_root,
    :children_of_leaf,
    :insert_left_of_root,
    :insert_right_of_root,
    :insert_child_of_leaf,
    :append_child_of_leaf,
    :remove_root,
    :down_from_end,
    :up_from_end,
    :right_from_end,
    :left_from_end,
    :rightmost_from_end,
    :leftmost_from_end,
    :lefts_of_end,
    :rights_of_end,
    :path_of_end,
    :insert_left_of_end,
    :insert_right_of_end,
    :remove_end
  ]

  setup do
    [zipper: Zipper.list_zipper([1, [], [2, 3, [4, 5]]])]
  end

  describe "message/1" do
    test "gives every reason a readable message" do
      for reason <- @reasons do
        message = Exception.message(ExZipper.Error.exception(reason: reason))

        assert is_binary(message)
        assert message != ""
        refute message == inspect(reason)
        refute String.starts_with?(message, "ExZipper error: ")
      end
    end

    test "falls back to a generic message for an unknown reason" do
      message = Exception.message(ExZipper.Error.exception(reason: :something_else))

      assert message == "ExZipper error: :something_else"
    end

    test "gives every reason a different message" do
      messages = Enum.map(@reasons, &Exception.message(ExZipper.Error.exception(reason: &1)))

      assert length(Enum.uniq(messages)) == length(@reasons)
    end
  end

  describe "the error's focus" do
    test "is the node the zipper was focused on when the operation failed", context do
      error =
        assert_zipper_error(:down_from_leaf, fn ->
          context.zipper |> Zipper.down() |> Zipper.down()
        end)

      assert error.focus == 1
    end
  end

  describe "pipelines" do
    test "raise at the step that failed, not at a later step", context do
      assert_zipper_error(:up_from_root, fn ->
        context.zipper |> Zipper.up() |> Zipper.down()
      end)
    end

    test "raise when the last step fails, instead of returning an error tuple", context do
      assert_zipper_error(:left_from_leftmost, fn ->
        context.zipper |> Zipper.down() |> Zipper.left()
      end)
    end

    test "raise when an edit in the middle of a pipeline fails", context do
      assert_zipper_error(:insert_child_of_leaf, fn ->
        context.zipper
        |> Zipper.down()
        |> Zipper.insert_child(0)
        |> Zipper.root()
      end)
    end

    test "return a zipper when every step succeeds", context do
      zipper =
        context.zipper
        |> Zipper.down()
        |> Zipper.rightmost()
        |> Zipper.down()
        |> Zipper.edit(&(&1 * 10))
        |> Zipper.root()

      assert Zipper.node(zipper) == [1, [], [20, 3, [4, 5]]]
    end
  end

  describe "depth-first walks" do
    test "do not raise when they reach leaves, empty branches, or the end of the tree",
         context do
      assert Zipper.to_list(context.zipper) ==
               [[1, [], [2, 3, [4, 5]]], 1, [], [2, 3, [4, 5]], 2, 3, [4, 5], 4, 5]

      assert context.zipper |> Zipper.find_all(&is_integer/1) |> length() == 5

      assert context.zipper |> Zipper.map(& &1) |> Zipper.node() ==
               [1, [], [2, 3, [4, 5]]]
    end

    test "can step backwards with prev from the last node to the root", context do
      last = context.zipper |> Zipper.find(&(&1 == 5))

      nodes =
        last
        |> Stream.iterate(&Zipper.prev/1)
        |> Enum.take(9)
        |> Enum.map(&Zipper.node/1)

      assert nodes == [5, 4, [4, 5], 3, 2, [2, 3, [4, 5]], [], 1, [1, [], [2, 3, [4, 5]]]]
    end

    test "can remove nodes without raising", context do
      zipper =
        context.zipper
        |> Zipper.find(&(&1 == []))
        |> Zipper.remove()
        |> Zipper.root()

      assert Zipper.node(zipper) == [1, [2, 3, [4, 5]]]
    end
  end

  describe "the end of a depth-first walk" do
    setup context do
      walked =
        context.zipper
        |> Stream.iterate(&Zipper.next/1)
        |> Enum.find(&Zipper.end?/1)

      [walked: walked]
    end

    test "raises an ExZipper.Error when navigating", context do
      assert_zipper_error(:down_from_end, fn -> Zipper.down(context.walked) end)
      assert_zipper_error(:up_from_end, fn -> Zipper.up(context.walked) end)
      assert_zipper_error(:right_from_end, fn -> Zipper.right(context.walked) end)
      assert_zipper_error(:left_from_end, fn -> Zipper.left(context.walked) end)
      assert_zipper_error(:rightmost_from_end, fn -> Zipper.rightmost(context.walked) end)
      assert_zipper_error(:leftmost_from_end, fn -> Zipper.leftmost(context.walked) end)
      assert_zipper_error(:prev_of_end, fn -> Zipper.prev(context.walked) end)
    end

    test "raises an ExZipper.Error when querying siblings or the path", context do
      assert_zipper_error(:lefts_of_end, fn -> Zipper.lefts(context.walked) end)
      assert_zipper_error(:rights_of_end, fn -> Zipper.rights(context.walked) end)
      assert_zipper_error(:path_of_end, fn -> Zipper.path(context.walked) end)
    end

    test "raises an ExZipper.Error when inserting siblings or removing", context do
      assert_zipper_error(:insert_left_of_end, fn -> Zipper.insert_left(context.walked, 0) end)
      assert_zipper_error(:insert_right_of_end, fn -> Zipper.insert_right(context.walked, 0) end)
      assert_zipper_error(:remove_end, fn -> Zipper.remove(context.walked) end)
    end

    test "records the root as the error's focus", context do
      error = assert_zipper_error(:down_from_end, fn -> Zipper.down(context.walked) end)

      assert error.focus == [1, [], [2, 3, [4, 5]]]
    end

    test "raises in a pipeline that tries to continue after the walk", context do
      assert_zipper_error(:down_from_end, fn ->
        context.walked |> Zipper.next() |> Zipper.down() |> Zipper.right()
      end)
    end

    test "stays at the end when next is called again", context do
      zipper = Zipper.next(context.walked)

      assert Zipper.end?(zipper)
      assert zipper == context.walked
    end

    test "can be navigated again after an explicit call to root", context do
      zipper = Zipper.root(context.walked)

      refute Zipper.end?(zipper)
      assert Zipper.path(zipper) == []
      assert zipper |> Zipper.down() |> Zipper.right() |> Zipper.node() == []
      assert zipper |> Zipper.next() |> Zipper.node() == 1
    end
  end
end
