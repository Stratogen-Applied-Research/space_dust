defmodule DataTest do
  use ExUnit.Case

  # leap second tests
  test "validate leap second" do
    leapSeconds = SpaceDust.Data.LeapSecond.julianDateToLeapSeconds(2_447_892.5)
    assert leapSeconds == 25
  end

  test "incorrect JD returns default leap second" do
    # JD before first leap second entry returns 10 (earliest value)
    leapSeconds = SpaceDust.Data.LeapSecond.julianDateToLeapSeconds(2_031.5)
    assert leapSeconds == 10
  end

  test "JD after table returns latest leap second" do
    # JD after all entries returns 37 (latest known value)
    leapSeconds = SpaceDust.Data.LeapSecond.julianDateToLeapSeconds(2_500_000.0)
    assert leapSeconds == 37
  end

  # EOP data tests
  test "parse EOP line" do
    # Sample line from finals.all.iau2000.txt format
    eopLine =
      "73 1 2 41684.00 I  0.120733 0.009786  0.136966 0.015902  I 0.8084178 0.0002710  0.0000 0.1916  P    -0.766    0.199    -0.720    0.300"

    {:ok, eop} = SpaceDust.Data.EOP.parseEopLine(eopLine)
    IO.inspect(eop)
    assert eop.modifiedJulianDate == 41684.0
    assert eop.polarMotionX == 0.120733
    assert eop.polarMotionY == 0.136966
    assert eop.ut1UTC == 0.8084178
    # dPsi and dEps are in milliarcsec, converted to arcsec (divide by 1000)
    assert_in_delta eop.dPsi, -0.000766, 0.000001
    assert_in_delta eop.dEps, -0.000720, 0.000001
    # LOD is 0.0000 in this line (converted from ms to s)
    assert eop.lod == 0.0
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

  test "parse entire EOP data file" do
    {:ok, rawEopData} = SpaceDust.Data.EOP.readSavedEopData()
    {:ok, eopData} = SpaceDust.Data.EOP.parseEopData(rawEopData)
    IO.inspect(%{parsed_eop_data: eopData})
    assert eopData != nil
  end

  test "get EOP data at epoch" do
    epoch = 60451.50
    {:ok, eopData} = SpaceDust.Data.EOP.getEopData(epoch)
    IO.inspect(%{eop_data_at_epoch: eopData})
    assert eopData != nil
  end
end
