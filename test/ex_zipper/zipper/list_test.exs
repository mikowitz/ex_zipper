defmodule ExZipper.Zipper.ListTest do
  use ExUnit.Case, async: true
  alias ExZipper.Zipper
  import ExZipper.TestHelpers

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
    test "raises an ExZipper.Error if called on a leaf", context do
      zipper = %{context.zipper | focus: 11}
      assert_zipper_error(:down_from_leaf, fn -> Zipper.down(zipper) end)
    end

    test "raises an ExZipper.Error if called on an empty branch", context do
      zipper = %{context.zipper | focus: []}
      assert_zipper_error(:down_from_empty_branch, fn -> Zipper.down(zipper) end)
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
    test "raises an ExZipper.Error if called on the root", context do
      assert_zipper_error(:right_from_root, fn -> Zipper.right(context.zipper) end)
    end

    test "raises an ExZipper.Error if called on the rightmost sibling", context do
      zipper =
        context.zipper
        |> Zipper.down()
        |> Zipper.right()
        |> Zipper.right()
        |> Zipper.right()
        |> Zipper.right()

      assert_zipper_error(:right_from_rightmost, fn -> Zipper.right(zipper) end)
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
    test "raises an ExZipper.Error if called on the root", context do
      assert_zipper_error(:left_from_root, fn -> Zipper.left(context.zipper) end)
    end

    test "raises an ExZipper.Error if called on the leftmost sibling", context do
      zipper = Zipper.down(context.zipper)
      assert_zipper_error(:left_from_leftmost, fn -> Zipper.left(zipper) end)
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
    test "raises an ExZipper.Error if called on root", context do
      assert_zipper_error(:up_from_root, fn -> Zipper.up(context.zipper) end)
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
    test "raises an ExZipper.Error if called on the root", context do
      assert_zipper_error(:rightmost_from_root, fn -> Zipper.rightmost(context.zipper) end)
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
    test "raises an ExZipper.Error if called on the root", context do
      assert_zipper_error(:leftmost_from_root, fn -> Zipper.leftmost(context.zipper) end)
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
      zipper =
        context.zipper
        |> Zipper.down()
        |> Zipper.right()
        |> Zipper.right()
        |> Zipper.right()
        |> Zipper.down()

      assert Zipper.root(zipper) == context.zipper
    end

    test "returns to the root from the end of a depth-first walk", context do
      zipper =
        context.zipper
        |> Stream.iterate(&Zipper.next/1)
        |> Enum.find(&Zipper.end?/1)

      zipper = Zipper.root(zipper)

      assert zipper.focus == context.list
      assert zipper.crumbs == nil
      refute Zipper.end?(zipper)
    end

    test "persists edits made before reaching the end of a depth-first walk", context do
      zipper =
        context.zipper
        |> Zipper.find(&(&1 == [5, 6]))
        |> Zipper.replace(:replaced)
        |> Stream.iterate(&Zipper.next/1)
        |> Enum.find(&Zipper.end?/1)

      zipper = Zipper.root(zipper)

      assert zipper.focus == [1, [], 2, [3, 4, :replaced, [7]], 8]
      assert zipper.crumbs == nil
    end
  end

  describe "lefts" do
    test "raises an ExZipper.Error if called on the root", context do
      assert_zipper_error(:lefts_of_root, fn -> Zipper.lefts(context.zipper) end)
    end

    test "returns all siblings to the left of the current focus", context do
      zipper = Zipper.down(context.zipper)

      assert Zipper.lefts(zipper) == []

      zipper = zipper |> Zipper.right() |> Zipper.right()

      assert Zipper.lefts(zipper) == [1, []]
    end
  end

  describe "rights" do
    test "raises an ExZipper.Error if called on the root", context do
      assert_zipper_error(:rights_of_root, fn -> Zipper.rights(context.zipper) end)
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

    test "raises an ExZipper.Error if called on a leaf", context do
      zipper = Zipper.down(context.zipper)

      assert_zipper_error(:children_of_leaf, fn -> Zipper.children(zipper) end)
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
      zipper =
        context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right() |> Zipper.right()

      zipper = Zipper.replace(zipper, [3, 4, 5, 6, 7])
      zipper = Zipper.root(zipper)

      assert zipper.focus == [1, [], 2, [3, 4, 5, 6, 7], 8]
    end
  end

  describe "edit" do
    test "replaces the current focus by applying the provided function, persisting the change when moving back up the zipper",
         context do
      zipper =
        context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right() |> Zipper.right()

      zipper = Zipper.edit(zipper, fn l -> List.flatten(l) end)
      zipper = Zipper.root(zipper)

      assert zipper.focus == [1, [], 2, [3, 4, 5, 6, 7], 8]
    end
  end

  describe "insert_left" do
    test "raises an ExZipper.Error if called on the root", context do
      assert_zipper_error(:insert_left_of_root, fn ->
        Zipper.insert_left(context.zipper, [10, 11, 12])
      end)
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
    test "raises an ExZipper.Error if called on the root", context do
      assert_zipper_error(:insert_right_of_root, fn ->
        Zipper.insert_right(context.zipper, [10, 11, 12])
      end)
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
    test "raises an ExZipper.Error if called on a leaf", context do
      zipper = Zipper.down(context.zipper)

      assert_zipper_error(:insert_child_of_leaf, fn -> Zipper.insert_child(zipper, 11) end)
    end

    test "adds a node as the leftmost child of the current focus", context do
      zipper =
        context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right() |> Zipper.right()

      zipper = Zipper.insert_child(zipper, 11)
      zipper = Zipper.root(zipper)

      assert zipper.focus == [1, [], 2, [11, 3, 4, [5, 6], [7]], 8]
    end
  end

  describe "append_child" do
    test "raises an ExZipper.Error if called on a leaf", context do
      zipper = Zipper.down(context.zipper)

      assert_zipper_error(:append_child_of_leaf, fn -> Zipper.append_child(zipper, 11) end)
    end

    test "adds a node as the rightmost child of the current focus", context do
      zipper =
        context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right() |> Zipper.right()

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
      assert_zipper_error(:prev_of_end, fn -> Zipper.prev(zipper) end)
    end
  end

  describe "end?" do
    test "returns true if at the last node of a depth-first walk through the zipper", context do
      zipper = Zipper.down(context.zipper)

      refute zipper |> Zipper.end?()

      refute zipper
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.end?()

      refute zipper
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.next()
             |> Zipper.end?()

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
    test "raises an ExZipper.Error when called on the root", context do
      assert_zipper_error(:remove_root, fn -> Zipper.remove(context.zipper) end)
    end

    test "removes the current focus, and moves to the prev location in a depth-first walk",
         context do
      zipper = Zipper.down(context.zipper)
      zipper = Zipper.remove(zipper)
      assert zipper.focus == [[], 2, [3, 4, [5, 6], [7]], 8]

      zipper = Zipper.root(zipper)
      assert zipper.focus == [[], 2, [3, 4, [5, 6], [7]], 8]

      zipper =
        context.zipper
        |> Zipper.down()
        |> Zipper.right()
        |> Zipper.right()
        |> Zipper.right()
        |> Zipper.down()
        |> Zipper.right()

      zipper = Zipper.remove(zipper)
      assert zipper.focus == 3
      zipper = Zipper.root(zipper)
      assert zipper.focus == [1, [], 2, [3, [5, 6], [7]], 8]
    end
  end

  describe "remove landing on the previous node in a depth-first walk" do
    test "lands on the left sibling when it is a leaf", context do
      zipper = context.zipper |> Zipper.find(&(&1 == [3, 4, [5, 6], [7]])) |> Zipper.remove()

      assert Zipper.node(zipper) == 2
      assert zipper |> Zipper.root() |> Zipper.node() == [1, [], 2, 8]
    end

    test "lands on the left sibling when it is an empty branch", context do
      zipper = context.zipper |> Zipper.find(&(&1 == 2)) |> Zipper.remove()

      assert Zipper.node(zipper) == []
      assert zipper |> Zipper.root() |> Zipper.node() == [1, [], [3, 4, [5, 6], [7]], 8]
    end

    test "lands on the deepest rightmost descendant of the left sibling", context do
      zipper = context.zipper |> Zipper.find(&(&1 == 8)) |> Zipper.remove()

      assert Zipper.node(zipper) == 7
      assert zipper |> Zipper.root() |> Zipper.node() == [1, [], 2, [3, 4, [5, 6], [7]]]
    end

    test "lands on the rightmost child of a left sibling branch below the root", context do
      zipper = context.zipper |> Zipper.find(&(&1 == [7])) |> Zipper.remove()

      assert Zipper.node(zipper) == 6
      assert zipper |> Zipper.root() |> Zipper.node() == [1, [], 2, [3, 4, [5, 6]], 8]
    end

    test "lands on a leaf several levels down inside the left sibling" do
      zipper =
        [[1, [2, [3, [4]]]], 5]
        |> Zipper.list_zipper()
        |> Zipper.find(&(&1 == 5))
        |> Zipper.remove()

      assert Zipper.node(zipper) == 4
      assert zipper |> Zipper.root() |> Zipper.node() == [[1, [2, [3, [4]]]]]
    end

    test "lands on an empty branch that is the rightmost descendant of the left sibling" do
      zipper =
        [[1, []], 2]
        |> Zipper.list_zipper()
        |> Zipper.find(&(&1 == 2))
        |> Zipper.remove()

      assert Zipper.node(zipper) == []
      assert Zipper.lefts(zipper) == [1]
      assert zipper |> Zipper.root() |> Zipper.node() == [[1, []]]
    end

    test "lands on a leaf that follows a branch inside the left sibling" do
      zipper =
        [[[1, 2], 3], 4]
        |> Zipper.list_zipper()
        |> Zipper.find(&(&1 == 4))
        |> Zipper.remove()

      assert Zipper.node(zipper) == 3
      assert Zipper.lefts(zipper) == [[1, 2]]
    end

    test "lands on the parent, without the removed node, when removing the leftmost child",
         context do
      zipper = context.zipper |> Zipper.find(&(&1 == 3)) |> Zipper.remove()

      assert Zipper.node(zipper) == [4, [5, 6], [7]]
      assert Zipper.lefts(zipper) == [1, [], 2]
      assert zipper |> Zipper.root() |> Zipper.node() == [1, [], 2, [4, [5, 6], [7]], 8]
    end

    test "leaves an empty branch when removing an only child", context do
      zipper = context.zipper |> Zipper.find(&(&1 == 7)) |> Zipper.remove()

      assert Zipper.node(zipper) == []
      assert Zipper.lefts(zipper) == [3, 4, [5, 6]]
      assert zipper |> Zipper.root() |> Zipper.node() == [1, [], 2, [3, 4, [5, 6], []], 8]
    end

    test "leaves an empty root when removing the root's only child" do
      zipper = [1] |> Zipper.list_zipper() |> Zipper.down() |> Zipper.remove()

      assert Zipper.node(zipper) == []
      assert Zipper.path(zipper) == []
    end

    test "returns a zipper that can keep walking past where the node was", context do
      zipper = context.zipper |> Zipper.find(&(&1 == [7])) |> Zipper.remove()

      assert zipper |> Zipper.next() |> Zipper.node() == 8
    end

    test "returns a zipper at the end of the tree when the last node is removed", context do
      zipper = context.zipper |> Zipper.find(&(&1 == 8)) |> Zipper.remove()

      assert Zipper.rights(zipper) == []
      assert zipper |> Zipper.next() |> Zipper.end?()
    end

    test "returns a zipper that can navigate back up to the edited parents", context do
      zipper = context.zipper |> Zipper.find(&(&1 == 8)) |> Zipper.remove()

      assert zipper |> Zipper.up() |> Zipper.node() == [7]
      assert zipper |> Zipper.up() |> Zipper.up() |> Zipper.node() == [3, 4, [5, 6], [7]]

      assert zipper |> Zipper.up() |> Zipper.up() |> Zipper.up() |> Zipper.node() ==
               [1, [], 2, [3, 4, [5, 6], [7]]]
    end

    test "can be called repeatedly, removing the previous node each time", context do
      zipper =
        context.zipper
        |> Zipper.find(&(&1 == 8))
        |> Zipper.remove()
        |> Zipper.remove()

      assert Zipper.node(zipper) == []
      assert zipper |> Zipper.root() |> Zipper.node() == [1, [], 2, [3, 4, [5, 6], []]]
    end

    test "removes a whole subtree and lands before it", context do
      zipper = context.zipper |> Zipper.find(&(&1 == [5, 6])) |> Zipper.remove()

      assert Zipper.node(zipper) == 4
      assert zipper |> Zipper.root() |> Zipper.node() == [1, [], 2, [3, 4, [7]], 8]
    end

    for tree <- [
          [1, [], 2, [3, 4, [5, 6], [7]], 8],
          [[1, []], 2],
          [[1, [2, [3, [4]]]], 5],
          [[[1, 2], 3], 4],
          [[], [[]], [[], []]]
        ] do
      test "agrees with prev and deletes only the removed node, at every location of #{inspect(tree, charlists: :as_lists)}" do
        tree = unquote(Macro.escape(tree))

        tree
        |> Zipper.list_zipper()
        |> Stream.iterate(&Zipper.next/1)
        |> Stream.take_while(&(not Zipper.end?(&1)))
        |> Stream.drop(1)
        |> Enum.each(fn location ->
          removed = Zipper.remove(location)
          prev = Zipper.prev(location)
          index_path = index_path(location)
          label = "removing at #{inspect(index_path)}"

          if Zipper.lefts(location) != [] do
            assert Zipper.node(removed) == Zipper.node(prev), label
          end

          assert length(Zipper.path(removed)) == length(Zipper.path(prev)), label

          if Zipper.path(prev) != [] do
            assert Zipper.lefts(removed) == Zipper.lefts(prev), label
          end

          assert removed |> Zipper.root() |> Zipper.node() == delete_at_path(tree, index_path),
                 label
        end)
      end
    end
  end

  defp index_path(%Zipper{crumbs: nil}), do: []

  defp index_path(zipper),
    do: index_path(Zipper.up(zipper)) ++ [length(Zipper.lefts(zipper))]

  defp delete_at_path(list, [index]), do: List.delete_at(list, index)

  defp delete_at_path(list, [index | rest]),
    do: List.update_at(list, index, &delete_at_path(&1, rest))

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

  describe "find" do
    test "returns a zipper focused on the first node in a depth-first walk matching the predicate",
         context do
      zipper = Zipper.find(context.zipper, fn node -> is_integer(node) and node > 2 end)

      assert zipper.focus == 3
      assert Zipper.path(zipper) == [context.list, [3, 4, [5, 6], [7]]]
    end

    test "considers the current focus as a possible match", context do
      zipper = Zipper.find(context.zipper, &is_list/1)

      assert zipper.focus == context.list
      assert zipper.crumbs == nil
    end

    test "searches from the current focus to the end of the walk, not the whole tree", context do
      zipper =
        context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right() |> Zipper.right()

      assert Zipper.find(zipper, &(&1 == 1)) == nil
      assert Zipper.find(zipper, &(&1 == 8)).focus == 8
    end

    test "can be combined with next to find successive matches", context do
      even? = fn node -> is_integer(node) and rem(node, 2) == 0 end

      zipper = Zipper.find(context.zipper, even?)
      assert zipper.focus == 2

      zipper = zipper |> Zipper.next() |> Zipper.find(even?)
      assert zipper.focus == 4
    end

    test "returns a zipper whose focus can be edited and persisted back to the root", context do
      zipper =
        context.zipper
        |> Zipper.find(&(&1 == [5, 6]))
        |> Zipper.replace(:replaced)
        |> Zipper.root()

      assert zipper.focus == [1, [], 2, [3, 4, :replaced, [7]], 8]
    end

    test "returns nil if no node matches the predicate", context do
      assert Zipper.find(context.zipper, &(&1 == 99)) == nil
    end

    test "returns nil if called on the end of the walk", context do
      zipper = %{context.zipper | crumbs: :end}

      assert Zipper.find(zipper, fn _ -> true end) == nil
    end
  end

  describe "find_all" do
    test "returns a list of zippers focused on every node matching the predicate, in depth-first order",
         context do
      zippers =
        Zipper.find_all(context.zipper, fn node -> is_integer(node) and rem(node, 2) == 0 end)

      assert Enum.map(zippers, &Zipper.node/1) == [2, 4, 6, 8]
    end

    test "returns zippers positioned at each match within the tree", context do
      [zipper] = Zipper.find_all(context.zipper, &(&1 == 6))

      assert Zipper.path(zipper) == [context.list, [3, 4, [5, 6], [7]], [5, 6]]
      assert Zipper.lefts(zipper) == [5]
      assert Zipper.rights(zipper) == []
    end

    test "searches from the current focus to the end of the walk, not the whole tree", context do
      zipper =
        context.zipper |> Zipper.down() |> Zipper.right() |> Zipper.right() |> Zipper.right()

      zippers = Zipper.find_all(zipper, fn node -> is_integer(node) and rem(node, 2) == 0 end)

      assert Enum.map(zippers, &Zipper.node/1) == [4, 6, 8]
    end

    test "returns an empty list if no node matches the predicate", context do
      assert Zipper.find_all(context.zipper, &(&1 == 99)) == []
    end
  end

  describe "map" do
    test "applies the function to every node in a depth-first walk, returning a zipper at the root",
         context do
      zipper =
        Zipper.map(context.zipper, fn
          node when is_integer(node) -> node * 10
          node -> node
        end)

      assert zipper.focus == [10, [], 20, [30, 40, [50, 60], [70]], 80]
      assert zipper.crumbs == nil
      refute Zipper.end?(zipper)
    end

    test "visits every node, branches included, in depth-first order", context do
      test_pid = self()

      Zipper.map(context.zipper, fn node ->
        send(test_pid, {:visited, node})
        node
      end)

      visited =
        for _ <- Zipper.to_list(context.zipper) do
          assert_received {:visited, node}
          node
        end

      assert visited == Zipper.to_list(context.zipper)
      refute_received {:visited, _}
    end

    test "transforms a branch before walking into its new children", context do
      zipper =
        Zipper.map(context.zipper, fn
          [7] -> [7, 9]
          9 -> :nine
          node -> node
        end)

      assert zipper.focus == [1, [], 2, [3, 4, [5, 6], [7, :nine]], 8]
    end

    test "transforms only the nodes from the current focus to the end of the walk", context do
      zipper =
        context.zipper
        |> Zipper.down()
        |> Zipper.right()
        |> Zipper.right()
        |> Zipper.right()
        |> Zipper.map(fn
          node when is_integer(node) -> node * 10
          node -> node
        end)

      assert zipper.focus == [1, [], 2, [30, 40, [50, 60], [70]], 80]
      assert zipper.crumbs == nil
    end

    test "returns the unchanged tree at the root if called on the end of the walk", context do
      zipper =
        context.zipper
        |> Stream.iterate(&Zipper.next/1)
        |> Enum.find(&Zipper.end?/1)
        |> Zipper.map(fn _ -> :should_not_be_applied end)

      assert zipper.focus == context.list
      assert zipper.crumbs == nil
      refute Zipper.end?(zipper)
    end
  end
end
