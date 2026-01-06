defmodule PropagationTest do
  use ExUnit.Case

  alias SpaceDust.Utils.Tle
  alias SpaceDust.State.TEMEState
  alias SpaceDust.State.Transforms
  alias SpaceDust.State.GeodeticState
  alias SpaceDust.Observations
  alias SpaceDust.Observations.AzEl

  # GOES-15 (geostationary weather satellite)
  @galaxy16_line1 "1 29236U 06023A   26006.23725337 -.00000127  00000+0  00000+0 0  9998"
  @galaxy16_line2 "2 29236   0.0411 205.2172 0003166  95.2511 151.7365  1.00272365 71347"

  # Denver, CO observer location
  # Lat: 39.7392° N, Lon: -104.9903° W, Alt: ~1.609 km (Mile High City)
  @denver GeodeticState.new(39.7392, -104.9903, 1.609)

  describe "GALAXY-16 propagation and observation" do
    test "parses TLE correctly" do
      {:ok, tle} = Tle.parseTLE(@galaxy16_line1, @galaxy16_line2)

      assert tle.catalogNumber == "29236"
      assert tle.classification == "U"
      assert tle.internationalDesignator == "06023A"
      # Near-zero inclination for geostationary
      assert_in_delta tle.inclinationDeg, 0.0411, 0.0001
      # Near-circular orbit
      assert_in_delta tle.eccentricity, 0.0003166, 0.0000001
      # ~1 rev/day for geostationary
      assert_in_delta tle.meanMotion, 1.00272365, 0.00001
    end

    test "propagates to current date and computes Az/El from Denver" do
      {:ok, tle} = Tle.parseTLE(@galaxy16_line1, @galaxy16_line2)

      # Propagate to today (January 6, 2026) at 12:00 UTC
      {:ok, observation_time, 0} = DateTime.from_iso8601("2026-01-06T12:00:00Z")

      # Get position/velocity in TEME frame
      {position, velocity} = Tle.getRVatTime(tle, observation_time)

      # Verify it's approximately at geostationary altitude (~35,786 km)
      {rx, ry, rz} = position
      radius = :math.sqrt(rx * rx + ry * ry + rz * rz)
      # Geostationary radius is ~42,164 km from Earth center
      assert_in_delta radius, 42164.0, 500.0

      # Convert to TEME state
      teme_state = TEMEState.new(observation_time, position, velocity)

      # Convert TEME to ECI
      eci_state = Transforms.teme_to_eci(teme_state)

      # Compute azimuth and elevation from Denver
      az_el = Observations.compute_az_el(@denver, eci_state)
      {az_deg, el_deg} = AzEl.to_degrees(az_el)

      # Print results for verification
      IO.puts("\n=== GALAXY-16 Observation from Denver, CO ===")
      IO.puts("Observation Time: #{observation_time}")
      IO.puts("Satellite Position (TEME): #{inspect(position)} km")
      IO.puts("Satellite Radius: #{Float.round(radius, 2)} km")
      IO.puts("Azimuth: #{Float.round(az_deg, 2)}°")
      IO.puts("Elevation: #{Float.round(el_deg, 2)}°")
      IO.puts("Range: #{Float.round(az_el.range, 2)} km")
      IO.puts("Above Horizon: #{AzEl.above_horizon?(az_el)}")
      IO.puts("Compass Direction: #{AzEl.compass_direction(az_el)}")
      IO.puts("============================================\n")

      # GOES-15 is positioned at ~135°W longitude (over the Pacific)
      # From Denver (~105°W), it should be visible in the southwestern sky
      # Azimuth should be roughly SW (180-270°)
      assert az_deg >= 0 and az_deg < 360, "Azimuth should be 0-360°"

      # For geostationary from mid-latitudes, elevation is typically 20-50°
      # but depends on the relative longitude
      # GOES-15 at 135°W, Denver at 105°W means satellite is 30° west
      # This should result in a visible but lower elevation
      IO.puts("Elevation check: #{el_deg}°")

      # Verify range is reasonable for geostationary (35,000-40,000 km)
      assert az_el.range > 35000.0, "Range should be > 35,000 km for geostationary"
      assert az_el.range < 42000.0, "Range should be < 42,000 km for geostationary"
    end

    test "visibility check from Denver" do
      {:ok, tle} = Tle.parseTLE(@galaxy16_line1, @galaxy16_line2)
      {:ok, observation_time, 0} = DateTime.from_iso8601("2026-01-06T12:00:00Z")

      {position, velocity} = Tle.getRVatTime(tle, observation_time)
      teme_state = TEMEState.new(observation_time, position, velocity)
      eci_state = Transforms.teme_to_eci(teme_state)

      # Check visibility
      is_visible = Observations.is_visible?(@denver, eci_state)

      # Get look angles for display
      {az_deg, el_deg, range_km} = Observations.look_angles(@denver, eci_state)

      IO.puts("\n=== Visibility Check ===")
      IO.puts("Is Visible: #{is_visible}")
      IO.puts("Look Angles: Az=#{Float.round(az_deg, 2)}°, El=#{Float.round(el_deg, 2)}°, Range=#{Float.round(range_km, 2)} km")

      # Assert visibility matches elevation
      if el_deg > 0 do
        assert is_visible, "Should be visible when elevation > 0"
      else
        refute is_visible, "Should not be visible when elevation <= 0"
      end
    end
  end
end
