defmodule SpaceDustTest do
  use ExUnit.Case
  doctest SpaceDust

  test "returns version" do
    assert SpaceDust.version() == "0.2.0"
  end
end
