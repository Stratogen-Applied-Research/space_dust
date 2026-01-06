defmodule SpaceDust.Time.Epoch do
  @moduledoc """
  Base module for time epoch types.

  All time types store time internally as seconds since their reference epoch,
  enabling efficient Nx-based conversions. Each time standard has its own
  reference epoch and relationship to other standards.

  ## Time Standards

  - **UTC** - Coordinated Universal Time (civil time, includes leap seconds)
  - **TAI** - International Atomic Time (continuous, no leap seconds)
  - **TT** - Terrestrial Time (used for ephemeris, TT = TAI + 32.184s)
  - **GPS** - GPS Time (GPS = TAI - 19s, started Jan 6, 1980)
  - **JD** - Julian Date (days since -4712 Jan 1, 12:00 TT)
  - **MJD** - Modified Julian Date (JD - 2400000.5)

  ## Unix Epoch Reference

  All internal representations use seconds from Unix epoch (1970-01-01 00:00:00 UTC)
  for efficient conversion and interoperability with Elixir DateTime.
  """

  @type seconds :: float()

  # Key epoch constants in Unix seconds
  # Unix epoch: 1970-01-01 00:00:00 UTC

  @doc "Julian Date at Unix epoch (JD 2440587.5)"
  def unix_epoch_jd, do: 2_440_587.5

  @doc "Seconds per day"
  def seconds_per_day, do: 86_400.0

  @doc "TAI-UTC offset at Unix epoch (10 leap seconds)"
  def tai_utc_at_unix_epoch, do: 10

  @doc "TT-TAI offset in seconds (constant 32.184s)"
  def tt_tai_offset, do: 32.184

  @doc "GPS-TAI offset in seconds (constant -19s, GPS = TAI - 19)"
  def gps_tai_offset, do: -19

  @doc "GPS epoch in Unix seconds (1980-01-06 00:00:00 UTC)"
  def gps_epoch_unix, do: 315_964_800

  @doc "J2000.0 epoch as Julian Date"
  def j2000_jd, do: 2_451_545.0
end
