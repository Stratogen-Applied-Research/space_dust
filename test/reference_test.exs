defmodule ReferenceTest do
  @moduledoc """
  Cross-checks against an independent implementation.

  Every expected value here was produced by `ferrocene`, an internal Rust astrodynamics
  library whose IAU 1980 chain is checked against SOFA in its own test suite.
  Both libraries were evaluated at the same epoch on the same inputs.

  These exist because the rest of the suite passed while the frame chain was
  wrong by hundreds of kilometres: nothing here was comparing against anything
  outside the library. Tolerances are set two to four orders of magnitude below
  the error each defect actually produced, and far enough above Earth-orientation
  data jitter that refreshing the IERS file will not move them.
  """
  use ExUnit.Case, async: false

  alias SpaceDust.Bodies.{Earth, Moon}
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
      # leaves the Moon on a near-circular orbit: 5 600 km of travel instead of
      # 44 000. Sampling six weeks is enough to see a full anomalistic month.
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
end
