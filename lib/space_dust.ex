defmodule SpaceDust do
  @moduledoc """
  SpaceDust is a comprehensive astrodynamics library for Elixir.

  This library provides tools for satellite tracking, orbital mechanics,
  coordinate transformations, and ground-based observation calculations.

  ## Main Components

  ### Time Systems

  Convert between astronomical time systems:

    - `SpaceDust.Time.UTC` - Coordinated Universal Time
    - `SpaceDust.Time.TAI` - International Atomic Time
    - `SpaceDust.Time.TT` - Terrestrial Time
    - `SpaceDust.Time.JulianDate` - Julian Date / Modified Julian Date
    - `SpaceDust.Time.GMST` - Greenwich Mean Sidereal Time
    - `SpaceDust.Time.GPS` - GPS Time

  ### State Vectors

  Represent and transform orbital states:

    - `SpaceDust.State.ECIState` - Earth-Centered Inertial J2000 frame
    - `SpaceDust.State.TEMEState` - True Equator Mean Equinox frame
    - `SpaceDust.State.ECEFState` - Earth-Centered Earth-Fixed frame
    - `SpaceDust.State.GeodeticState` - Geodetic coordinates (lat/lon/alt)
    - `SpaceDust.State.KeplerianElements` - Classical orbital elements
    - `SpaceDust.State.Transforms` - Frame transformations

  ### Observations

  Calculate angular observations from ground stations:

    - `SpaceDust.Observations` - Observation computation functions
    - `SpaceDust.Observations.AzEl` - Azimuth/Elevation angles
    - `SpaceDust.Observations.RaDec` - Right Ascension/Declination

  ### Celestial Bodies

  Calculate positions of celestial bodies:

    - `SpaceDust.Bodies.Earth` - Earth orientation and parameters
    - `SpaceDust.Bodies.Sun` - Solar position calculations
    - `SpaceDust.Bodies.Moon` - Lunar position calculations
    - `SpaceDust.Bodies.Barycenter` - Earth-Moon barycenter

  ### Data

  Reference data and parameters:

    - `SpaceDust.Data.EOP` - Earth Orientation Parameters
    - `SpaceDust.Data.EOPCache` - High-performance EOP cache
    - `SpaceDust.Data.IAU1980` - Nutation coefficients
    - `SpaceDust.Data.LeapSecond` - Leap second table

  ### Utilities

  TLE parsing and propagation:

    - `SpaceDust.Utils.Tle` - TLE parsing and SGP4 propagation
    - `SpaceDust.Utils.Constants` - Physical constants
    - `SpaceDust.Ingest.Celestrak` - Celestrak TLE retrieval

  ## Quick Example

      alias SpaceDust.Ingest.Celestrak
      alias SpaceDust.Utils.Tle
      alias SpaceDust.State.{TEMEState, GeodeticState, Transforms}
      alias SpaceDust.Observations

      # Fetch TLE and propagate
      {:ok, tle} = Celestrak.pullLatestTLE("25544")
      epoch = DateTime.utc_now()
      {pos, vel} = Tle.getRVatTime(tle, epoch)

      # Convert to ECI and compute observation angles
      teme = TEMEState.new(epoch, pos, vel)
      eci = Transforms.teme_to_eci(teme)

      observer = GeodeticState.new(40.0, -105.0, 1.6)
      az_el = Observations.compute_az_el(observer, eci)
  """

  @doc """
  Returns library version information.

  ## Examples

      iex> SpaceDust.version()
      "0.2.0"

  """
  @spec version() :: String.t()
  def version do
    "0.2.0"
  end
end
