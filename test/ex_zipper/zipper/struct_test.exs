defmodule ExZipper.Zipper.StructTest do
  use ExUnit.Case, async: true
  alias ExZipper.Zipper, as: Z

  defmodule Measure do
    defstruct [:time_signature, :music]
  end
  defmodule Voice do
    defstruct [:name, :music]
  end
  defmodule Note do
    defstruct [:note]
  end

  setup do
    measure = %Measure{time_signature: "4/4", music: [
      %Note{note: "c4"},
      %Voice{name: "empty", music: []},
      %Note{note: "d4"},
      %Voice{
        name: "soprano",
        music: [
          %Note{note: "e4"},
          %Note{note: "f4"},
          %Voice{
            name: "soprano2",
            music: [
              %Note{note: "g4"},
              %Note{note: "a4"}
            ]
          },
          %Voice{
            name: "alto",
            music: [
              %Note{note: "b4"}
            ]
          }
        ]
      },
      %Note{note: "c'4"}
    ]}
    zipper = Z.zipper(
      fn map -> Map.has_key?(map, :music) end,
      fn %{music: music} -> music end,
      fn node, music -> %{node | music: music} end,
      measure
    )
    {:ok, %{measure: measure, zipper: zipper}}
  end

  describe "node/1" do
    test "returns the current focus of the zipper", context do
      assert Z.node(context.zipper) == context.measure
    end
  end

  describe "down/1" do
    test "returns an error if called on a leaf", context do
      zipper = %{context.zipper | focus: %Note{note: "cs4"}}
      assert Z.down(zipper) == {:error, :down_from_leaf}
    end

    test "returns an error if called on an empty branch", context do
      zipper = %{context.zipper | focus: %Voice{name: "empty", music: []}}
      assert Z.down(zipper) == {:error, :down_from_empty_branch}
    end

    test "moves focus to the first child of the current focus", context do
      zipper = Z.down(context.zipper)
      assert Z.node(zipper) == %Note{note: "c4"}
      [_|crumb_right] = context.measure.music
      assert zipper.crumbs == %{
        left: [],
        right: crumb_right,
        pnodes: nil,
        ppath: [context.measure]
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
      assert Z.node(zipper) == %Voice{name: "empty", music: []}
      [crumb_left,_|crumb_right] = context.measure.music
      assert zipper.crumbs == %{
        left: [crumb_left],
        right: crumb_right,
        pnodes: nil,
        ppath: [context.measure]
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
      zipper = zipper |> Z.right
      zipper = Z.left(zipper)
      [_|new_right] = context.measure.music
      assert zipper.focus == %Note{note: "c4"}
      assert zipper.crumbs == %{
        left: [],
        right: new_right,
        pnodes: nil,
        ppath: [context.measure]
      }
    end
  end

  describe "up" do
    test "returns an error if called on root", context do
      assert Z.up(context.zipper) == {:error, :up_from_root}
    end

    test "moves focus to the current focus' parent", context do
      zipper = context.zipper |> Z.down |> Z.right |> Z.right |> Z.right |> Z.down

      zipper = Z.up(zipper)

      assert zipper.focus == %Voice{
        name: "soprano",
        music: [
          %Note{note: "e4"},
          %Note{note: "f4"},
          %Voice{
            name: "soprano2",
            music: [
              %Note{note: "g4"},
              %Note{note: "a4"}
            ]
          },
          %Voice{
            name: "alto",
            music: [
              %Note{note: "b4"}
            ]
          }
        ]
      }
      assert zipper.crumbs == %{
        left: [
          %Note{note: "d4"},
          %Voice{name: "empty", music: []},
          %Note{note: "c4"}
        ],
        right: [%Note{note: "c'4"}],
        pnodes: nil,
        ppath: [context.measure]
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

      assert zipper.focus == %Note{note: "c'4"}
      assert zipper.crumbs == %{
        left: [
          %Voice{
            name: "soprano",
            music: [
              %Note{note: "e4"},
              %Note{note: "f4"},
              %Voice{
                name: "soprano2",
                music: [
                  %Note{note: "g4"},
                  %Note{note: "a4"}
                ]
              },
              %Voice{
                name: "alto",
                music: [
                  %Note{note: "b4"}
                ]
              }
            ]
          },
          %Note{note: "d4"},
          %Voice{name: "empty", music: []},
          %Note{note: "c4"}
        ],
        right: [],
        pnodes: nil,
        ppath: [context.measure]
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
      zipper = Z.down(context.zipper)
      zipper = Z.leftmost(zipper)

      assert zipper.focus == %Note{note: "c4"}
      assert zipper.crumbs == %{
        left: [],
        right: [
          %Voice{name: "empty", music: []},
          %Note{note: "d4"},
          %Voice{
            name: "soprano",
            music: [
              %Note{note: "e4"},
              %Note{note: "f4"},
              %Voice{
                name: "soprano2",
                music: [
                  %Note{note: "g4"},
                  %Note{note: "a4"}
                ]
              },
              %Voice{
                name: "alto",
                music: [
                  %Note{note: "b4"}
                ]
              }
            ]
          },
          %Note{note: "c'4"}
        ],
        pnodes: nil,
        ppath: [context.measure]
      }
    end

    test "remains in place if called on the leftmost sibling", context do
      zipper = context.zipper |> Z.down
      assert Z.leftmost(zipper) == zipper
    end
  end
end
