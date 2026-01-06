defmodule BodiesTest do
  use ExUnit.Case

  alias SpaceDust.Bodies.{Sun, Moon, Barycenter}
  alias SpaceDust.Math.Vector

  # Test epoch: J2000.0 - 2000-01-01 12:00:00 TT (approximately)
  @j2000_epoch ~U[2000-01-01 12:00:00Z]

  # Test epoch: Vernal equinox 2024
  @vernal_equinox_2024 ~U[2024-03-20 03:06:00Z]

  # Winter solstice 2024
  @winter_solstice_2024 ~U[2024-12-21 09:21:00Z]

  describe "Sun module" do
    test "constants are correct" do
      # Sun's gravitational parameter
      assert Sun.mu() > 1.3e20
      assert Sun.mu() < 1.4e20

      # Astronomical Unit
      assert Sun.au() > 1.49e11
      assert Sun.au() < 1.50e11

      # Solar radius
      assert Sun.radius() > 6.9e8
      assert Sun.radius() < 7.0e8
    end

    test "eci_position returns a Vector3D" do
      pos = Sun.eci_position(@j2000_epoch)
      assert %SpaceDust.Math.Vector.Vector3D{} = pos
    end

    test "eci_position magnitude is approximately 1 AU" do
      pos = Sun.eci_position(@j2000_epoch)
      r = Vector.magnitude(pos)

      # Should be within ~3% of 1 AU (Earth's orbital eccentricity ~1.7%)
      assert r > 0.97 * Sun.au()
      assert r < 1.03 * Sun.au()
    end

    test "distance function matches eci_position magnitude" do
      distance = Sun.distance(@j2000_epoch)
      pos = Sun.eci_position(@j2000_epoch)
      r = Vector.magnitude(pos)

      assert_in_delta(distance, r, 1.0)
    end

    test "direction returns unit vector" do
      dir = Sun.direction(@j2000_epoch)
      mag = Vector.magnitude(dir)

      assert_in_delta(mag, 1.0, 1.0e-10)
    end

    test "apparent_position returns valid RA and Dec" do
      {ra, dec} = Sun.apparent_position(@j2000_epoch)

      # RA should be in [0, 2π]
      assert ra >= 0
      assert ra < 2 * :math.pi()

      # Dec should be in [-π/2, π/2]
      assert dec >= -:math.pi() / 2
      assert dec <= :math.pi() / 2
    end

    test "sun position varies over the year" do
      pos1 = Sun.eci_position(@vernal_equinox_2024)
      pos2 = Sun.eci_position(@winter_solstice_2024)

      # Positions should be different (Earth has moved)
      diff = Vector.subtract(pos1, pos2)
      distance = Vector.magnitude(diff)

      # Should be significant (> 1 AU apart for ~9 months)
      assert distance > 0.5 * Sun.au()
    end
  end

  describe "Moon module" do
    test "constants are correct" do
      # Moon's gravitational parameter
      assert Moon.mu() > 4.9e12
      assert Moon.mu() < 5.0e12

      # Mean distance
      assert Moon.mean_distance() > 3.8e8
      assert Moon.mean_distance() < 3.9e8

      # Lunar radius
      assert Moon.radius() > 1.7e6
      assert Moon.radius() < 1.8e6
    end

    test "eci_position returns a Vector3D" do
      pos = Moon.eci_position(@j2000_epoch)
      assert %SpaceDust.Math.Vector.Vector3D{} = pos
    end

    test "eci_position magnitude is approximately mean lunar distance" do
      pos = Moon.eci_position(@j2000_epoch)
      r = Vector.magnitude(pos)

      # Should be within ~15% of mean distance (lunar orbit eccentricity ~5.5%)
      assert r > 0.85 * Moon.mean_distance()
      assert r < 1.15 * Moon.mean_distance()
    end

    test "distance function matches eci_position magnitude" do
      distance = Moon.distance(@j2000_epoch)
      pos = Moon.eci_position(@j2000_epoch)
      r = Vector.magnitude(pos)

      assert_in_delta(distance, r, 1.0)
    end

    test "direction returns unit vector" do
      dir = Moon.direction(@j2000_epoch)
      mag = Vector.magnitude(dir)

      assert_in_delta(mag, 1.0, 1.0e-10)
    end

    test "apparent_position returns valid RA and Dec" do
      {ra, dec} = Moon.apparent_position(@j2000_epoch)

      # RA should be in [0, 2π]
      assert ra >= 0
      assert ra < 2 * :math.pi()

      # Dec should be in [-π/2, π/2] (Moon's orbit is ~5° inclined)
      assert dec >= -:math.pi() / 2
      assert dec <= :math.pi() / 2
    end

    test "phase_angle returns valid angle" do
      phase = Moon.phase_angle(@j2000_epoch)

      # Phase angle should be in [0, π]
      assert phase >= 0
      assert phase <= :math.pi()
    end

    test "moon position varies over a month" do
      epoch1 = @j2000_epoch
      # ~14 days later (half lunar month)
      epoch2 = DateTime.add(epoch1, 14 * 24 * 3600, :second)

      pos1 = Moon.eci_position(epoch1)
      pos2 = Moon.eci_position(epoch2)

      # Positions should be significantly different
      diff = Vector.subtract(pos1, pos2)
      distance = Vector.magnitude(diff)

      # Should be significant (> 1/2 mean distance for half orbit)
      # Moon moves around Earth, so after half a period it should be
      # roughly on the opposite side
      assert distance > 0.5 * Moon.mean_distance()
    end
  end

  describe "Barycenter module" do
    test "mass constants are reasonable" do
      # Earth/Moon mass ratio ~81.3
      assert Barycenter.earth_moon_mass_ratio() > 80
      assert Barycenter.earth_moon_mass_ratio() < 83

      # Sun/Earth mass ratio ~333000
      assert Barycenter.sun_earth_mass_ratio() > 330_000
      assert Barycenter.sun_earth_mass_ratio() < 340_000
    end

    test "earth_moon_barycenter is inside Earth" do
      emb = Barycenter.earth_moon_barycenter(@j2000_epoch)
      r = Vector.magnitude(emb)

      # EMB should be inside Earth (~4670 km from Earth center)
      earth_radius = 6_378_137.0
      assert r < earth_radius
      assert r > 4_000_000  # But not at center
    end

    test "earth_moon_barycenter is along Earth-Moon line" do
      emb = Barycenter.earth_moon_barycenter(@j2000_epoch)
      moon_pos = Moon.eci_position(@j2000_epoch)

      # EMB direction should match Moon direction
      emb_dir = Vector.normalize(emb)
      moon_dir = Vector.normalize(moon_pos)

      # Dot product should be ~1 (same direction)
      dot = Vector.dot(emb_dir, moon_dir)
      assert_in_delta(dot, 1.0, 1.0e-10)
    end

    test "earth_heliocentric is opposite of Sun ECI position" do
      earth_helio = Barycenter.earth_heliocentric(@j2000_epoch)
      sun_eci = Sun.eci_position(@j2000_epoch)

      # Should be negatives of each other
      assert_in_delta(earth_helio.x, -sun_eci.x, 1.0)
      assert_in_delta(earth_helio.y, -sun_eci.y, 1.0)
      assert_in_delta(earth_helio.z, -sun_eci.z, 1.0)
    end

    test "moon_heliocentric is sum of earth_heliocentric and moon ECI" do
      moon_helio = Barycenter.moon_heliocentric(@j2000_epoch)
      earth_helio = Barycenter.earth_heliocentric(@j2000_epoch)
      moon_eci = Moon.eci_position(@j2000_epoch)

      expected = Vector.add(earth_helio, moon_eci)

      assert_in_delta(moon_helio.x, expected.x, 1.0)
      assert_in_delta(moon_helio.y, expected.y, 1.0)
      assert_in_delta(moon_helio.z, expected.z, 1.0)
    end

    test "eci_to_heliocentric and heliocentric_to_eci are inverses" do
      original_eci = Moon.eci_position(@j2000_epoch)

      helio = Barycenter.eci_to_heliocentric(original_eci, @j2000_epoch)
      recovered_eci = Barycenter.heliocentric_to_eci(helio, @j2000_epoch)

      assert_in_delta(original_eci.x, recovered_eci.x, 1.0)
      assert_in_delta(original_eci.y, recovered_eci.y, 1.0)
      assert_in_delta(original_eci.z, recovered_eci.z, 1.0)
    end

    test "distance_between earth and moon matches Moon.distance" do
      d1 = Barycenter.distance_between(:earth, :moon, @j2000_epoch)
      d2 = Moon.distance(@j2000_epoch)

      assert_in_delta(d1, d2, 1.0)
    end

    test "distance_between earth and sun matches Sun.distance" do
      d1 = Barycenter.distance_between(:earth, :sun, @j2000_epoch)
      d2 = Sun.distance(@j2000_epoch)

      assert_in_delta(d1, d2, 1.0)
    end

    test "body_heliocentric_position returns correct positions" do
      # Sun at origin
      sun_pos = Barycenter.body_heliocentric_position(:sun, @j2000_epoch)
      assert sun_pos.x == 0.0
      assert sun_pos.y == 0.0
      assert sun_pos.z == 0.0

      # Earth position matches earth_heliocentric
      earth_pos = Barycenter.body_heliocentric_position(:earth, @j2000_epoch)
      expected = Barycenter.earth_heliocentric(@j2000_epoch)
      assert_in_delta(earth_pos.x, expected.x, 1.0)
      assert_in_delta(earth_pos.y, expected.y, 1.0)
      assert_in_delta(earth_pos.z, expected.z, 1.0)
    end

    test "body_eci_position returns correct positions" do
      # Earth at origin
      earth_pos = Barycenter.body_eci_position(:earth, @j2000_epoch)
      assert earth_pos.x == 0.0
      assert earth_pos.y == 0.0
      assert earth_pos.z == 0.0

      # Sun position matches Sun.eci_position
      sun_pos = Barycenter.body_eci_position(:sun, @j2000_epoch)
      expected = Sun.eci_position(@j2000_epoch)
      assert_in_delta(sun_pos.x, expected.x, 1.0)
      assert_in_delta(sun_pos.y, expected.y, 1.0)
      assert_in_delta(sun_pos.z, expected.z, 1.0)
    end

    test "earth_orbital_elements returns reasonable values" do
      elements = Barycenter.earth_orbital_elements(@j2000_epoch)

      # Semi-major axis ~1 AU
      assert_in_delta(elements.semi_major_axis, Sun.au(), 1.0e9)

      # Eccentricity ~0.017
      assert_in_delta(elements.eccentricity, 0.0167, 0.001)

      # Distance should be between perihelion and aphelion
      assert elements.distance > 0.98 * Sun.au()
      assert elements.distance < 1.02 * Sun.au()

      # True anomaly in [0, 2π]
      assert elements.true_anomaly >= 0
      assert elements.true_anomaly < 2 * :math.pi()
    end
  end
end
