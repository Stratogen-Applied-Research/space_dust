defmodule DataTest do
  use ExUnit.Case

  test "validate leap second" do
    leapSeconds = SpaceDust.Data.LeapSecond.julianDateToLeapSeconds(2_447_892.5)
    assert leapSeconds == 25
  end

  test "incorrect JD returns default leap second" do
    leapSeconds = SpaceDust.Data.LeapSecond.julianDateToLeapSeconds(2_031.5)
    assert leapSeconds == 37
  end
end
