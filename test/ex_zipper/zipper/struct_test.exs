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
    measure = %Measure{
      time_signature: "4/4",
      music: [
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
      ]
    }

    zipper =
      Z.zipper(
        fn map -> Map.has_key?(map, :music) end,
        fn %{music: music} -> music end,
        fn node, music ->
          case Map.has_key?(node, :music) do
            true -> %{node | music: music}
            false -> %Voice{name: "", music: music}
          end
        end,
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
      [_ | crumb_right] = context.measure.music

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
      zipper = context.zipper |> Z.down() |> Z.right() |> Z.right() |> Z.right() |> Z.right()
      assert Z.right(zipper) == {:error, :right_from_rightmost}
    end

    test "moves focus to the sibling to the right of the current focus", context do
      zipper = Z.down(context.zipper)
      zipper = Z.right(zipper)
      assert Z.node(zipper) == %Voice{name: "empty", music: []}
      [crumb_left, _ | crumb_right] = context.measure.music

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
      zipper = zipper |> Z.right()
      zipper = Z.left(zipper)
      [_ | new_right] = context.measure.music
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
      zipper = context.zipper |> Z.down() |> Z.right() |> Z.right() |> Z.right() |> Z.down()

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
      zipper = context.zipper |> Z.down() |> Z.rightmost()
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
      zipper = context.zipper |> Z.down()
      assert Z.leftmost(zipper) == zipper
    end
  end

  describe "root" do
    test "remains in place if called at the root", context do
      assert context.zipper == Z.root(context.zipper)
    end

    test "returns to the root from the current focus", context do
      zipper = context.zipper |> Z.down() |> Z.right() |> Z.right() |> Z.right() |> Z.down()

      assert Z.root(zipper) == context.zipper
    end
  end

  describe "lefts" do
    test "returns an error if called on the root", context do
      assert Z.lefts(context.zipper) == {:error, :lefts_of_root}
    end

    test "returns all siblings to the left of the current focus", context do
      zipper = Z.down(context.zipper)

      assert Z.lefts(zipper) == []

      zipper = zipper |> Z.right() |> Z.right()

      assert Z.lefts(zipper) == [%Note{note: "c4"}, %Voice{name: "empty", music: []}]
    end
  end

  describe "rights" do
    test "returns an error if called on the root", context do
      assert Z.rights(context.zipper) == {:error, :rights_of_root}
    end

    test "returns all siblings to the right of the current focus", context do
      zipper = Z.down(context.zipper)

      assert Z.rights(zipper) == [
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
             ]

      zipper = context.zipper |> Z.down() |> Z.right() |> Z.right()

      assert Z.rights(zipper) == [
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
             ]
    end
  end

  describe "path" do
    test "returns an empty list if called at the root", context do
      assert Z.path(context.zipper) == []
    end

    test "returns a path of nodes leading to the current focus from the root", context do
      zipper =
        context.zipper
        |> Z.down()
        |> Z.rightmost()
        |> Z.left()
        |> Z.down()
        |> Z.right()
        |> Z.right()
        |> Z.down()
        |> Z.right()

      assert Z.node(zipper) == %Note{note: "a4"}

      assert Z.path(zipper) == [
               context.measure,
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
               %Voice{
                 name: "soprano2",
                 music: [
                   %Note{note: "g4"},
                   %Note{note: "a4"}
                 ]
               }
             ]
    end
  end

  describe "branch?" do
    test "returns true if the current focus is a branch", context do
      assert Z.branch?(context.zipper)
    end

    test "returns false if the current focus is not a branch", context do
      zipper = Z.down(context.zipper)

      refute Z.branch?(zipper)
    end
  end

  describe "children" do
    test "returns the children of the current focus if it is a branch", context do
      assert Z.children(context.zipper) == context.measure.music
    end

    test "returns an error if called on a leaf", context do
      zipper = Z.down(context.zipper)

      assert Z.children(zipper) == {:error, :children_of_leaf}
    end
  end

  describe "make_node" do
    test "returns a new branch node, given an existing node and new children", context do
      new_node =
        Z.make_node(context.zipper, %Voice{name: "test voice", music: [%Note{note: "c4"}]}, [
          %Note{note: "d4"}
        ])

      assert new_node == %Voice{name: "test voice", music: [%Note{note: "d4"}]}

      node_from_leaf = Z.make_node(context.zipper, %Note{note: "e4"}, [%Note{note: "fs8"}])

      assert node_from_leaf == %Voice{name: "", music: [%Note{note: "fs8"}]}
    end
  end

  describe "replace" do
    test "replaces the current focus, persisting the change when moving back up the zipper",
         context do
      zipper = context.zipper |> Z.down() |> Z.right()
      zipper = Z.replace(zipper, %Note{note: "cs8"})
      zipper = Z.root(zipper)

      assert zipper.focus == %Measure{
               time_signature: "4/4",
               music: [
                 %Note{note: "c4"},
                 %Note{note: "cs8"},
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
               ]
             }
    end
  end

  describe "edit" do
    test "replaces the current focus by applying the given function, persisting the change when moving back up the zipper",
         context do
      zipper = context.zipper |> Z.down()
      zipper = Z.edit(zipper, fn note -> %{note | note: "c16"} end)
      zipper = Z.root(zipper)

      assert zipper.focus == %Measure{
               time_signature: "4/4",
               music: [
                 %Note{note: "c16"},
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
               ]
             }
    end
  end

  describe "insert_left" do
    test "returns an error if called on the root", context do
      assert Z.insert_left(context.zipper, %Note{note: "bf,16"}) == {:error, :insert_left_of_root}
    end

    test "inserts the provided node to the left of the current focus, without changing focus",
         context do
      zipper = Z.down(context.zipper)
      zipper = Z.insert_left(zipper, %Note{note: "bf,16"})
      zipper = Z.root(zipper)

      assert zipper.focus == %Measure{
               time_signature: "4/4",
               music: [
                 %Note{note: "bf,16"},
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
               ]
             }
    end
  end

  describe "insert_right" do
    test "returns an error if called on the root", context do
      assert Z.insert_right(context.zipper, %Note{note: "bf,16"}) ==
               {:error, :insert_right_of_root}
    end

    test "inserts the provided node to the right of the current focus, without changing focus",
         context do
      zipper = Z.down(context.zipper)
      zipper = Z.insert_right(zipper, %Note{note: "bf,16"})
      zipper = Z.root(zipper)

      assert zipper.focus == %Measure{
               time_signature: "4/4",
               music: [
                 %Note{note: "c4"},
                 %Note{note: "bf,16"},
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
               ]
             }
    end
  end

  describe "insert_child" do
    test "returns an error if called on a leaf", context do
      zipper = Z.down(context.zipper)

      assert Z.insert_child(zipper, %Note{note: "bf8"}) == {:error, :insert_child_of_leaf}
    end

    test "adds a node as the leftmost child of the current focus", context do
      zipper = context.zipper |> Z.down() |> Z.right() |> Z.right() |> Z.right()

      zipper = Z.insert_child(zipper, %Note{note: "bf,16"})
      zipper = Z.root(zipper)

      assert zipper.focus == %Measure{
               time_signature: "4/4",
               music: [
                 %Note{note: "c4"},
                 %Voice{name: "empty", music: []},
                 %Note{note: "d4"},
                 %Voice{
                   name: "soprano",
                   music: [
                     %Note{note: "bf,16"},
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
               ]
             }
    end
  end

  describe "append_child" do
    test "returns an error if called on a leaf", context do
      zipper = Z.down(context.zipper)

      assert Z.append_child(zipper, %Note{note: "bf8"}) == {:error, :append_child_of_leaf}
    end

    test "adds a node as the leftmost child of the current focus", context do
      zipper = context.zipper |> Z.down() |> Z.right() |> Z.right() |> Z.right()

      zipper = Z.append_child(zipper, %Note{note: "bf,16"})
      zipper = Z.root(zipper)

      assert zipper.focus == %Measure{
               time_signature: "4/4",
               music: [
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
                     },
                     %Note{note: "bf,16"}
                   ]
                 },
                 %Note{note: "c'4"}
               ]
             }
    end
  end

  describe "next" do
    test "navigates to the next node in a depth-first walk", context do
      zipper = Z.next(context.zipper)
      assert zipper.focus.note == "c4"
      zipper = Z.next(zipper)
      assert zipper.focus.name == "empty"
      zipper = Z.next(zipper)
      assert zipper.focus.note == "d4"
      zipper = Z.next(zipper)
      assert zipper.focus.name == "soprano"
      zipper = Z.next(zipper)
      assert zipper.focus.note == "e4"
      zipper = Z.next(zipper)
      assert zipper.focus.note == "f4"
      zipper = Z.next(zipper)
      assert zipper.focus.name == "soprano2"
      zipper = Z.next(zipper)
      assert zipper.focus.note == "g4"
      zipper = Z.next(zipper)
      assert zipper.focus.note == "a4"
      zipper = Z.next(zipper)
      assert zipper.focus.name == "alto"
      zipper = Z.next(zipper)
      assert zipper.focus.note == "b4"
      zipper = Z.next(zipper)
      assert zipper.focus.note == "c'4"
      zipper = Z.next(zipper)
      assert zipper.focus == context.measure
      assert Z.end?(zipper)
      zipper = Z.next(zipper)
      assert zipper.focus == context.measure
      assert Z.end?(zipper)
    end
  end

  describe "prev" do
    test "navigates to the previous node in a depth-first walk", context do
      zipper =
        context.zipper
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()

      assert zipper.focus.note == "c'4"
      refute Z.end?(zipper)
      zipper = Z.prev(zipper)
      assert zipper.focus.note == "b4"
      zipper = Z.prev(zipper)
      assert zipper.focus.name == "alto"
      zipper = Z.prev(zipper)
      assert zipper.focus.note == "a4"
      zipper = Z.prev(zipper)
      assert zipper.focus.note == "g4"
      zipper = Z.prev(zipper)
      assert zipper.focus.name == "soprano2"
      zipper = Z.prev(zipper)
      assert zipper.focus.note == "f4"
      zipper = Z.prev(zipper)
      assert zipper.focus.note == "e4"
      zipper = Z.prev(zipper)
      assert zipper.focus.name == "soprano"
      zipper = Z.prev(zipper)
      assert zipper.focus.note == "d4"
      zipper = Z.prev(zipper)
      assert zipper.focus.name == "empty"
      zipper = Z.prev(zipper)
      assert zipper.focus.note == "c4"
      zipper = Z.prev(zipper)
      assert zipper.focus == context.measure
    end

    test "can't navigate back from the end of the walk", context do
      zipper =
        context.zipper
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()
        |> Z.next()

      assert Z.end?(zipper)
      assert Z.prev(zipper) == {:error, :prev_of_end}
    end
  end

  describe "end?" do
    test "returns true if at the last node of a depth-first walk through the zipper", context do
      zipper = Z.down(context.zipper)

      refute zipper |> Z.end?()
      refute zipper |> Z.next() |> Z.next() |> Z.next() |> Z.next() |> Z.end?()
      refute zipper |> Z.next() |> Z.next() |> Z.next() |> Z.next() |> Z.end?()

      assert zipper
             |> Z.next()
             |> Z.next()
             |> Z.next()
             |> Z.next()
             |> Z.next()
             |> Z.next()
             |> Z.next()
             |> Z.next()
             |> Z.next()
             |> Z.next()
             |> Z.next()
             |> Z.next()
             |> Z.end?()
    end
  end

  describe "remove" do
    test "returns an error when called on the root", context do
      assert Z.remove(context.zipper) == {:error, :remove_root}
    end

    test "removes the current focus, and moves to the prev location in a depth-first walk",
         context do
      zipper = Z.down(context.zipper)
      zipper = Z.remove(zipper)

      assert zipper.focus == %Measure{
               time_signature: "4/4",
               music: [
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
               ]
             }

      zipper = Z.root(zipper)

      assert zipper.focus == %Measure{
               time_signature: "4/4",
               music: [
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
               ]
             }

      zipper =
        context.zipper |> Z.down() |> Z.right() |> Z.right() |> Z.right() |> Z.down() |> Z.right()

      zipper = Z.remove(zipper)
      assert zipper.focus == %Note{note: "e4"}

      zipper = Z.root(zipper)

      assert zipper.focus == %Measure{
               time_signature: "4/4",
               music: [
                 %Note{note: "c4"},
                 %Voice{name: "empty", music: []},
                 %Note{note: "d4"},
                 %Voice{
                   name: "soprano",
                   music: [
                     %Note{note: "e4"},
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
               ]
             }
    end
  end

  describe "to_list" do
    test "returns a depth-first list of all elements in the zipper", context do
      zipper_list = Z.to_list(context.zipper)
      assert length(zipper_list) == 13
      assert Enum.map(zipper_list, &(&1.__struct__)) == [
        Measure,
        Note,
        Voice,
        Note,
        Voice,
        Note,
        Note,
        Voice,
        Note,
        Note,
        Voice,
        Note,
        Note
      ]
    end
  end
end
