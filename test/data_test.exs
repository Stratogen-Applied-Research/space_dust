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
  test "parse EOP line" do
    eopLine =
      "1984   1   1  12  45700.50   -0.134064    0.093057   0.3968898    0.005644   -0.002799    0.034912   -0.041530   0.0014139    0.001250    0.000992   0.0002417    0.000876    0.000351    0.001226    0.000991   0.0000730"

    eop = SpaceDust.Data.EOP.parseEopLine(eopLine)
    IO.inspect(eop)
    assert eop.modifiedJulianDate == 45700.50
    assert eop.polarMotionX == -0.134064
    assert eop.polarMotionY == 0.093057
    assert eop.ut1UTC == 0.3968898
    assert eop.dPsi == 0.005644
    assert eop.dEps == -0.002799
    assert eop.lod == 0.0014139
  end

  test "pull and save EOP data" do
    {:ok, eopData} = SpaceDust.Data.EOP.pullEOPData()
    assert eopData != nil
    {:ok, filename} = SpaceDust.Data.EOP.saveEopData(eopData)
    assert filename != nil
  end

  test "read saved EOP data" do
    {:ok, rawEopData} = SpaceDust.Data.EOP.readSavedEopData()
    # parse the first line
    {:ok, eopData} = SpaceDust.Data.EOP.parseEopLine(Enum.at(rawEopData, 0))
    IO.inspect(%{parsed_eop_line: eopData})
    assert eopData != nil
  end
end
