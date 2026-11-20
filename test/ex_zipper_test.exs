defmodule ExZipperTest do
  use ExUnit.Case

  alias ExZipper.Zipper

  doctest ExZipper.Zipper
  doctest ExZipper.Zipper.Navigation
  doctest ExZipper.Zipper.Editing
  doctest ExZipper.Zipper.Traversal
end
