defmodule TleTest do
  use ExUnit.Case

  test "parse valid TLE" do
    tleLine1 = "1 25544U 98067A   24346.98672894  .00019985  00000-0  35072-3 0  9994"
    tleLine2 = "2 25544  51.6393 154.4947 0007200 331.0970 170.8608 15.50504106486123"

    {:ok, tleEpoch, 0} = DateTime.from_iso8601("2024-12-11T23:40:53.380415Z")

    {:ok, tle} = SpaceDust.Utils.Tle.parseTLE(tleLine1, tleLine2)
    assert tle.catalogNumber == "25544"
    assert tle.classification == "U"
    assert tle.internationalDesignator == "98067A"
    assert tle.epoch == tleEpoch
    assert tle.meanMotionDot == 0.00019985
    assert tle.meanMotionDoubleDot == 0.0
    assert tle.bStar == 0.00035072
    assert tle.ephemerisType == 0
    assert tle.elementSetNumber == 999
    assert tle.inclinationDeg == 51.6393
    assert tle.raanDeg == 154.4947
    assert tle.eccentricity == 0.0007200
    assert tle.argPerigeeDeg == 331.0970
    assert tle.meanAnomalyDeg == 170.8608
    assert tle.meanMotion == 15.50504106
    assert tle.revNumber == 48612
  end
end
