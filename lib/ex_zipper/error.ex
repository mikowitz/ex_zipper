defmodule ExZipper.Error do
  @messages [
    down_from_leaf: "Cannot move down into a leaf",
    down_from_empty_branch: "Cannot move down onto an empty branch",
    up_from_root: "Cannot move up from the root",
    right_from_root: "Cannot move right from the root",
    right_from_rightmost: "Cannot move right from the rightmost member",
    left_from_root: "Cannot move left from the root",
    left_from_leftmost: "Cannot move left from the leftmost member",
    rightmost_from_root: "Cannot call rightmost from the root",
    leftmost_from_root: "Cannot call leftmost from the root",
    prev_of_end: "Cannot call previous from the end",
    lefts_of_root: "Cannot query lefts of the root",
    rights_of_root: "Cannot query rights of the root",
    children_of_leaf: "Cannot query children of a leaf",
    insert_left_of_root: "Cannot insert to the left of the root",
    insert_right_of_root: "Cannot insert to the right of the root",
    insert_child_of_leaf: "Cannot insert a child into a leaf",
    append_child_of_leaf: "Cannot append a child to a leaf",
    remove_root: "Cannot remove root",
    down_from_end: "Cannot move down from the end",
    up_from_end: "Cannot move up from the end",
    right_from_end: "Cannot move right from the end",
    left_from_end: "Cannot move left from the end",
    lefts_of_end: "Cannot query lefts of the end",
    rights_of_end: "Cannot query rights of the end",
    insert_left_of_end: "Cannot insert to the left of the end",
    insert_right_of_end: "Cannot insert to the right of the end",
    path_of_end: "Cannot query the path to the end",
    rightmost_from_end: "Cannot call rightmost from the end",
    leftmost_from_end: "Cannot call leftmost from the end",
    remove_end: "Cannot remove the end"
  ]

  @moduledoc """
  Raised when a zipper operation cannot be performed on the current focus,
  such as moving down from a leaf or inserting a sibling next to the root.

  Navigation and editing functions in `ExZipper.Zipper` either return a new
  zipper or raise this error, so a pipeline stops at the first step that
  fails:

      zipper
      |> Zipper.down()
      |> Zipper.left()   # raises if the first child has no left sibling
      |> Zipper.edit(&(&1 * 10))

  ## Fields

    * `:reason` - an atom saying which operation failed and why
    * `:focus` - the node the zipper was focused on when the operation failed

  ## Reasons

  #{Enum.map_join(Enum.sort(@messages), "\n", fn {reason, message} -> "  * `#{inspect(reason)}` - #{message}" end)}

  ## Handling errors

  To branch on a specific failure, rescue the error and match on `:reason`:

      try do
        Zipper.down(zipper)
      rescue
        e in ExZipper.Error ->
          case e.reason do
            :down_from_leaf -> ...
            :down_from_empty_branch -> ...
          end
      end
  """

  defexception [:reason, :focus]

  @type reason ::
          unquote(
            @messages
            |> Keyword.keys()
            |> Enum.reverse()
            |> Enum.reduce(fn reason, acc -> quote(do: unquote(reason) | unquote(acc)) end)
          )

  @type t :: %__MODULE__{reason: reason() | atom(), focus: any()}

  @impl true
  def message(error)

  for {reason, message} <- @messages do
    def message(%{reason: unquote(reason)}), do: unquote(message)
  end

  def message(%{reason: reason}), do: "ExZipper error: #{inspect(reason)}"
end
