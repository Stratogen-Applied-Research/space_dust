defmodule SpaceDust.Bodies.Earth.PrecessionAngles do
  @moduledoc """
  Struct to hold the precession angles for the earth (radians)
  """
  defstruct [
    :zeta,
    :theta,
    :z
  ]
end

defmodule SpaceDust.Bodies.Earth.NutationAngles do
  @moduledoc """
  Struct to hold the nutation angles for the earth (radians)
  """
  defstruct [
    :dPsi,
    :dEps,
    :mEps,
    :eps,
    :eqEq,
    :gast
  ]
end

defmodule SpaceDust.Bodies.Earth do
  alias SpaceDust.Utils.Constants, as: Constants
  alias SpaceDust.Math.Functions, as: Math
  alias SpaceDust.Bodies.Earth.PrecessionAngles
  alias SpaceDust.Bodies.Earth.NutationAngles
  alias SpaceDust.Data.IAU1980, as: IAU1980
  alias SpaceDust.Data.IAU1980Data, as: IAU1980Data
  alias SpaceDust.Data.EOPCache
  alias SpaceDust.Math.Vector
  alias SpaceDust.Math.Vector.Vector3D
  alias SpaceDust.Time.{UTC, Transforms}

  # doc "'zeta' coefficients for earth precession - IAU 1976"
  # zeta = 2306.2181"T + 0.30188"T^2 + 0.017998"T^3
  defp zetaPoly do
    [
      0.017998 * Constants.arcsecToRadians(),
      0.30188 * Constants.arcsecToRadians(),
      2306.2181 * Constants.arcsecToRadians(),
      0.0
    ]
  end

  # doc "'theta' coefficients for earth precession - IAU 1976"
  # theta = 2004.3109"T - 0.42665"T^2 - 0.041833"T^3
  # Both higher-order terms are negative; theta shrinks relative to the linear term.
  defp thetaPoly do
    [
      -0.041833 * Constants.arcsecToRadians(),
      -0.42665 * Constants.arcsecToRadians(),
      2004.3109 * Constants.arcsecToRadians(),
      0.0
    ]
  end

  # doc "'z' coefficients for earth precession"
  defp zPoly do
    [
      0.018203 * Constants.arcsecToRadians(),
      1.09468 * Constants.arcsecToRadians(),
      2306.2181 * Constants.arcsecToRadians(),
      0.0
    ]
  end

  # doc "earth nutation lunar anomaly poly coefficients"
  defp lunarAnomalyPoly do
    [
      1.78e-5 * Constants.degreesToRadians(),
      0.0086972 * Constants.degreesToRadians(),
      (1325 * 360 + 198.8673981) * Constants.degreesToRadians(),
      134.96298139 * Constants.degreesToRadians()
    ]
  end

  # doc "earth nutation solar anomaly poly coefficients"
  defp solarAnomalyPoly do
    [
      -3.3e-6 * Constants.degreesToRadians(),
      -0.0001603 * Constants.degreesToRadians(),
      (99 * 360 + 359.05034) * Constants.degreesToRadians(),
      357.52772333 * Constants.degreesToRadians()
    ]
  end

  # doc "earth nutation lunar latitude poly coefficients"
  defp lunarLatitudePoly do
    [
      3.1e-6 * Constants.degreesToRadians(),
      -0.0036825 * Constants.degreesToRadians(),
      (1342 * 360 + 82.0175381) * Constants.degreesToRadians(),
      93.27191028 * Constants.degreesToRadians()
    ]
  end

  # doc "earth nutation sun elongation poly coefficients"
  defp sunElongationPoly do
    [
      5.3e-6 * Constants.degreesToRadians(),
      -0.0019142 * Constants.degreesToRadians(),
      (1236 * 360 + 307.1114800) * Constants.degreesToRadians(),
      297.85036306 * Constants.degreesToRadians()
    ]
  end

  # doc "earth nutation linar right ascension poly coefficients"
  defp lunarRaanPoly do
    [
      2.2e-6 * Constants.degreesToRadians(),
      0.0020708 * Constants.degreesToRadians(),
      -(5 * 360 + 134.1362608) * Constants.degreesToRadians(),
      125.04452222 * Constants.degreesToRadians()
    ]
  end

  # doc "earth mean obliquity of the ecliptic, IAU 1980"
  # eps_mean = 84381.448" - 46.8150"T - 0.00059"T^2 + 0.001813"T^3
  #
  # Kept in arcseconds because that is how the IAU defines it: 84381.448" is
  # exact, and the rounded degree form (23.439291) is 0.4 mas short of it.
  defp meanEpsilonPoly do
    [
      0.001813 * Constants.arcsecToRadians(),
      -0.00059 * Constants.arcsecToRadians(),
      -46.8150 * Constants.arcsecToRadians(),
      84_381.448 * Constants.arcsecToRadians()
    ]
  end

  @doc "earth gravitational parameter in m^3/s^2"
  def mu, do: 3.986004418e14

  @doc "earth equatorial radius in meters"
  def equatorialRadius, do: 6_378_137.0

  @doc "earth flattening (unitless)"
  def flattening, do: 1.0 / 298.257223563

  @doc "earth polar radius in meters"
  def polarRadius do
    equatorialRadius() * (1.0 - flattening())
  end

  @doc "earth mean radius in meters"
  def meanRadius do
    (2.0 * equatorialRadius() + polarRadius()) / 3.0
  end

  @doc "earth sidereal rotation rate in rad/s"
  def siderealRotationRate, do: 7.292115e-5

  @doc "earth sidereal rotation period in seconds"
  def siderealRotationPeriod do
    2.0 * :math.pi() / siderealRotationRate()
  end

  @doc "earth J2 coefficient (unitless)"
  def j2, do: 1.08262668355315e-3

  @doc "earth J3 coefficient (unitless)"
  def j3, do: -2.53265648533224e-6

  @doc "earth J4 coefficient (unitless)"
  def j4, do: -1.619621591367e-6

  @doc "earth J5 coefficient (unitless)"
  def j5, do: -2.27296082868698e-7

  @doc "earth J6 coefficient (unitless)"
  def j6, do: 5.40681239107085e-7

  @doc """
  Polar motion angles at an epoch, as `{xp, yp}` in radians.

  These orient the true celestial pole against the ITRF pole and are the `W`
  in the `W * R * N * P` chain from J2000 to Earth-fixed. They are tabulated by
  the IERS in arcseconds and are worth up to about 15 m at the Earth's surface.

  Returns `{0.0, 0.0}` when no EOP record covers the epoch, which degrades the
  Earth-fixed frame to the true-of-date pole rather than failing.
  """
  @spec polarMotion(DateTime.t()) :: {float(), float()}
  def polarMotion(epochUtc) do
    utc = UTC.from_datetime(epochUtc)

    case EOPCache.get(UTC.to_mjd(utc)) do
      {:ok, %{polarMotionX: xp, polarMotionY: yp}} when is_number(xp) and is_number(yp) ->
        {xp * Constants.arcsecToRadians(), yp * Constants.arcsecToRadians()}

      _ ->
        {0.0, 0.0}
    end
  end

  @doc """
  Calculate the IAU 1976 precession angles for the earth, in radians.

  The angles are defined on Julian centuries of *Terrestrial Time* since
  J2000.0, not UTC.
  """
  def precessionAngles(epochUtc) do
    utc = UTC.from_datetime(epochUtc)
    tt = Transforms.utc_to_tt(utc)
    t = SpaceDust.Time.TT.julian_centuries_j2000(tt)
    zeta = Math.polyEval(zetaPoly(), t)
    theta = Math.polyEval(thetaPoly(), t)
    z = Math.polyEval(zPoly(), t)

    %PrecessionAngles{
      zeta: zeta,
      theta: theta,
      z: z
    }
  end

  @doc """
  Rotate a mean-equinox-of-date (MOD) vector into ECI J2000.

  The low-precision Sun and Moon series are referred to the mean equinox of
  date, which by 2026 differs from J2000 by about 0.36 degrees - thirty-six
  times the Sun series' own accuracy. Anything combined with an `ECIState`, which
  is J2000, has to come through here first.

  This is the transpose of `precessionAngles/1`'s rotation: `ROT3(zeta)
  ROT2(-theta) ROT3(z)` in passive form.
  """
  @spec modToJ2000(Vector.vector(), DateTime.t()) :: Vector.vector()
  def modToJ2000(%Vector3D{} = vector, epochUtc) do
    %PrecessionAngles{zeta: zeta, theta: theta, z: z} = precessionAngles(epochUtc)

    vector
    |> rotateZ(z)
    |> rotateY(-theta)
    |> rotateZ(zeta)
  end

  # Passive (frame) rotations, matching SpaceDust.State.Transforms. Kept local
  # and in plain Elixir: Math.Vector.rotateZ/2 is an active rotation, and a
  # three-element rotation does not need an Nx tensor round trip.
  defp rotateZ(%Vector3D{x: x, y: y, z: z}, angle) do
    c = :math.cos(angle)
    s = :math.sin(angle)
    %Vector3D{x: c * x + s * y, y: -s * x + c * y, z: z}
  end

  defp rotateY(%Vector3D{x: x, y: y, z: z}, angle) do
    c = :math.cos(angle)
    s = :math.sin(angle)
    %Vector3D{x: c * x - s * z, y: y, z: s * x + c * z}
  end

  # doc "compute deltaPsi and deltaEpsilon from IAU 1980 nutation theory"
  defp iauToNutationAngles(
         iau1980,
         lunarAnomaly,
         solarAnomaly,
         lunarLatitude,
         sunElongation,
         lunarRaan,
         julianCenturies
       ) do
    case iau1980 do
      %IAU1980Data{} = iau1980 ->
        arg =
          iau1980.a1 * lunarAnomaly +
            iau1980.a2 * solarAnomaly +
            iau1980.a3 * lunarLatitude +
            iau1980.a4 * sunElongation +
            iau1980.a5 * lunarRaan

        sinC = iau1980.ai + iau1980.bi * julianCenturies
        cosC = iau1980.ci + iau1980.di * julianCenturies

        deltaPsi = sinC * :math.sin(arg)
        deltaEpsilon = cosC * :math.cos(arg)
        {deltaPsi, deltaEpsilon}
    end
  end

  @doc """
  Calculate the IAU 1980 nutation angles for the earth, in radians.

  `coeffs` is how many terms of the 106-term series to sum, longest-period
  first; the default is all of them. Truncating to the leading 4 costs about
  0.14 arcseconds, which is larger than everything else in this chain.
  """
  def nutationAngles(epochUtc, coeffs \\ IAU1980.termCount(), useEop \\ true) do
    utc = UTC.from_datetime(epochUtc)
    tt = Transforms.utc_to_tt(utc)
    julianCenturies = SpaceDust.Time.TT.julian_centuries_j2000(tt)

    lunarAnomaly = Math.polyEval(lunarAnomalyPoly(), julianCenturies)
    solarAnomaly = Math.polyEval(solarAnomalyPoly(), julianCenturies)
    lunarLatitude = Math.polyEval(lunarLatitudePoly(), julianCenturies)
    sunElongation = Math.polyEval(sunElongationPoly(), julianCenturies)
    lunarRaan = Math.polyEval(lunarRaanPoly(), julianCenturies)

    # sum results of nutation theory, in the published unit of 0.0001 arcsecond
    {deltaPsi, deltaEpsilon} =
      IAU1980.all()
      |> Enum.take(coeffs)
      |> Enum.reduce({0.0, 0.0}, fn term, {accPsi, accEps} ->
        {dPsi, dEps} =
          iauToNutationAngles(
            term,
            lunarAnomaly,
            solarAnomaly,
            lunarLatitude,
            sunElongation,
            lunarRaan,
            julianCenturies
          )

        {accPsi + dPsi, accEps + dEps}
      end)

    deltaPsiRad = deltaPsi * Constants.ttArcsecToRadians()
    deltaEpsilonRad = deltaEpsilon * Constants.ttArcsecToRadians()

    # The IERS celestial-pole offsets are tabulated in arcseconds; the series
    # above is already in radians, so they have to be scaled before they are
    # added. Missing EOP coverage costs well under a milliarcsecond here, so an
    # uncovered epoch falls back to the unadjusted series rather than failing.
    {finalDeltaPsi, finalDeltaEpsilon} =
      case useEop && EOPCache.get(UTC.to_mjd(utc)) do
        {:ok, %{dPsi: dPsi, dEps: dEps}} when is_number(dPsi) and is_number(dEps) ->
          {deltaPsiRad + dPsi * Constants.arcsecToRadians(),
           deltaEpsilonRad + dEps * Constants.arcsecToRadians()}

        _ ->
          {deltaPsiRad, deltaEpsilonRad}
      end

    meanEpsilon = Math.polyEval(meanEpsilonPoly(), julianCenturies)
    epsilon = meanEpsilon + finalDeltaEpsilon

    gmst = Transforms.utc_to_gmst(utc)

    # The equation of the equinoxes takes the *mean* obliquity, per IAU 1976/FK5.
    # The two complementary terms in the lunar node are the 1994 addition.
    eqEq =
      finalDeltaPsi * :math.cos(meanEpsilon) +
        0.00264 * Constants.arcsecToRadians() * :math.sin(lunarRaan) +
        0.000063 * Constants.arcsecToRadians() * :math.sin(2.0 * lunarRaan)

    gast = SpaceDust.Time.GMST.to_radians(gmst) + eqEq

    %NutationAngles{
      dPsi: finalDeltaPsi,
      dEps: finalDeltaEpsilon,
      mEps: meanEpsilon,
      eps: epsilon,
      eqEq: eqEq,
      gast: gast
    }
  end
end
