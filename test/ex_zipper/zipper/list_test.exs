defmodule ExZipper.Zipper.ListTest do
  use ExUnit.Case, async: true
  alias ExZipper.Zipper, as: Zipper

  doctest ExZipper.Zipper

  setup do
    list = [1, [], 2, [3, 4, [5, 6], [7]], 8]

    zipper =
      Zipper.zipper(
        &is_list/1,
        & &1,
        fn _node, children -> children end,
        list
      )

    {:ok, %{list: list, zipper: zipper}}
  end

  describe "node/1" do
    test "returns the current focus of the zipper", context do
      assert Zipper.node(context.zipper) == context.list
    end
  end

  describe "down/1" do
    test "returns an error if called on a leaf", context do
      zipper = %{context.zipper | focus: 11}
      assert Zipper.down(zipper) == {:error, :down_from_leaf}
    end

    test "returns an error if called on an empty branch", context do
      zipper = %{context.zipper | focus: []}
      assert Zipper.down(zipper) == {:error, :down_from_empty_branch}
    end

    test "moves focus to the first child of the current focus", context do
      zipper = Zipper.down(context.zipper)
      assert Zipper.node(zipper) == 1

      assert zipper.crumbs == %{
               left: [],
               right: [[], 2, [3, 4, [5, 6], [7]], 8],
               pnodes: nil,
               ppath: [context.list]
             }
    end
  end

  describe "right/1" do
    test "returns an error if called on the root", context do
      assert Zipper.right(context.zipper) == {:error, :right_from_root}
    end

    test "returns an error if called on the rightmost sibling", context do
      zipper = context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right() |> Zipper.right() |> Zipper.right()
      assert Zipper.right(zipper) == {:error, :right_from_rightmost}
    end

    test "moves focus to the sibling to the right of the current focus", context do
      zipper = Zipper.down(context.zipper)
      zipper = Zipper.right(zipper)
      assert zipper.focus == []

      assert zipper.crumbs == %{
               left: [1],
               right: [2, [3, 4, [5, 6], [7]], 8],
               pnodes: nil,
               ppath: [context.list]
             }
    end
  end

  describe "left" do
    test "returns an error if called on the root", context do
      assert Zipper.left(context.zipper) == {:error, :left_from_root}
    end

    test "returns an error if called on the leftmost sibling", context do
      zipper = Zipper.down(context.zipper)
      assert Zipper.left(zipper) == {:error, :left_from_leftmost}
    end

    test "moves focus to the sibling to the left of the current focus", context do
      zipper = Zipper.down(context.zipper)
      zipper = zipper |> Zipper.right() |> Zipper.right() |> Zipper.right()
      zipper = Zipper.left(zipper)

      assert zipper.focus == 2

      assert zipper.crumbs == %{
               left: [[], 1],
               right: [[3, 4, [5, 6], [7]], 8],
               pnodes: nil,
               ppath: [context.list]
             }
    end
  end

  describe "up" do
    test "returns an error if called on root", context do
      assert Zipper.up(context.zipper) == {:error, :up_from_root}
    end

    test "moves focus to the current focus' parent", context do
      zipper =
        context.zipper
        |> Zipper.down()
        |> Zipper.right()
        |> Zipper.right()
        |> Zipper.right()
        |> Zipper.down()
        |> Zipper.right()
        |> Zipper.right()
        |> Zipper.down()

      zipper = Zipper.up(zipper)

      assert zipper.focus == [5, 6]

      assert zipper.crumbs == %{
               left: [4, 3],
               right: [[7]],
               pnodes: %{
                 left: [2, [], 1],
                 right: [8],
                 pnodes: nil,
                 ppath: [context.list]
               },
               ppath: [[3, 4, [5, 6], [7]], context.list]
             }
    end
  end

  describe "rightmost" do
    test "returns an error if called on the root", context do
      assert Zipper.rightmost(context.zipper) == {:error, :rightmost_from_root}
    end

    test "moves focus to the rightmost sibling of the current focus", context do
      zipper = Zipper.down(context.zipper)
      zipper = Zipper.rightmost(zipper)

      assert zipper.focus == 8

      assert zipper.crumbs == %{
               left: [[3, 4, [5, 6], [7]], 2, [], 1],
               right: [],
               pnodes: nil,
               ppath: [context.list]
             }
    end

    test "remains in place if called on the rightmost sibling", context do
      zipper = context.zipper |> Zipper.down() |> Zipper.rightmost()
      assert Zipper.rightmost(zipper) == zipper
    end
  end

  describe "leftmost" do
    test "returns an error if called on the root", context do
      assert Zipper.leftmost(context.zipper) == {:error, :leftmost_from_root}
    end

    test "moves focus to the leftmost sibling of the current focus", context do
      zipper = context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right()
      zipper = Zipper.leftmost(zipper)

      assert zipper.focus == 1

      assert zipper.crumbs == %{
               left: [],
               right: [[], 2, [3, 4, [5, 6], [7]], 8],
               pnodes: nil,
               ppath: [context.list]
             }
    end

    test "remains in place if called on the leftmost sibling", context do
      zipper = context.zipper |> Zipper.down()
      assert Zipper.leftmost(zipper) == zipper
    end
  end

  describe "root" do
    test "remains in place if called at the root", context do
      assert context.zipper == Zipper.root(context.zipper)
    end

    test "returns to the root from the current focus", context do
      zipper = context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right() |> Zipper.right() |> Zipper.down()

      assert Zipper.root(zipper) == context.zipper
    end
  end

  describe "lefts" do
    test "returns an error if called on the root", context do
      assert Zipper.lefts(context.zipper) == {:error, :lefts_of_root}
    end

    test "returns all siblings to the left of the current focus", context do
      zipper = Zipper.down(context.zipper)

      assert Zipper.lefts(zipper) == []

      zipper = zipper |> Zipper.right() |> Zipper.right()

      assert Zipper.lefts(zipper) == [1, []]
    end
  end

  describe "rights" do
    test "returns an error if called on the root", context do
      assert Zipper.rights(context.zipper) == {:error, :rights_of_root}
    end

    test "returns all siblings to the right of the current focus", context do
      zipper = Zipper.down(context.zipper)

      assert Zipper.rights(zipper) == [[], 2, [3, 4, [5, 6], [7]], 8]

      zipper = context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right()

      assert Zipper.rights(zipper) == [[3, 4, [5, 6], [7]], 8]
    end
  end

  describe "path" do
    test "returns an empty list if called at the root", context do
      assert Zipper.path(context.zipper) == []
    end

    test "returns a path of nodes leading to the current focus from the root", context do
      zipper =
        context.zipper
        |> Zipper.down()
        |> Zipper.rightmost()
        |> Zipper.left()
        |> Zipper.down()
        |> Zipper.right()
        |> Zipper.right()
        |> Zipper.down()

      assert Zipper.node(zipper) == 5
      assert Zipper.path(zipper) == [context.list, [3, 4, [5, 6], [7]], [5, 6]]
    end
  end

  describe "branch?" do
    test "returns true if the current focus is a branch", context do
      assert Zipper.branch?(context.zipper)
    end

    test "returns false if the current focus is not a branch", context do
      zipper = Zipper.down(context.zipper)

      refute Zipper.branch?(zipper)
    end
  end

  describe "children" do
    test "returns the children of the current focus if it is a branch", context do
      assert Zipper.children(context.zipper) == context.list
    end

    test "returns an error if called on a leaf", context do
      zipper = Zipper.down(context.zipper)

      assert Zipper.children(zipper) == {:error, :children_of_leaf}
    end
  end

  describe "make_node" do
    test "returns a new branch node, given an existing node and new children", context do
      new_node = Zipper.make_node(context.zipper, [1, 2, 3], [4, 5, 6])
      assert new_node == [4, 5, 6]
    end
  end

  describe "replace" do
    test "replaces the current focus, persisting the change when moving back up the zipper",
         context do
      zipper = context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right() |> Zipper.right()
      zipper = Zipper.replace(zipper, [3, 4, 5, 6, 7])
      zipper = Zipper.root(zipper)

      assert zipper.focus == [1, [], 2, [3, 4, 5, 6, 7], 8]
    end
  end

  describe "edit" do
    test "replaces the current focus by applying the provided function, persisting the change when moving back up the zipper",
         context do
      zipper = context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right() |> Zipper.right()
      zipper = Zipper.edit(zipper, fn l -> List.flatten(l) end)
      zipper = Zipper.root(zipper)

      assert zipper.focus == [1, [], 2, [3, 4, 5, 6, 7], 8]
    end
  end

  describe "insert_left" do
    test "returns an error if called on the root", context do
      assert Zipper.insert_left(context.zipper, [10, 11, 12]) == {:error, :insert_left_of_root}
    end

    test "inserts the provided node to the left of the current focus, without changing focus",
         context do
      zipper = Zipper.down(context.zipper)
      zipper = Zipper.insert_left(zipper, [10, 11, 12])
      zipper = Zipper.root(zipper)

      assert zipper.focus == [[10, 11, 12], 1, [], 2, [3, 4, [5, 6], [7]], 8]
    end
  end

  describe "insert_right" do
    test "returns an error if called on the root", context do
      assert Zipper.insert_right(context.zipper, [10, 11, 12]) == {:error, :insert_right_of_root}
    end

    test "inserts the provided node to the right of the current focus, without changing focus",
         context do
      zipper = Zipper.down(context.zipper)
      zipper = Zipper.insert_right(zipper, [10, 11, 12])
      zipper = Zipper.root(zipper)

      assert zipper.focus == [1, [10, 11, 12], [], 2, [3, 4, [5, 6], [7]], 8]
    end
  end

  describe "insert_child" do
    test "returns an error if called on a leaf", context do
      zipper = Zipper.down(context.zipper)

      assert Zipper.insert_child(zipper, 11) == {:error, :insert_child_of_leaf}
    end

    test "adds a node as the leftmost child of the current focus", context do
      zipper = context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right() |> Zipper.right()

      zipper = Zipper.insert_child(zipper, 11)
      zipper = Zipper.root(zipper)

      assert zipper.focus == [1, [], 2, [11, 3, 4, [5, 6], [7]], 8]
    end
  end

  describe "append_child" do
    test "returns an error if called on a leaf", context do
      zipper = Zipper.down(context.zipper)

      assert Zipper.append_child(zipper, 11) == {:error, :append_child_of_leaf}
    end

    test "adds a node as the rightmost child of the current focus", context do
      zipper = context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right() |> Zipper.right()

      zipper = Zipper.append_child(zipper, 11)
      zipper = Zipper.root(zipper)

      assert zipper.focus == [1, [], 2, [3, 4, [5, 6], [7], 11], 8]
    end
  end

  describe "next" do
    test "navigates to the next node in a depth-first walk", context do
      zipper = Zipper.next(context.zipper)
      assert zipper.focus == 1
      zipper = Zipper.next(zipper)
      assert zipper.focus == []
      zipper = Zipper.next(zipper)
      assert zipper.focus == 2
      zipper = Zipper.next(zipper)
      assert zipper.focus == [3, 4, [5, 6], [7]]
      zipper = Zipper.next(zipper)
      assert zipper.focus == 3
      zipper = Zipper.next(zipper)
      assert zipper.focus == 4
      zipper = Zipper.next(zipper)
      assert zipper.focus == [5, 6]
      zipper = Zipper.next(zipper)
      assert zipper.focus == 5
      zipper = Zipper.next(zipper)
      assert zipper.focus == 6
      zipper = Zipper.next(zipper)
      assert zipper.focus == [7]
      zipper = Zipper.next(zipper)
      assert zipper.focus == 7
      zipper = Zipper.next(zipper)
      assert zipper.focus == 8
      zipper = Zipper.next(zipper)
      assert zipper.focus == context.list
      assert Zipper.end?(zipper)
      zipper = Zipper.next(zipper)
      assert zipper.focus == context.list
      assert Zipper.end?(zipper)
    end
  end

  describe "prev" do
    test "navigates to the previous node in a depth-first walk", context do
      zipper =
        context.zipper
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()

      assert zipper.focus == 8
      refute Zipper.end?(zipper)
      zipper = Zipper.prev(zipper)
      assert zipper.focus == 7
      zipper = Zipper.prev(zipper)
      assert zipper.focus == [7]
      zipper = Zipper.prev(zipper)
      assert zipper.focus == 6
      zipper = Zipper.prev(zipper)
      assert zipper.focus == 5
      zipper = Zipper.prev(zipper)
      assert zipper.focus == [5, 6]
      zipper = Zipper.prev(zipper)
      assert zipper.focus == 4
      zipper = Zipper.prev(zipper)
      assert zipper.focus == 3
      zipper = Zipper.prev(zipper)
      assert zipper.focus == [3, 4, [5, 6], [7]]
      zipper = Zipper.prev(zipper)
      assert zipper.focus == 2
      zipper = Zipper.prev(zipper)
      assert zipper.focus == []
      zipper = Zipper.prev(zipper)
      assert zipper.focus == 1
      zipper = Zipper.prev(zipper)
      assert zipper.focus == context.list
    end

    test "can't navigate back from the end of the walk", context do
      zipper =
        context.zipper
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()
        |> Zipper.next()

      assert Zipper.end?(zipper)
      assert Zipper.prev(zipper) == {:error, :prev_of_end}
    end
  end

  describe "end?" do
    test "returns true if at the last node of a depth-first walk through the zipper", context do
      zipper = Zipper.down(context.zipper)

      refute zipper |> Zipper.end?()
      refute zipper |> Zipper.next() |> Zipper.next() |> Zipper.next() |> Zipper.next() |> Zipper.end?()
      refute zipper |> Zipper.next() |> Zipper.next() |> Zipper.next() |> Zipper.next() |> Zipper.end?()

      assert zipper
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.end?()
    end
  end

  describe "remove" do
    test "returns an error when called on the root", context do
      assert Zipper.remove(context.zipper) == {:error, :remove_root}
    end

    test "removes the current focus, and moves to the prev location in a depth-first walk", context do
      zipper = Zipper.down(context.zipper)
      zipper = Zipper.remove(zipper)
      assert zipper.focus == [[], 2, [3, 4, [5, 6], [7]], 8]

      zipper = Zipper.root(zipper)
      assert zipper.focus == [[], 2, [3, 4, [5, 6], [7]], 8]

      zipper =
        context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right() |> Zipper.right() |> Zipper.down() |> Zipper.right()

      zipper = Zipper.remove(zipper)
      assert zipper.focus == 3
      zipper = Zipper.root(zipper)
      assert zipper.focus == [1, [], 2, [3, [5, 6], [7]], 8]
    end
  end

  describe "to_list" do
    test "returns a depth-first list of all elements in the zipper", context do
      assert Zipper.to_list(context.zipper) == [
        [1, [], 2, [3, 4, [5, 6], [7]], 8],
        1,
        [],
        2,
        [3, 4, [5, 6], [7]],
        3,
        4,
        [5, 6],
        5,
        6,
        [7],
        7,
        8
      ]
    end
  end
end
