defmodule ExZipper.InspectTest do
  use ExUnit.Case, async: true
  alias ExZipper.Zipper

  defmodule Note do
    defstruct [:note]
  end

  setup do
    [zipper: Zipper.list_zipper([1, [], [2, 3]])]
  end

  describe "at the root" do
    test "shows the focus followed by an ellipsis", context do
      assert inspect(context.zipper) == "#ExZipper.Zipper<[1, [], [2, 3]] ...>"
    end

    test "shows an empty root branch", _context do
      assert inspect(Zipper.list_zipper([])) == "#ExZipper.Zipper<[] ...>"
    end

    test "shows a root that is a leaf" do
      zipper = Zipper.zipper(&is_list/1, & &1, fn _, children -> children end, 5)

      assert inspect(zipper) == "#ExZipper.Zipper<5 ...>"
    end
  end

  describe "below the root" do
    test "shows the focus between ellipses", context do
      assert context.zipper |> Zipper.down() |> inspect() == "#ExZipper.Zipper<... 1 ...>"
    end

    test "shows an empty branch between ellipses", context do
      assert context.zipper |> Zipper.down() |> Zipper.right() |> inspect() ==
               "#ExZipper.Zipper<... [] ...>"
    end

    test "shows a branch below the root between ellipses", context do
      assert context.zipper |> Zipper.find(&(&1 == [2, 3])) |> inspect() ==
               "#ExZipper.Zipper<... [2, 3] ...>"
    end

    test "shows the last node of the walk between ellipses, not as the end", context do
      zipper = Zipper.find(context.zipper, &(&1 == 3))

      refute Zipper.end?(zipper)
      assert inspect(zipper) == "#ExZipper.Zipper<... 3 ...>"
    end

    test "shows the edited focus after an edit", context do
      zipper = context.zipper |> Zipper.down() |> Zipper.replace(:new)

      assert inspect(zipper) == "#ExZipper.Zipper<... :new ...>"
    end
  end

  describe "at the end of a walk" do
    setup context do
      walked =
        context.zipper
        |> Stream.iterate(&Zipper.next/1)
        |> Enum.find(&Zipper.end?/1)

      [walked: walked]
    end

    test "shows an ellipsis followed by the root", context do
      assert inspect(context.walked) == "#ExZipper.Zipper<... [1, [], [2, 3]]>"
    end

    test "shows the root followed by an ellipsis again after root/1", context do
      assert context.walked |> Zipper.root() |> inspect() ==
               "#ExZipper.Zipper<[1, [], [2, 3]] ...>"
    end
  end

  describe "inspect options" do
    test "are applied to the focus, so a large focus is truncated" do
      zipper = Zipper.list_zipper([1, 2, 3, 4, 5])

      assert inspect(zipper, limit: 3) == "#ExZipper.Zipper<[1, 2, 3, ...] ...>"
    end

    test "control how charlists in the focus are shown" do
      zipper = Zipper.list_zipper([104, 105])

      assert inspect(zipper, charlists: :as_lists) == "#ExZipper.Zipper<[104, 105] ...>"
    end
  end

  describe "the output" do
    test "uses the focus's own inspect implementation" do
      zipper =
        Zipper.zipper(
          &is_list/1,
          & &1,
          fn _, children -> children end,
          [%Note{note: "c4"}]
        )
        |> Zipper.down()

      assert inspect(zipper) ==
               "#ExZipper.Zipper<... %ExZipper.InspectTest.Note{note: \"c4\"} ...>"
    end

    test "does not include the stored functions or crumbs", context do
      output = context.zipper |> Zipper.down() |> inspect()

      refute output =~ "#Function"
      refute output =~ "crumbs"
      refute output =~ "functions"
    end

    test "works when the zipper is nested inside other data", context do
      assert inspect([context.zipper]) == "[#ExZipper.Zipper<[1, [], [2, 3]] ...>]"
    end
  end
end
