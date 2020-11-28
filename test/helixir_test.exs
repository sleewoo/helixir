defmodule HelixirTest do
  use ExUnit.Case
  doctest Helixir

  test "greets the world" do
    assert Helixir.hello() == :world
  end
end
