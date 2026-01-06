defmodule ObservationsTest do
  use ExUnit.Case

  alias SpaceDust.State.{ECIState, GeodeticState}
  alias SpaceDust.Observations
  alias SpaceDust.Observations.{RaDec, AzEl}

  # Test epoch
  @epoch ~U[2024-01-01 12:00:00Z]

  # Observer at Boulder, Colorado (approximately)
  @boulder GeodeticState.new(40.0150, -105.2705, 1.655)

  # Observer at equator on prime meridian
  @equator_observer GeodeticState.new(0.0, 0.0, 0.0)

  # ISS-like orbit: ~420 km altitude, ~51.6 deg inclination
  @iss_position {-4400.0, 1700.0, 4700.0}
  @iss_velocity {-3.5, -6.2, 2.8}

  describe "GeodeticState" do
    test "new creates valid struct" do
      state = GeodeticState.new(40.0, -105.0, 1.6)
      assert state.latitude == 40.0
      assert state.longitude == -105.0
      assert state.altitude == 1.6
    end

    test "to_ecef produces reasonable position" do
      ecef = GeodeticState.to_ecef(@boulder, @epoch)
      {x, y, z} = ecef.position

      # Boulder should be in the Western hemisphere (negative x and y in ECEF at local midnight)
      # At ~40N latitude, z should be positive and significant
      assert z > 0

      # Position magnitude should be close to Earth radius + altitude
      r = :math.sqrt(x * x + y * y + z * z)
      assert_in_delta(r, 6378.0 + 1.655, 50.0)
    end

    test "to_eci and back via from_ecef preserves position" do
      # Convert geodetic -> ECEF
      ecef1 = GeodeticState.to_ecef(@boulder, @epoch)

      # Convert back to geodetic
      recovered = GeodeticState.from_ecef(ecef1)

      assert_in_delta(recovered.latitude, @boulder.latitude, 1.0e-6)
      assert_in_delta(recovered.longitude, @boulder.longitude, 1.0e-6)
      assert_in_delta(recovered.altitude, @boulder.altitude, 1.0e-6)
    end

    test "equator observer has correct z-coordinate" do
      ecef = GeodeticState.to_ecef(@equator_observer, @epoch)
      {_x, _y, z} = ecef.position

      # At equator, z should be essentially zero
      assert_in_delta(z, 0.0, 1.0e-6)
    end

    test "local_sidereal_time varies with longitude" do
      lst1 = GeodeticState.local_sidereal_time(@equator_observer, @epoch)

      # Observer 90 degrees east
      east_observer = GeodeticState.new(0.0, 90.0, 0.0)
      lst2 = GeodeticState.local_sidereal_time(east_observer, @epoch)

      # LST should differ by ~π/2 radians (90 degrees = 6 hours)
      diff = :math.fmod(lst2 - lst1 + 4 * :math.pi(), 2 * :math.pi())
      assert_in_delta(diff, :math.pi() / 2, 0.01)
    end
  end

  describe "RaDec" do
    test "new creates valid struct" do
      obs = RaDec.new(@epoch, 1.5, 0.3)
      assert obs.epoch == @epoch
      assert obs.right_ascension == 1.5
      assert obs.declination == 0.3
    end

    test "from_degrees converts correctly" do
      obs = RaDec.from_degrees(@epoch, 90.0, 45.0)
      assert_in_delta(obs.right_ascension, :math.pi() / 2, 1.0e-10)
      assert_in_delta(obs.declination, :math.pi() / 4, 1.0e-10)
    end

    test "to_degrees is inverse of from_degrees" do
      obs = RaDec.from_degrees(@epoch, 123.456, -23.456)
      {ra_deg, dec_deg} = RaDec.to_degrees(obs)
      assert_in_delta(ra_deg, 123.456, 1.0e-10)
      assert_in_delta(dec_deg, -23.456, 1.0e-10)
    end

    test "from_hms_dms converts correctly" do
      # 6h 0m 0s = 90 degrees
      # +45° 0' 0" = 45 degrees
      obs = RaDec.from_hms_dms(@epoch, {6, 0, 0.0}, {45, 0, 0.0})
      {ra_deg, dec_deg} = RaDec.to_degrees(obs)
      assert_in_delta(ra_deg, 90.0, 1.0e-6)
      assert_in_delta(dec_deg, 45.0, 1.0e-6)
    end

    test "normalizes RA to [0, 2π)" do
      obs = RaDec.new(@epoch, -:math.pi() / 2, 0.0)
      assert obs.right_ascension > 0
      assert obs.right_ascension < 2 * :math.pi()
    end

    test "ra_to_hms format" do
      obs = RaDec.from_degrees(@epoch, 90.0, 0.0)
      hms = RaDec.ra_to_hms(obs)
      assert String.contains?(hms, "6h")
    end

    test "dec_to_dms format" do
      obs = RaDec.from_degrees(@epoch, 0.0, 45.0)
      dms = RaDec.dec_to_dms(obs)
      assert String.contains?(dms, "45°")
      assert String.starts_with?(dms, "+")
    end
  end

  describe "AzEl" do
    test "new creates valid struct" do
      obs = AzEl.new(@epoch, 1.5, 0.3)
      assert obs.epoch == @epoch
      assert obs.azimuth == 1.5
      assert obs.elevation == 0.3
    end

    test "from_degrees converts correctly" do
      obs = AzEl.from_degrees(@epoch, 180.0, 45.0)
      assert_in_delta(obs.azimuth, :math.pi(), 1.0e-10)
      assert_in_delta(obs.elevation, :math.pi() / 4, 1.0e-10)
    end

    test "to_degrees is inverse of from_degrees" do
      obs = AzEl.from_degrees(@epoch, 123.456, 23.456)
      {az_deg, el_deg} = AzEl.to_degrees(obs)
      assert_in_delta(az_deg, 123.456, 1.0e-10)
      assert_in_delta(el_deg, 23.456, 1.0e-10)
    end

    test "above_horizon? works correctly" do
      above = AzEl.from_degrees(@epoch, 0.0, 10.0)
      below = AzEl.from_degrees(@epoch, 0.0, -10.0)

      assert AzEl.above_horizon?(above)
      refute AzEl.above_horizon?(below)
    end

    test "above_elevation? works correctly" do
      obs = AzEl.from_degrees(@epoch, 0.0, 15.0)

      assert AzEl.above_elevation?(obs, 10.0 * :math.pi() / 180)
      refute AzEl.above_elevation?(obs, 20.0 * :math.pi() / 180)
    end

    test "compass_direction returns correct direction" do
      north = AzEl.from_degrees(@epoch, 0.0, 45.0)
      east = AzEl.from_degrees(@epoch, 90.0, 45.0)
      south = AzEl.from_degrees(@epoch, 180.0, 45.0)
      west = AzEl.from_degrees(@epoch, 270.0, 45.0)

      assert AzEl.compass_direction(north) == "N"
      assert AzEl.compass_direction(east) == "E"
      assert AzEl.compass_direction(south) == "S"
      assert AzEl.compass_direction(west) == "W"
    end

    test "normalizes azimuth to [0, 2π)" do
      obs = AzEl.new(@epoch, -:math.pi() / 2, 0.0)
      assert obs.azimuth > 0
      assert obs.azimuth < 2 * :math.pi()
    end
  end

  describe "Observations.compute_ra_dec" do
    test "computes valid RA/Dec for target" do
      target = ECIState.new(@epoch, @iss_position, @iss_velocity)
      ra_dec = Observations.compute_ra_dec(@boulder, target)

      # RA should be in [0, 2π)
      assert ra_dec.right_ascension >= 0
      assert ra_dec.right_ascension < 2 * :math.pi()

      # Dec should be in [-π/2, π/2]
      assert ra_dec.declination >= -:math.pi() / 2
      assert ra_dec.declination <= :math.pi() / 2

      # Range should be reasonable (few hundred to few thousand km for LEO)
      assert ra_dec.range > 100
      assert ra_dec.range < 10000
    end

    test "computes rates when requested" do
      target = ECIState.new(@epoch, @iss_position, @iss_velocity)
      ra_dec = Observations.compute_ra_dec(@boulder, target, include_rates: true)

      assert ra_dec.range_rate != nil
      assert ra_dec.right_ascension_rate != nil
      assert ra_dec.declination_rate != nil
    end

    test "geocentric_ra_dec works" do
      target = ECIState.new(@epoch, {7000.0, 0.0, 0.0}, {0.0, 7.5, 0.0})
      ra_dec = Observations.geocentric_ra_dec(target)

      # Target along +X axis should have RA = 0
      assert_in_delta(ra_dec.right_ascension, 0.0, 0.01)
      # Target in equatorial plane should have Dec = 0
      assert_in_delta(ra_dec.declination, 0.0, 0.01)
    end
  end

  describe "Observations.compute_az_el" do
    test "computes valid Az/El for target" do
      target = ECIState.new(@epoch, @iss_position, @iss_velocity)
      az_el = Observations.compute_az_el(@boulder, target)

      # Az should be in [0, 2π)
      assert az_el.azimuth >= 0
      assert az_el.azimuth < 2 * :math.pi()

      # El should be in [-π/2, π/2]
      assert az_el.elevation >= -:math.pi() / 2
      assert az_el.elevation <= :math.pi() / 2

      # Range should match
      assert az_el.range > 100
      assert az_el.range < 10000
    end

    test "computes rates when requested" do
      target = ECIState.new(@epoch, @iss_position, @iss_velocity)
      az_el = Observations.compute_az_el(@boulder, target, include_rates: true)

      assert az_el.range_rate != nil
      assert az_el.azimuth_rate != nil
      assert az_el.elevation_rate != nil
    end

    test "zenith target has elevation of 90 degrees" do
      # Create a target directly above the equator observer
      ecef_pos = GeodeticState.to_ecef(@equator_observer, @epoch)
      {ox, oy, oz} = ecef_pos.position

      # Target 1000 km directly above (along the radial direction)
      r = :math.sqrt(ox * ox + oy * oy + oz * oz)
      scale = (r + 1000) / r
      target_pos = {ox * scale, oy * scale, oz * scale}

      # Convert to ECI - need to rotate by GAST
      nutation = SpaceDust.Bodies.Earth.nutationAngles(@epoch)
      gast = nutation.gast
      {tx, ty, tz} = target_pos
      eci_x = tx * :math.cos(gast) - ty * :math.sin(gast)
      eci_y = tx * :math.sin(gast) + ty * :math.cos(gast)
      eci_z = tz

      target = ECIState.new(@epoch, {eci_x, eci_y, eci_z}, {0.0, 0.0, 0.0})
      az_el = Observations.compute_az_el(@equator_observer, target)

      # Elevation should be close to 90 degrees
      el_deg = az_el.elevation * 180.0 / :math.pi()
      assert_in_delta(el_deg, 90.0, 1.0)
    end
  end

  describe "Observations coordinate conversions" do
    test "ra_dec_to_az_el and az_el_to_ra_dec are inverses" do
      # Create a RA/Dec observation
      original_ra_dec = RaDec.new(@epoch, 1.0, 0.5, range: 1000.0)

      # Convert to Az/El
      az_el = Observations.ra_dec_to_az_el(original_ra_dec, @boulder)

      # Convert back to RA/Dec
      recovered_ra_dec = Observations.az_el_to_ra_dec(az_el, @boulder)

      # Should match original
      assert_in_delta(recovered_ra_dec.right_ascension, original_ra_dec.right_ascension, 1.0e-6)
      assert_in_delta(recovered_ra_dec.declination, original_ra_dec.declination, 1.0e-6)
    end

    test "ra_dec_to_eci_direction produces unit vector" do
      ra_dec = RaDec.new(@epoch, 1.0, 0.5)
      dir = Observations.ra_dec_to_eci_direction(ra_dec)

      mag = :math.sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
      assert_in_delta(mag, 1.0, 1.0e-10)
    end

    test "az_el_to_sez_direction produces unit vector" do
      az_el = AzEl.new(@epoch, 1.0, 0.5)
      dir = Observations.az_el_to_sez_direction(az_el)

      mag = :math.sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
      assert_in_delta(mag, 1.0, 1.0e-10)
    end

    test "az_el_to_eci_direction produces unit vector" do
      az_el = AzEl.new(@epoch, 1.0, 0.5)
      dir = Observations.az_el_to_eci_direction(az_el, @boulder)

      mag = :math.sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
      assert_in_delta(mag, 1.0, 1.0e-10)
    end
  end

  describe "Observations.is_visible?" do
    test "is_visible? agrees with computed elevation" do
      # Use ISS position which gives a concrete Az/El
      target = ECIState.new(@epoch, @iss_position, @iss_velocity)
      az_el = Observations.compute_az_el(@boulder, target)
      
      # is_visible? should agree with whether elevation > 0
      if AzEl.above_horizon?(az_el) do
        assert Observations.is_visible?(@boulder, target)
      else
        refute Observations.is_visible?(@boulder, target)
      end
    end

    test "is_visible? with minimum elevation agrees with above_elevation?" do
      target = ECIState.new(@epoch, @iss_position, @iss_velocity)
      az_el = Observations.compute_az_el(@boulder, target)
      min_el = 10.0
      
      if AzEl.above_elevation?(az_el, min_el) do
        assert Observations.is_visible?(@boulder, target, min_elevation: min_el)
      else
        refute Observations.is_visible?(@boulder, target, min_elevation: min_el)
      end
    end
  end

  describe "Observations.look_angles" do
    test "returns az, el in degrees and range" do
      target = ECIState.new(@epoch, @iss_position, @iss_velocity)
      {az_deg, el_deg, range_km} = Observations.look_angles(@boulder, target)

      # Verify it's in degrees
      assert az_deg >= 0 and az_deg < 360
      assert el_deg >= -90 and el_deg <= 90
      assert range_km > 0
    end
  end
end
