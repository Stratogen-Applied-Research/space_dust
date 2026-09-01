defmodule ReferenceTest do
  @moduledoc """
  Cross-checks against an independent implementation.

  Every expected value here was produced by `ferrocene`, an internal Rust astrodynamics
  library whose IAU 1980 chain is checked against SOFA in its own test suite.
  Both libraries were evaluated at the same epoch on the same inputs.

  These exist because the rest of the suite passed while the frame chain was
  wrong by hundreds of kilometers: nothing here was comparing against anything
  outside the library. Tolerances are set two to four orders of magnitude below
  the error each defect actually produced, and far enough above Earth-orientation
  data jitter that refreshing the IERS file will not move them.
  """
  use ExUnit.Case, async: false

  alias SpaceDust.Bodies.{Earth, Moon, Sun}
  alias SpaceDust.Math.Vector
  alias SpaceDust.Observations
  alias SpaceDust.Observations.AzEl
  alias SpaceDust.State.{ECEFState, ECIState, GeodeticState, TEMEState}
  alias SpaceDust.State.Transforms, as: ST
  alias SpaceDust.Time.{GMST, Transforms, UTC}
  alias SpaceDust.Utils.Tle

  @epoch ~U[2026-01-06 12:00:00Z]

  defp distance_km({x1, y1, z1}, {x2, y2, z2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2) + :math.pow(z2 - z1, 2))
  end

  describe "sidereal time" do
    test "GMST matches the reference at every hour of the day" do
      # The IAU 1982 polynomial is defined at 0h UT1. Evaluating it at the full
      # Julian Date and *also* adding the fractional-day term counts the day
      # twice: zero error at midnight, growing to 0.0151 rad by 21h. Sampling
      # across the day is what catches it - a midnight-only check cannot.
      expected = %{0 => 1.842877368876, 6 => 3.417974393641, 12 => 4.993071418414, 18 => 0.284983135990}

      for {hour, want} <- expected do
        jd = UTC.to_jd(UTC.from_datetime(DateTime.new!(~D[2026-01-06], Time.new!(hour, 0, 0))))
        got = GMST.to_radians(Transforms.jd_to_gmst(SpaceDust.Time.JulianDate.new(jd)))

        assert_in_delta got, want, 1.0e-9,
                        "GMST at #{hour}h UT1 is #{got}, reference is #{want}"
      end
    end

    test "GMST is formed from UT1, not UTC" do
      utc = UTC.from_datetime(@epoch)
      from_ut1 = GMST.to_radians(Transforms.utc_to_gmst(utc))
      from_utc = GMST.to_radians(Transforms.jd_to_gmst(SpaceDust.Time.JulianDate.new(UTC.to_jd(utc))))

      # UT1 - UTC was about +0.0737 s here, which is 5.4e-6 rad of rotation.
      assert Transforms.utc_to_ut1_jd(utc) != UTC.to_jd(utc)
      assert_in_delta from_ut1 - from_utc, 5.38e-6, 5.0e-7
    end
  end

  describe "Earth orientation" do
    test "precession angles match the reference" do
      angles = Earth.precessionAngles(@epoch)

      assert_in_delta angles.zeta, 2.908808291401e-3, 1.0e-12
      assert_in_delta angles.theta, 2.527784980188e-3, 1.0e-12
      assert_in_delta angles.z, 2.909068437548e-3, 1.0e-12
    end

    test "nutation angles are arcsecond-scale and match the reference" do
      # dPsi peaks near 17 arcseconds. A units slip in the 0.0001-arcsecond
      # coefficient table, or adding the IERS pole offsets without converting
      # them from arcseconds, both land here as a factor of ten or more.
      n = Earth.nutationAngles(@epoch)

      assert_in_delta n.dPsi, 2.997256998685e-5, 5.0e-8
      assert_in_delta n.dEps, 3.991675649065e-5, 5.0e-8
      assert_in_delta n.mEps, 0.409033758965, 1.0e-9
      assert_in_delta n.gast, 4.993104299082, 1.0e-7
    end

    test "the full 106-term nutation series is summed by default" do
      truncated = Earth.nutationAngles(@epoch, 4)
      full = Earth.nutationAngles(@epoch)

      assert full.dPsi == Earth.nutationAngles(@epoch, 106).dPsi
      assert abs(full.dPsi - truncated.dPsi) > 1.0e-9
    end

    test "polar motion is returned in radians" do
      {xp, yp} = Earth.polarMotion(@epoch)

      assert_in_delta xp, 5.0070e-7, 5.0e-10
      assert_in_delta yp, 1.6319e-6, 5.0e-10
    end
  end

  describe "frame transforms" do
    # A geostationary state, where a rotation error shows up at its largest.
    @geo_teme_pos {-41851.32900600911, -5169.267703342104, 11.746394989381328}
    @geo_teme_vel {0.37775380813591286, -3.0510398632978495, -4.582707610246194e-4}

    test "TEME to ECI J2000 matches the reference" do
      # Applying the precession matrix in the wrong direction put this 541 km out.
      got = ST.teme_to_eci(TEMEState.new(@epoch, @geo_teme_pos, @geo_teme_vel)).position

      assert distance_km(got, {-41880.665304, -4924.544479, 118.074220}) < 0.1
    end

    test "TEME to ECI and back is an identity" do
      teme = TEMEState.new(@epoch, @geo_teme_pos, @geo_teme_vel)
      round_tripped = teme |> ST.teme_to_eci() |> ST.eci_to_teme()

      assert distance_km(round_tripped.position, teme.position) < 1.0e-9
    end

    test "ECI to ECEF applies the whole W * R * N * P chain" do
      # Rz(GAST) alone - no precession, no nutation, no polar motion - put this
      # 645 km out, and left z untouched, which a rotation about z cannot change.
      eci = ECIState.new(@epoch, {-41851.0, -5169.0, 11.7}, {0.377, -3.066, 0.0})
      got = ST.eci_to_ecef(eci).position

      assert distance_km(got, {-6384.288598, -41682.811681, -94.701594}) < 0.1
      {_, _, z} = got
      refute_in_delta z, 11.7, 1.0
    end

    test "ECI to ECEF matches the reference in low Earth orbit" do
      eci = ECIState.new(@epoch, {7000.0, 0.0, 0.0}, {0.0, 7.546, 0.0})
      got = ST.eci_to_ecef(eci).position

      assert distance_km(got, {1899.946827, 6737.201667, 17.769435}) < 0.1
    end

    test "ECI to ECEF and back is an identity" do
      eci = ECIState.new(@epoch, {-41851.0, -5169.0, 11.7}, {0.377, -3.066, 0.0})
      round_tripped = eci |> ST.eci_to_ecef() |> ST.ecef_to_eci()

      assert distance_km(round_tripped.position, eci.position) < 1.0e-9
    end
  end

  describe "Keplerian elements" do
    # Degenerate geometry: an undefined node or an undefined perigee. Reporting
    # zero for the missing angle without moving the reference direction loses
    # the orbit's orientation entirely.
    @cases [
      {"inclined", {7000.0, 0.001, 0.0001}, {0.0, 5.0, 5.6}},
      {"equatorial eccentric", {0.0, 7000.0, 0.0}, {-8.5, 0.0, 0.0}},
      {"circular inclined", {0.0, 4949.7475, 4949.7475}, {-7.546, 0.0, 0.0}},
      {"near-circular equatorial", {7000.0, 0.0, 0.0}, {0.0, 7.546, 0.0}}
    ]

    for {name, position, velocity} <- @cases do
      test "#{name} orbits round-trip through classical elements" do
        state =
          ECIState.new(@epoch, unquote(Macro.escape(position)), unquote(Macro.escape(velocity)))

        round_tripped =
          state
          |> ST.to_keplerian()
          |> ST.keplerian_to_eci()

        assert distance_km(round_tripped.position, state.position) < 1.0e-6
      end
    end

    test "an equatorial orbit keeps its longitude of perigee" do
      # Perigee is at +y. With the node undefined the argument of perigee has to
      # be measured from the vernal equinox instead, giving pi/2 - not zero.
      elements =
        ECIState.new(@epoch, {0.0, 7000.0, 0.0}, {-8.5, 0.0, 0.0})
        |> ST.to_keplerian()

      assert_in_delta elements.inclination, 0.0, 1.0e-12
      assert_in_delta elements.arg_perigee, :math.pi() / 2.0, 1.0e-9
      assert_in_delta elements.eccentricity, 0.26881444916652386, 1.0e-12
    end

    test "near-degenerate geometry does not raise" do
      # acos of a value a rounding step outside [-1, 1] raises ArithmeticError.
      # This state produced acos(-1.0000000000000002).
      state = ECIState.new(@epoch, {0.0, 4949.7475, 4949.7475}, {-7.546, 0.0, 0.0})
      elements = ST.to_keplerian(state)

      assert_in_delta elements.inclination, :math.pi() / 4.0, 1.0e-12
      assert is_float(elements.true_anomaly)
    end
  end

  describe "lunar ephemeris" do
    test "the distance spans the real perigee-to-apogee range" do
      # A series in Earth radii with amplitudes an order of magnitude short
      # leaves the Moon on a near-circular orbit: 5,600 km of travel instead of
      # 44,000. Sampling six weeks is enough to see a full anomalistic month.
      {closest, farthest} =
        Enum.reduce(0..41, {1.0e30, 0.0}, fn day, {lo, hi} ->
          r =
            ~U[2026-01-01 00:00:00Z]
            |> DateTime.add(day * 86_400, :second)
            |> Moon.eci_position()
            |> Vector.magnitude()

          {min(lo, r), max(hi, r)}
        end)

      assert farthest - closest > 40_000_000.0,
             "distance only spans #{(farthest - closest) / 1000.0} km"

      assert closest > 350_000_000.0 and closest < 372_000_000.0
      assert farthest > 400_000_000.0 and farthest < 410_000_000.0
    end

    test "the distance at the reference epoch matches" do
      assert_in_delta Vector.magnitude(Moon.eci_position(@epoch)), 376_858_432.0, 5_000.0
    end
  end

  describe "end to end" do
    test "GALAXY-16 look angles from Denver match the reference" do
      line1 = "1 29236U 06023A   26006.23725337 -.00000127  00000+0  00000+0 0  9998"
      line2 = "2 29236   0.0411 205.2172 0003166  95.2511 151.7365  1.00272365 71347"

      {:ok, tle} = Tle.parseTLE(line1, line2)
      {position, velocity} = Tle.getRVatTime(tle, @epoch)

      eci = ST.teme_to_eci(TEMEState.new(@epoch, position, velocity))
      observation = Observations.compute_az_el(GeodeticState.new(39.7392, -104.9903, 1.609), eci)
      {azimuth_deg, elevation_deg} = AzEl.to_degrees(observation)

      # Before the frame chain was corrected these were out by 0.330 and 0.154
      # degrees respectively - 186 km of cross-range at geostationary radius.
      assert_in_delta azimuth_deg, 170.734051, 1.0e-3
      assert_in_delta elevation_deg, 43.650504, 1.0e-3
      assert_in_delta observation.range, 37_505.559813, 0.05
    end

    test "a ground site round-trips through ECI" do
      site = GeodeticState.new(39.7392, -104.9903, 1.609)
      ecef = GeodeticState.to_ecef(site, @epoch)

      round_tripped =
        ecef
        |> ST.ecef_to_eci()
        |> ST.eci_to_ecef()

      assert distance_km(round_tripped.position, ecef.position) < 1.0e-9
      assert %ECEFState{} = ecef
    end
  end
  describe "geodetic conversion" do
    # Altitude as p / cos(lat) is 0/0 on the polar axis, which reported the
    # altitude as minus the prime-vertical radius - 6400 km below the pole.
    @polar_cases [
      {"north pole, on the ellipsoid", {0.0, 0.0, 6356.7523142}, 90.0, -4.5e-8},
      {"north pole, 100 km up", {0.0, 0.0, 6456.7523142}, 90.0, 99.999999955},
      {"one meter off the axis", {0.001, 0.0, 6356.7523142}, 89.999991047, -3.105e-6},
      {"south pole", {0.0, 0.0, -6356.7523142}, -90.0, -4.5e-8}
    ]

    for {name, position, latitude_deg, altitude_km} <- @polar_cases do
      test "#{name}" do
        {lat, _lon, alt} =
          ECEFState.to_geodetic(
            ECEFState.new(@epoch, unquote(Macro.escape(position)), {0.0, 0.0, 0.0})
          )

        assert_in_delta lat, unquote(latitude_deg), 1.0e-8
        assert_in_delta alt, unquote(altitude_km), 1.0e-6
      end
    end

    test "ECEFState and GeodeticState agree, because there is only one implementation" do
      position = {-1270.6453909, -4745.3264885, 4056.7836714}
      {lat, lon, alt} = ECEFState.to_geodetic(ECEFState.new(@epoch, position, {0.0, 0.0, 0.0}))
      geodetic = GeodeticState.from_ecef(ECEFState.new(@epoch, position, {0.0, 0.0, 0.0}))

      assert geodetic.latitude == lat
      assert geodetic.longitude == lon
      assert geodetic.altitude == alt
    end

    test "a geodetic site round-trips through ECEF" do
      for {lat, lon, alt} <- [{39.7392, -104.9903, 1.609}, {-33.9, 151.2, 0.058}, {89.9, 0.0, 0.0}] do
        site = GeodeticState.new(lat, lon, alt)

        back =
          site
          |> GeodeticState.to_ecef(@epoch)
          |> GeodeticState.from_ecef()

        assert_in_delta back.latitude, lat, 1.0e-9
        assert_in_delta back.longitude, lon, 1.0e-9
        assert_in_delta back.altitude, alt, 1.0e-9
      end
    end
  end

  describe "solar and lunar ephemerides" do
    # The series are referred to the mean equinox of date; returning them
    # unrotated under an "ECI J2000" name left them off by the precession angle,
    # which by 2026 is 0.36 degrees - thirty-six times the Sun series' accuracy.
    @body_epochs [
      {~U[2021-03-14 07:00:00Z], {147_793_461_754.259, -15_300_149_351.860, -6_632_555_179.162},
       {396_742_244.525, 34_933_816.758, -20_615_371.615}},
      {~U[2024-06-01 00:00:00Z], {50_409_092_576.879, 131_274_187_853.131, 56_905_711_416.475},
       {368_489_613.459, -10_689_768.441, -14_658_430.136}},
      {~U[2026-01-06 12:00:00Z], {39_884_653_043.473, -129_910_178_140.936, -56_313_870_013.436},
       {-315_359_595.844, 186_128_153.629, 89_033_217.668}}
    ]

    defp angle_deg(a, {x, y, z}) do
      Vector.angle(a, %SpaceDust.Math.Vector.Vector3D{x: x, y: y, z: z}) * 180.0 / :math.pi()
    end

    test "the Sun is returned in J2000, not mean-of-date" do
      for {epoch, sun_ref, _moon_ref} <- @body_epochs do
        # The reference holds the longitude of perihelion fixed at its J2000
        # value where this series tracks its real 0.3 deg/century motion, so the
        # two drift apart linearly with time. At J2000 itself they agree to
        # 0.005 deg, which is what pins the rotation - see the test below.
        assert angle_deg(Sun.eci_position(epoch), sun_ref) < 0.1
        assert angle_deg(Sun.mod_position(epoch), sun_ref) > 0.3
      end
    end

    test "the Sun matches the reference at J2000, where the two frames coincide" do
      epoch = ~U[2000-01-01 12:00:00Z]
      reference = {26_508_949_246.335, -132_752_486_846.951, -57_555_271_422.649}

      assert angle_deg(Sun.eci_position(epoch), reference) < 0.01
      # MOD and J2000 are the same frame at J2000.0, so the rotation is a no-op.
      assert_in_delta angle_deg(Sun.mod_position(epoch), reference),
                      angle_deg(Sun.eci_position(epoch), reference),
                      1.0e-6
    end

    test "the Moon is returned in J2000, not mean-of-date" do
      for {epoch, _sun_ref, moon_ref} <- @body_epochs do
        assert angle_deg(Moon.eci_position(epoch), moon_ref) < 0.03
        assert angle_deg(Moon.mod_position(epoch), moon_ref) > 0.25
      end
    end

    test "the phase angle does not raise at new or full moon" do
      # A bare acos of the dot product raises once rounding pushes it outside
      # [-1, 1], which is exactly what happens at syzygy.
      for day <- 0..60 do
        epoch = DateTime.add(~U[2026-01-01 00:00:00Z], day * 86_400, :second)
        angle = Moon.phase_angle(epoch)

        assert angle >= 0.0 and angle <= :math.pi()
      end
    end
  end

  describe "TLE parsing" do
    @line2 "2 25544  51.6400 208.1200 0001234  85.0000 275.0000 15.48919100123456"

    defp parse_epoch_year(two_digit_year) do
      line1 = "1 25544U 98067A   #{two_digit_year}006.50000000  .00016717  00000-0  10270-3 0  9002"
      {:ok, tle} = Tle.parseTLE(line1, @line2)
      tle.epoch.year
    end

    test "the epoch year pivots at 57, not on today's date" do
      # NORAD's fixed window: 57-99 are 1957-1999, 00-56 are 2000-2056. Pivoting
      # on the current year sent YY=27 to 1927 and changed its own answer as the
      # calendar advanced.
      assert parse_epoch_year("00") == 2000
      assert parse_epoch_year("26") == 2026
      assert parse_epoch_year("27") == 2027
      assert parse_epoch_year("30") == 2030
      assert parse_epoch_year("56") == 2056
      assert parse_epoch_year("57") == 1957
      assert parse_epoch_year("99") == 1999
    end

    test "BSTAR parses whichever way the sign column is written" do
      # Some producers leave the sign column blank for a positive value, others
      # write "+". Folding it into the mantissa made "+10270-3" fail the parse
      # and rejected the whole element set.
      for {field, expected} <- [
            {" 10270-3", 1.027e-4},
            {"+10270-3", 1.027e-4},
            {"-10270-3", -1.027e-4},
            {" 00000+0", 0.0}
          ] do
        line1 = "1 25544U 98067A   26006.50000000  .00016717  00000-0 #{field} 0  9002"

        assert {:ok, tle} = Tle.parseTLE(line1, @line2)
        assert_in_delta tle.bStar, expected, 1.0e-12
      end
    end
  end

  describe "vector math" do
    test "the angle between vectors normalizes and clamps" do
      unit = fn {x, y, z} -> %SpaceDust.Math.Vector.Vector3D{x: x, y: y, z: z} end

      # acos(dot) without normalizing gives acos(9.0) here, which raises.
      assert_in_delta Vector.angle(unit.({3.0, 0.0, 0.0}), unit.({3.0, 0.0, 0.0})), 0.0, 1.0e-12
      assert_in_delta Vector.angle(unit.({3.0, 0.0, 0.0}), unit.({0.0, 4.0, 0.0})),
                      :math.pi() / 2.0,
                      1.0e-12

      assert_in_delta Vector.angle(unit.({2.0, 0.0, 0.0}), unit.({-5.0, 0.0, 0.0})),
                      :math.pi(),
                      1.0e-12
    end
  end
end
