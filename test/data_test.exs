defmodule DataTest do
  use ExUnit.Case

  # leap second tests
  test "validate leap second" do
    leapSeconds = SpaceDust.Data.LeapSecond.julianDateToLeapSeconds(2_447_892.5)
    assert leapSeconds == 25
  end

  test "incorrect JD returns default leap second" do
    leapSeconds = SpaceDust.Data.LeapSecond.julianDateToLeapSeconds(2_031.5)
    assert leapSeconds == 37
  end

  # EOP data tests
  test "pull EOP data" do
    {:ok, eopData} = SpaceDust.Data.EOP.pullEOPData()
    assert eopData != nil
  end
end
