defmodule LoaderTest do
  use ExUnit.Case
  doctest Loader

  test "greets the world" do
    assert Loader.hello() == :world
  end
end
