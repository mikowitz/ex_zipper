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
    :remove_root
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
      end
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
end
