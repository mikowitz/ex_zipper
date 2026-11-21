defmodule ExZipper do
  @moduledoc false

  def raise_error(reason, %ExZipper.Zipper{focus: focus}) do
    raise ExZipper.Error, reason: reason, focus: focus
  end
end
