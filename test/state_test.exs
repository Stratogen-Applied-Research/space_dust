defmodule StateTest do
  use ExUnit.Case

  alias SpaceDust.State.TEMEState
  alias SpaceDust.State.ECIState
  alias SpaceDust.State.ECEFState
  alias SpaceDust.State.KeplerianElements
  alias SpaceDust.State.Transforms

  describe "state types" do
    test "create TEME state" do
      epoch = ~U[2024-01-01 12:00:00Z]
      pos = {6678.0, 0.0, 0.0}
      vel = {0.0, 7.73, 0.0}

      state = TEMEState.new(epoch, pos, vel)

      assert state.epoch == epoch
      assert state.position == pos
      assert state.velocity == vel
    end

    test "create ECI state" do
      epoch = ~U[2024-01-01 12:00:00Z]
      pos = {6678.0, 0.0, 0.0}
      vel = {0.0, 7.73, 0.0}

      state = ECIState.new(epoch, pos, vel)

      assert state.epoch == epoch
      assert state.position == pos
      assert state.velocity == vel
    end

    test "create ECEF state and convert to geodetic" do
      epoch = ~U[2024-01-01 12:00:00Z]
      # Point on equator at prime meridian, ~300km altitude
      pos = {6678.0, 0.0, 0.0}
      vel = {0.0, 0.0, 0.0}

      state = ECEFState.new(epoch, pos, vel)
      {lat, lon, alt} = ECEFState.to_geodetic(state)

      # Should be near equator, prime meridian
      assert_in_delta lat, 0.0, 0.1
      assert_in_delta lon, 0.0, 0.1
      assert_in_delta alt, 299.863, 1.0
    end

    test "create Keplerian elements" do
      # ISS-like orbit
      a = 6778.0  # km
      e = 0.0001
      i = 51.6 * :math.pi() / 180.0
      raan = 0.0
      w = 0.0
      nu = 0.0

      elements = KeplerianElements.new(a, e, i, raan, w, nu)

      assert_in_delta elements.semi_major_axis, 6778.0, 0.01
      assert_in_delta elements.eccentricity, 0.0001, 0.00001

      # Check orbital period (~92 minutes for ISS)
      period_minutes = KeplerianElements.period(elements) / 60.0
      assert_in_delta period_minutes, 92.5, 1.0
    end
  end

  describe "coordinate transforms" do
    test "TEME to ECI J2000 and back" do
      epoch = ~U[2024-01-01 12:00:00Z]
      pos = {6678.0, 1000.0, 500.0}
      vel = {-1.0, 7.5, 0.5}

      teme_state = TEMEState.new(epoch, pos, vel)
      eci_state = Transforms.teme_to_eci(teme_state)
      teme_back = Transforms.eci_to_teme(eci_state)

      # Should get back approximately the same state
      {x, y, z} = teme_back.position
      {ox, oy, oz} = pos
      assert_in_delta x, ox, 0.001
      assert_in_delta y, oy, 0.001
      assert_in_delta z, oz, 0.001

      {vx, vy, vz} = teme_back.velocity
      {ovx, ovy, ovz} = vel
      assert_in_delta vx, ovx, 0.0001
      assert_in_delta vy, ovy, 0.0001
      assert_in_delta vz, ovz, 0.0001
    end

    test "ECI to ECEF and back" do
      epoch = ~U[2024-01-01 12:00:00Z]
      pos = {6678.0, 1000.0, 500.0}
      vel = {-1.0, 7.5, 0.5}

      eci_state = ECIState.new(epoch, pos, vel)
      ecef_state = Transforms.eci_to_ecef(eci_state)
      eci_back = Transforms.ecef_to_eci(ecef_state)

      # Should get back approximately the same state
      {x, y, z} = eci_back.position
      {ox, oy, oz} = pos
      assert_in_delta x, ox, 0.001
      assert_in_delta y, oy, 0.001
      assert_in_delta z, oz, 0.001

      {vx, vy, vz} = eci_back.velocity
      {ovx, ovy, ovz} = vel
      assert_in_delta vx, ovx, 0.0001
      assert_in_delta vy, ovy, 0.0001
      assert_in_delta vz, ovz, 0.0001
    end

    test "TEME to ECEF" do
      epoch = ~U[2024-01-01 12:00:00Z]
      pos = {6678.0, 0.0, 0.0}
      vel = {0.0, 7.73, 0.0}

      teme_state = TEMEState.new(epoch, pos, vel)
      ecef_state = Transforms.teme_to_ecef(teme_state)

      # ECEF position magnitude should be preserved
      {x, y, z} = ecef_state.position
      r_ecef = :math.sqrt(x * x + y * y + z * z)
      r_teme = :math.sqrt(6678.0 * 6678.0)
      assert_in_delta r_ecef, r_teme, 0.1
    end
  end

  describe "Keplerian conversions" do
    test "Cartesian to Keplerian and back" do
      epoch = ~U[2024-01-01 12:00:00Z]

      # Circular equatorial orbit at ~300km altitude
      r = 6678.0  # km
      v = :math.sqrt(398600.4418 / r)  # Circular velocity

      eci_state = ECIState.new(epoch, {r, 0.0, 0.0}, {0.0, v, 0.0})

      elements = Transforms.to_keplerian(eci_state)

      # Check semi-major axis
      assert_in_delta elements.semi_major_axis, r, 0.1

      # Check eccentricity (should be near-circular)
      assert elements.eccentricity < 0.001

      # Check inclination (should be equatorial)
      assert_in_delta elements.inclination, 0.0, 0.001

      # Convert back to Cartesian
      eci_back = Transforms.keplerian_to_eci(elements)

      {x, y, z} = eci_back.position
      assert_in_delta x, r, 0.1
      assert_in_delta y, 0.0, 0.1
      assert_in_delta z, 0.0, 0.1

      {vx, vy, vz} = eci_back.velocity
      assert_in_delta vx, 0.0, 0.001
      assert_in_delta vy, v, 0.001
      assert_in_delta vz, 0.0, 0.001
    end

    test "Keplerian elements orbital parameters" do
      # Elliptical orbit
      a = 10000.0  # km
      e = 0.2
      i = 45.0 * :math.pi() / 180.0
      raan = 30.0 * :math.pi() / 180.0
      w = 60.0 * :math.pi() / 180.0
      nu = 0.0  # At perigee

      elements = KeplerianElements.new(a, e, i, raan, w, nu)

      # Check periapsis and apoapsis
      assert_in_delta KeplerianElements.periapsis(elements), 8000.0, 0.1
      assert_in_delta KeplerianElements.apoapsis(elements), 12000.0, 0.1

      # Check angular momentum
      h = KeplerianElements.angular_momentum(elements)
      assert h > 0
    end
  end
end
