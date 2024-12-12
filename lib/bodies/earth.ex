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
  alias SpaceDust.Utils.Math, as: Math
  alias SpaceDust.Bodies.Earth.PrecessionAngles
  alias SpaceDust.Bodies.Earth.NutationAngles

  @doc "'zeta' coefficients for earth precession"
  defp zetaPoly do
    [
      0.017988 * Constants.arcsecToRadians(),
      0.30188 * Constants.arcsecToRadians(),
      2306.2181 * Constants.arcsecToRadians(),
      0.0
    ]
  end

  @doc "'theta' coefficients for earth precession"
  defp thetaPoly do
    [
      -0.041833 * Constants.arcsecToRadians(),
      0.42665 * Constants.arcsecToRadians(),
      2004.3109 * Constants.arcsecToRadians(),
      0.0
    ]
  end

  @doc "'z' coefficients for earth precession"
  defp zPoly do
    [
      0.018203 * Constants.arcsecToRadians(),
      1.09468 * Constants.arcsecToRadians(),
      2306.2181 * Constants.arcsecToRadians(),
      0.0
    ]
  end

  @doc "earth nutation lunar anomaly poly coefficients"
  defp lunarAnomalyPoly do
    [
      1.78e-5 * Constants.degreesToRadians(),
      0.0086972 * Constants.degreesToRadians(),
      (1325 * 360 + 198.8673981) * Constants.degreesToRadians(),
      134.96298139 * Constants.degreesToRadians()
    ]
  end

  @doc "earth nutation solar anomaly poly coefficients"
  defp solarAnomalyPoly do
    [
      -3.3e-6 * Constants.degreesToRadians(),
      -0.0001603 * Constants.degreesToRadians(),
      (99 * 360 + 359.05034) * Constants.degreesToRadians(),
      357.52772333 * Constants.degreesToRadians()
    ]
  end

  @doc "earth nutation lunar latitude poly coefficients"
  defp lunarLatitudePoly do
    [
      3.1e-6 * Constants.degreesToRadians(),
      -0.0036825 * Constants.degreesToRadians(),
      (1342 * 360 + 82.0175381) * Constants.degreesToRadians(),
      93.27191028 * Constants.degreesToRadians()
    ]
  end

  @doc "earth nutation sun elongation poly coefficients"
  defp sunElongationPoly do
    [
      5.3e-6 * Constants.degreesToRadians(),
      -0.0019142 * Constants.degreesToRadians(),
      (1236 * 360 + 307.1114800) * Constants.degreesToRadians(),
      297.85036306 * Constants.degreesToRadians()
    ]
  end

  @doc "earth nutation linar right ascension poly coefficients"
  defp lunarRaanPoly do
    [
      2.2e-6 * Constants.degreesToRadians(),
      0.0020708 * Constants.degreesToRadians(),
      -(5 * 360 + 134.1362608) * Constants.degreesToRadians(),
      125.04452222 * Constants.degreesToRadians()
    ]
  end

  @doc "earth nutation mean epsilon poly coefficients"
  defp meanEpsilonPoly do
    [
      5.04e-7 * Constants.degreesToRadians(),
      -1.64e-7 * Constants.degreesToRadians(),
      -0.0130042 * Constants.degreesToRadians(),
      23.439291 * Constants.degreesToRadians()
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


  @doc "calculate the precession angles for the earth"
  def precessionAngles(julianDate) do
    t = (julianDate - Constants.j2000()) / 36525.0
    zeta = Math.polyEval(zetaPoly(), t)
    theta = Math.polyEval(thetaPoly(), t)
    z = Math.polyEval(zPoly(), t)

    %PrecessionAngles{
      zeta: zeta,
      theta: theta,
      z: z
    }
  end
end
