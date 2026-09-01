defmodule SpaceDust.Bodies.Sun do
  @moduledoc """
  Solar body parameters and position calculations.

  Provides functions to compute the Sun's position in various coordinate frames,
  including ECI (Earth-Centered Inertial) and heliocentric coordinates.

  The algorithms are based on low-precision solar coordinates from the
  Astronomical Almanac (approximate accuracy ~0.01 degrees).
  """

  alias SpaceDust.Utils.Constants
  alias SpaceDust.Math.Functions, as: Math
  alias SpaceDust.Math.Vector
  alias SpaceDust.Math.Vector.Vector3D
  alias SpaceDust.Bodies.Earth
  alias SpaceDust.Time.{UTC, TT, Transforms}

  # Sun's gravitational parameter (m^3/s^2)
  @mu_sun 1.32712440018e20

  # Astronomical Unit in meters
  @au_meters 149_597_870_700.0

  # Solar radius in meters
  @solar_radius 6.96e8

  # Mean longitude polynomial coefficients (degrees)
  # L0 = 280.4606184 + 36000.77005361 * T
  defp meanLongitudePoly do
    [36000.77005361, 280.4606184]
  end

  # Mean anomaly polynomial coefficients (degrees)
  # M = 357.5277233 + 35999.05034 * T
  defp meanAnomalyPoly do
    [35999.05034, 357.5277233]
  end

  # Obliquity of ecliptic polynomial coefficients (degrees)
  # ε = 23.439291 - 0.0130042 * T
  defp obliquityPoly do
    [-0.0130042, 23.439291]
  end

  @doc "Sun's gravitational parameter in m^3/s^2"
  def mu, do: @mu_sun

  @doc "Astronomical Unit in meters"
  def au, do: @au_meters

  @doc "Solar radius in meters"
  def radius, do: @solar_radius

  @doc """
  Calculate the Sun's position in the Earth-Centered Inertial J2000 (ECI) frame.

  Position is returned in meters.

  The underlying Almanac series is referred to the mean equinox *of date*, so
  the result is rotated into J2000 before it is returned. That matters: by 2026
  the two frames differ by about 0.36 degrees, which is thirty-six times this
  series' own accuracy, and `ECIState` is J2000. Use `mod_position/1` if you
  want the of-date vector.

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - Sun position in ECI J2000 frame (meters)

  ## Example
      iex> SpaceDust.Bodies.Sun.eci_position(~U[2024-01-01 12:00:00Z])
  """
  @spec eci_position(DateTime.t()) :: Vector.vector()
  def eci_position(epochUtc) do
    epochUtc
    |> mod_position()
    |> Earth.modToJ2000(epochUtc)
  end

  @doc """
  Calculate the Sun's position in the mean equinox of date (MOD) frame.

  This is what the low-precision Astronomical Almanac series produces natively,
  to roughly 0.01 degrees. Prefer `eci_position/1` for anything that has to line
  up with an `ECIState`.

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - Sun position in MOD frame (meters)
  """
  @spec mod_position(DateTime.t()) :: Vector.vector()
  def mod_position(epochUtc) do
    utc = UTC.from_datetime(epochUtc)
    tt = Transforms.utc_to_tt(utc)
    t_centuries = TT.julian_centuries_j2000(tt)

    # Mean longitude of the Sun (degrees)
    l0 = Math.polyEval(meanLongitudePoly(), t_centuries)

    # Mean anomaly of the Sun (degrees)
    m = Math.polyEval(meanAnomalyPoly(), t_centuries)
    m_rad = rem_degrees(m) * Constants.degreesToRadians()

    # Ecliptic longitude (degrees)
    # λ = L0 + 1.9146 * sin(M) + 0.0200 * sin(2M)
    lambda =
      l0 +
        1.9146 * :math.sin(m_rad) +
        0.0200 * :math.sin(2.0 * m_rad)

    lambda_rad = lambda * Constants.degreesToRadians()

    # Obliquity of the ecliptic (degrees)
    epsilon = Math.polyEval(obliquityPoly(), t_centuries)
    epsilon_rad = epsilon * Constants.degreesToRadians()

    # Distance from Earth to Sun in AU
    # r = 1.00014 - 0.01671 * cos(M) - 0.00014 * cos(2M)
    r_au =
      1.00014 -
        0.01671 * :math.cos(m_rad) -
        0.00014 * :math.cos(2.0 * m_rad)

    r_m = r_au * @au_meters

    # Geocentric equatorial coordinates, mean equinox of date
    cos_lambda = :math.cos(lambda_rad)
    sin_lambda = :math.sin(lambda_rad)
    cos_epsilon = :math.cos(epsilon_rad)
    sin_epsilon = :math.sin(epsilon_rad)

    %Vector3D{
      x: r_m * cos_lambda,
      y: r_m * sin_lambda * cos_epsilon,
      z: r_m * sin_lambda * sin_epsilon
    }
  end

  @doc """
  Calculate the Sun's position in ECI frame using a UTC struct.

  ## Parameters
    - `utc` - `%SpaceDust.Time.UTC{}` struct

  ## Returns
    - `%Vector3D{}` - Sun position in ECI frame (meters)
  """
  @spec eci_position_utc(UTC.t()) :: Vector.vector()
  def eci_position_utc(%UTC{} = utc) do
    eci_position(UTC.to_datetime(utc))
  end

  @doc """
  Calculate the Sun's apparent right ascension and declination.

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `{right_ascension, declination}` - tuple of angles in radians
  """
  @spec apparent_position(DateTime.t()) :: {float(), float()}
  def apparent_position(epochUtc) do
    pos = eci_position(epochUtc)
    r = Vector.magnitude(pos)

    # Declination
    dec = :math.asin(pos.z / r)

    # Right ascension
    ra = :math.atan2(pos.y, pos.x)
    ra_normalized = if ra < 0, do: ra + Constants.twopi(), else: ra

    {ra_normalized, dec}
  end

  @doc """
  Calculate the distance from Earth to the Sun in meters.

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - Distance in meters
  """
  @spec distance(DateTime.t()) :: float()
  def distance(epochUtc) do
    pos = eci_position(epochUtc)
    Vector.magnitude(pos)
  end

  @doc """
  Calculate the Sun's unit vector from Earth in ECI frame.

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - Unit vector pointing from Earth to Sun
  """
  @spec direction(DateTime.t()) :: Vector.vector()
  def direction(epochUtc) do
    pos = eci_position(epochUtc)
    Vector.normalize(pos)
  end

  # Helper to normalize degrees to 0-360 range
  defp rem_degrees(deg) do
    d = :math.fmod(deg, 360.0)
    if d < 0, do: d + 360.0, else: d
  end
end
