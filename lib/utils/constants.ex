defmodule SpaceDust.Utils.Constants do

  # angular conversions
  def degreesToRadians, do: :math.pi / 180.0
  def radiansToDegrees, do: 180.0 / :math.pi
  def arcsecToRadians, do: :math.pi / 648000.0
  def radiansToArcsec, do: 648000.0 / :math.pi

  # time constants
  @doc "seconds per day - 86400.0"
  def secondsPerDay, do: 86400.0

  @doc "Julian century - 36525.0"
  def julianCentury, do: 36525.0

  @doc "Julian date of J2000.0 - 2451545.0"
  def j2000, do: 2451545.0

  @doc "Julian date of the Unix epoch - 1970-01-01 00:00:00 UTC (JD 2440587.5)"
  def unixEpochJulianDate, do: 2440587.5
end
