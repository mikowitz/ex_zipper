defmodule ExZipper.TestHelpers do
  @moduledoc false
  import ExUnit.Assertions

  @doc """
  Asserts that calling `fun` raises an `ExZipper.Error` with the given
  `reason`, and that the error has a readable message. Returns the error.
  """
  def assert_zipper_error(reason, fun) do
    error = assert_raise ExZipper.Error, fun
    assert error.reason == reason
    assert is_binary(Exception.message(error))
    error
  end
end

ExUnit.start()
