defmodule SpaceDust.Bodies.Earth do
  alias SpaceDust.Utils.Constants, as: Constants


  @doc "'zeta' coefficients for earth precession"
  defp zetaPoly do
    [0.017988 * Constants.arcsecToRadians,
     0.30188 * Constants.arcsecToRadians,
     2306.2181 * Constants.arcsecToRadians,
     0.0]
  end

  @doc "'theta' coefficients for earth precession"
  defp thetaPoly do
    [-0.041833 * Constants.arcsecToRadians,
     0.42665 * Constants.arcsecToRadians,
     2004.3109 * Constants.arcsecToRadians,
     0.0]
  end

  @doc "'z' coefficients for earth precession"
  defp zPoly do
    [0.018203 * Constants.arcsecToRadians,
     1.09468 * Constants.arcsecToRadians,
     2306.2181 * Constants.arcsecToRadians,
     0.0]
  end

  @doc "earth nutation lunar anomaly poly coefficients"
  defp lunarAnomalyPoly do
    [1.78e-5 * Constants.degreesToRadians,
    0.0086972 * Constants.degreesToRadians,
    (1325 * 360 + 198.8673981) * Constants.degreesToRadians,
  134.96298139 * Constants.degreesToRadians]
  end

  @doc "earth nutation solar anomaly poly coefficients"
  defp solarAnomalyPoly do
    [-3.3e-6 * Constants.degreesToRadians,
    -0.0001603 * Constants.degreesToRadians,
    (99 * 360 + 359.05034) * Constants.degreesToRadians,
  357.52772333 * Constants.degreesToRadians]
  end

  @doc "earth nutation lunar latitude poly coefficients"
  defp lunarLatitudePoly do
    [3.1e-6 * Constants.degreesToRadians,
    -0.0036825 * Constants.degreesToRadians,
    (1342 * 360 + 82.0175381) * Constants.degreesToRadians,
    93.27191028 * Constants.degreesToRadians]
  end

  @doc "earth nutation sun elongation poly coefficients"
  defp sunElongationPoly do
    [5.3e-6 * Constants.degreesToRadians,
    -0.0019142 * Constants.degreesToRadians,
    (1236 * 360 + 307.1114800) * Constants.degreesToRadians,
    297.85036306 * Constants.degreesToRadians]
  end

  @doc "earth nutation linar right ascension poly coefficients"
  defp lunarRaanPoly do
    [2.2e-6 * Constants.degreesToRadians,
    0.0020708 * Constants.degreesToRadians,
    -(5 * 360 + 134.1362608) * Constants.degreesToRadians,
    125.04452222 * Constants.degreesToRadians]
  end

  @doc "earth nutation mean epsilon poly coefficients"
  defp meanEpsilonPoly do
    [5.04e-7 * Constants.degreesToRadians,
    -1.64e-7 * Constants.degreesToRadians,
    -0.0130042 * Constants.degreesToRadians,
    23.439291 * Constants.degreesToRadians]
  end
end
