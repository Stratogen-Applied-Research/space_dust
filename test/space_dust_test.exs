defmodule SpaceDustTest do
  use ExUnit.Case
  doctest SpaceDust

  test "returns version" do
    assert SpaceDust.version() == to_string(Application.spec(:space_dust, :vsn))
  end
end
