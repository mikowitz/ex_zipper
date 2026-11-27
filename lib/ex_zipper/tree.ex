defmodule ExZipper.Tree do
  @callback branch?(arg :: any()) :: boolean()
  @callback children(arg :: any()) :: list(any())
  @callback make_node(arg :: any(), children :: list(any())) :: any()
end
