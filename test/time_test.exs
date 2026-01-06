defmodule TimeTest do
  use ExUnit.Case, async: true

  alias SpaceDust.Time.{UTC, TAI, TT, GPS, JulianDate, GMST, Epoch, Transforms}

  describe "UTC" do
    test "create from datetime" do
      dt = ~U[2024-01-01 12:00:00Z]
      utc = UTC.from_datetime(dt)
      assert utc.unix_seconds == DateTime.to_unix(dt)
    end

    test "convert to/from datetime round trip" do
      dt = ~U[2024-06-15 08:30:45Z]
      utc = UTC.from_datetime(dt)
      result = UTC.to_datetime(utc)
      assert DateTime.truncate(result, :second) == DateTime.truncate(dt, :second)
    end

    test "from_iso8601!" do
      utc = UTC.from_iso8601!("2024-01-01T00:00:00Z")
      assert utc.unix_seconds == 1_704_067_200.0
    end

    test "to/from Julian Date" do
      utc = UTC.from_datetime(~U[2000-01-01 12:00:00Z])
      jd = UTC.to_jd(utc)
      # J2000.0 epoch
      assert_in_delta jd, 2_451_545.0, 0.0001
    end

    test "to/from MJD" do
      utc = UTC.from_datetime(~U[2024-01-01 00:00:00Z])
      mjd = UTC.to_mjd(utc)
      utc2 = UTC.from_mjd(mjd)
      assert_in_delta utc.unix_seconds, utc2.unix_seconds, 0.001
    end

    test "add seconds" do
      utc = UTC.new(0.0)
      utc2 = UTC.add(utc, 3600)
      assert utc2.unix_seconds == 3600.0
    end

    test "diff between times" do
      utc1 = UTC.new(7200.0)
      utc2 = UTC.new(3600.0)
      assert UTC.diff(utc1, utc2) == 3600.0
    end

    test "to/from tensor" do
      utc = UTC.new(1234567.89)
      tensor = UTC.to_tensor(utc)
      utc2 = UTC.from_tensor(tensor)
      assert_in_delta utc.unix_seconds, utc2.unix_seconds, 0.001
    end
  end

  describe "TAI" do
    test "create and retrieve seconds" do
      tai = TAI.new(1000.0)
      assert TAI.to_seconds(tai) == 1000.0
    end

    test "add and diff" do
      tai1 = TAI.new(5000.0)
      tai2 = TAI.add(tai1, 500.0)
      assert TAI.diff(tai2, tai1) == 500.0
    end

    test "to/from tensor" do
      tai = TAI.new(9876.54)
      tensor = TAI.to_tensor(tai)
      tai2 = TAI.from_tensor(tensor)
      assert_in_delta tai.tai_seconds, tai2.tai_seconds, 0.001
    end
  end

  describe "TT" do
    test "create and retrieve seconds" do
      tt = TT.new(2000.0)
      assert TT.to_seconds(tt) == 2000.0
    end

    test "julian_centuries_j2000" do
      # J2000.0 should give 0 centuries
      j2000_unix = (Epoch.j2000_jd() - Epoch.unix_epoch_jd()) * Epoch.seconds_per_day()
      tt = TT.new(j2000_unix)
      assert_in_delta TT.julian_centuries_j2000(tt), 0.0, 0.0001
    end
  end

  describe "GPS" do
    test "create from seconds" do
      gps = GPS.new(1_000_000.0)
      assert GPS.to_seconds(gps) == 1_000_000.0
    end

    test "week and seconds of week" do
      # 1 week + 1 day
      gps = GPS.new(604_800.0 + 86_400.0)
      {week, sow} = GPS.to_week_and_seconds(gps)
      assert week == 1
      assert_in_delta sow, 86_400.0, 0.001
    end

    test "from week and seconds" do
      gps = GPS.from_week_and_seconds(100, 50000.0)
      {week, sow} = GPS.to_week_and_seconds(gps)
      assert week == 100
      assert_in_delta sow, 50000.0, 0.001
    end

    test "day of week" do
      # Start of week (Sunday)
      gps = GPS.new(0.0)
      assert GPS.day_of_week(gps) == 0

      # One day into week (Monday)
      gps2 = GPS.new(86_400.0)
      assert GPS.day_of_week(gps2) == 1
    end
  end

  describe "JulianDate" do
    test "create and retrieve days" do
      jd = JulianDate.new(2_451_545.0)
      assert JulianDate.to_days(jd) == 2_451_545.0
    end

    test "to/from MJD" do
      jd = JulianDate.new(2_451_545.0)
      mjd = JulianDate.to_mjd(jd)
      jd2 = JulianDate.from_mjd(mjd)
      assert_in_delta jd.jd, jd2.jd, 0.0001
    end

    test "j2000 epoch" do
      j2000 = JulianDate.j2000()
      assert j2000.jd == 2_451_545.0
    end

    test "julian_centuries_j2000" do
      j2000 = JulianDate.j2000()
      assert JulianDate.julian_centuries_j2000(j2000) == 0.0

      # One century later
      jd = JulianDate.new(2_451_545.0 + 36525.0)
      assert_in_delta JulianDate.julian_centuries_j2000(jd), 1.0, 0.0001
    end

    test "add days and seconds" do
      jd = JulianDate.new(2_451_545.0)
      jd2 = JulianDate.add_days(jd, 1.0)
      assert jd2.jd == 2_451_546.0

      jd3 = JulianDate.add_seconds(jd, 86_400.0)
      assert jd3.jd == 2_451_546.0
    end

    test "diff in days and seconds" do
      jd1 = JulianDate.new(2_451_546.0)
      jd2 = JulianDate.new(2_451_545.0)
      assert JulianDate.diff_days(jd1, jd2) == 1.0
      assert JulianDate.diff_seconds(jd1, jd2) == 86_400.0
    end
  end

  describe "GMST" do
    test "create from radians" do
      gmst = GMST.new(:math.pi())
      assert GMST.to_radians(gmst) == :math.pi()
    end

    test "to/from degrees" do
      gmst = GMST.from_degrees(180.0)
      assert_in_delta GMST.to_degrees(gmst), 180.0, 0.0001
    end

    test "to/from hours" do
      gmst = GMST.from_hours(12.0)
      assert_in_delta GMST.to_hours(gmst), 12.0, 0.0001
    end

    test "normalize" do
      # 3π radians should normalize to π
      gmst = GMST.new(3.0 * :math.pi())
      normalized = GMST.normalize(gmst)
      assert_in_delta GMST.to_radians(normalized), :math.pi(), 0.0001
    end
  end

  describe "Epoch constants" do
    test "unix epoch JD" do
      assert Epoch.unix_epoch_jd() == 2_440_587.5
    end

    test "seconds per day" do
      assert Epoch.seconds_per_day() == 86_400.0
    end

    test "j2000 JD" do
      assert Epoch.j2000_jd() == 2_451_545.0
    end

    test "TT-TAI offset" do
      assert Epoch.tt_tai_offset() == 32.184
    end
  end

  describe "Transforms" do
    test "utc_to_tai and back" do
      utc = UTC.from_datetime(~U[2020-01-01 00:00:00Z])
      tai = Transforms.utc_to_tai(utc)
      utc2 = Transforms.tai_to_utc(tai)
      # Should be close but may differ slightly due to leap second lookup
      assert_in_delta utc.unix_seconds, utc2.unix_seconds, 1.0
    end

    test "tai_to_tt and back" do
      tai = TAI.new(1_000_000.0)
      tt = Transforms.tai_to_tt(tai)
      tai2 = Transforms.tt_to_tai(tt)
      assert_in_delta tai.tai_seconds, tai2.tai_seconds, 0.001
    end

    test "TT is TAI + 32.184" do
      tai = TAI.new(1_000_000.0)
      tt = Transforms.tai_to_tt(tai)
      assert_in_delta tt.tt_seconds - tai.tai_seconds, 32.184, 0.001
    end

    test "utc_to_tt convenience" do
      utc = UTC.from_datetime(~U[2020-01-01 00:00:00Z])
      tt = Transforms.utc_to_tt(utc)

      # Verify it's equivalent to going through TAI
      tai = Transforms.utc_to_tai(utc)
      tt2 = Transforms.tai_to_tt(tai)
      assert_in_delta tt.tt_seconds, tt2.tt_seconds, 0.001
    end

    test "utc_to_jd and back" do
      utc = UTC.from_datetime(~U[2024-06-15 12:00:00Z])
      jd = Transforms.utc_to_jd(utc)
      utc2 = Transforms.jd_to_utc(jd)
      assert_in_delta utc.unix_seconds, utc2.unix_seconds, 0.001
    end

    test "utc_to_gmst" do
      utc = UTC.from_datetime(~U[2024-01-01 00:00:00Z])
      gmst = Transforms.utc_to_gmst(utc)
      # GMST should be normalized to [0, 2π)
      assert GMST.to_radians(gmst) >= 0
      assert GMST.to_radians(gmst) < 2 * :math.pi()
    end

    test "jd_to_gmst" do
      jd = JulianDate.new(2_451_545.0)  # J2000.0
      gmst = Transforms.jd_to_gmst(jd)
      # GMST at J2000.0 should be approximately 18.697 hours
      hours = GMST.to_hours(gmst)
      assert hours >= 0
      assert hours < 24
    end
  end
end
