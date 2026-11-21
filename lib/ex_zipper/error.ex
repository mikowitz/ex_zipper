defmodule ExZipper.Error do
  defexception [:reason, :focus]

  def message(%__MODULE__{reason: reason}), do: to_string(reason)
end
