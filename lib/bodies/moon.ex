defmodule SpaceDust.Bodies.Moon do
  @moduledoc """
  Lunar body parameters and position calculations.

  Provides functions to compute the Moon's position in various coordinate frames,
  including ECI (Earth-Centered Inertial).

  The algorithms are based on the low-precision lunar coordinates from the
  Astronomical Almanac (approximate accuracy ~0.3 degrees in longitude,
  ~0.2 degrees in latitude, ~0.003 Earth radii in distance).
  """

  alias SpaceDust.Utils.Constants
  alias SpaceDust.Math.Functions, as: Math
  alias SpaceDust.Math.Vector
  alias SpaceDust.Math.Vector.Vector3D
  alias SpaceDust.Time.{UTC, TT, Transforms}

  # Moon's gravitational parameter (m^3/s^2)
  @mu_moon 4.902800066e12

  # Mean lunar distance in meters (semi-major axis)
  @mean_distance 384_400_000.0

  # Lunar radius in meters
  @lunar_radius 1_737_400.0

  # Earth radius in meters (for distance calculation)
  @earth_radius 6_378_137.0

  # Polynomial coefficients for lunar position (degrees)
  # Mean longitude of Moon
  defp meanLongitudePoly do
    [
      -1.52e-6,
      1.0 / 538841.0,
      -0.0015786,
      481267.88123421,
      218.3164477
    ]
  end

  # Mean elongation of Moon from Sun
  defp meanElongationPoly do
    [
      -8.78e-6,
      -1.0 / 113065.0,
      0.0018819,
      445267.1114034,
      297.8501921
    ]
  end

  # Sun's mean anomaly
  defp sunMeanAnomalyPoly do
    [
      1.59e-5,
      -1.0 / 24490000.0,
      -0.0001536,
      35999.0502909,
      357.5291092
    ]
  end

  # Moon's mean anomaly
  defp moonMeanAnomalyPoly do
    [
      3.239e-5,
      -1.0 / 69699.0,
      0.0087414,
      477198.8675055,
      134.9633964
    ]
  end

  # Moon's argument of latitude
  defp argumentOfLatitudePoly do
    [
      3.17e-6,
      -1.0 / 3526000.0,
      -0.0036539,
      483202.0175233,
      93.2720950
    ]
  end

  # Longitude of ascending node (not used in current algorithm, kept for reference)
  # defp ascendingNodePoly do
  #   [
  #     -5.0e-7,
  #     1.0 / 450000.0,
  #     0.0020754,
  #     -1934.1362091,
  #     125.0445479
  #   ]
  # end

  # Obliquity of ecliptic polynomial coefficients (degrees)
  defp obliquityPoly do
    [-0.0130042, 23.439291]
  end

  @doc "Moon's gravitational parameter in m^3/s^2"
  def mu, do: @mu_moon

  @doc "Mean Earth-Moon distance in meters"
  def mean_distance, do: @mean_distance

  @doc "Lunar radius in meters"
  def radius, do: @lunar_radius

  @doc """
  Calculate the Moon's position in the Earth-Centered Inertial (ECI) frame.

  Uses the low-precision lunar coordinates from the Astronomical Almanac.
  Position is returned in meters.

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - Moon position in ECI frame (meters)

  ## Example
      iex> SpaceDust.Bodies.Moon.eci_position(~U[2024-01-01 12:00:00Z])
  """
  @spec eci_position(DateTime.t()) :: Vector.vector()
  def eci_position(epochUtc) do
    utc = UTC.from_datetime(epochUtc)
    tt = Transforms.utc_to_tt(utc)
    t = TT.julian_centuries_j2000(tt)

    # Compute fundamental arguments (in degrees)
    # Polynomials are defined [T^4, T^3, T^2, T^1, T^0] which is correct for polyEval
    l_prime = Math.polyEval(meanLongitudePoly(), t)
    d = Math.polyEval(meanElongationPoly(), t)
    m = Math.polyEval(sunMeanAnomalyPoly(), t)
    m_prime = Math.polyEval(moonMeanAnomalyPoly(), t)
    f = Math.polyEval(argumentOfLatitudePoly(), t)

    # Convert to radians and normalize
    d_rad = rem_degrees(d) * Constants.degreesToRadians()
    m_rad = rem_degrees(m) * Constants.degreesToRadians()
    m_prime_rad = rem_degrees(m_prime) * Constants.degreesToRadians()
    f_rad = rem_degrees(f) * Constants.degreesToRadians()

    # Longitude corrections (degrees)
    # Major terms from Meeus/Astronomical Almanac
    delta_lambda =
      6.288774 * :math.sin(m_prime_rad) +
        1.274027 * :math.sin(2.0 * d_rad - m_prime_rad) +
        0.658314 * :math.sin(2.0 * d_rad) +
        0.213618 * :math.sin(2.0 * m_prime_rad) -
        0.185116 * :math.sin(m_rad) -
        0.114332 * :math.sin(2.0 * f_rad) +
        0.058793 * :math.sin(2.0 * (d_rad - m_prime_rad)) +
        0.057066 * :math.sin(2.0 * d_rad - m_rad - m_prime_rad) +
        0.053322 * :math.sin(2.0 * d_rad + m_prime_rad) +
        0.045758 * :math.sin(2.0 * d_rad - m_rad) -
        0.040923 * :math.sin(m_rad - m_prime_rad) -
        0.034720 * :math.sin(d_rad) -
        0.030383 * :math.sin(m_rad + m_prime_rad) +
        0.015327 * :math.sin(2.0 * (d_rad - f_rad)) -
        0.012528 * :math.sin(m_prime_rad + 2.0 * f_rad) +
        0.010980 * :math.sin(m_prime_rad - 2.0 * f_rad)

    # Ecliptic longitude
    lambda = l_prime + delta_lambda
    lambda_rad = lambda * Constants.degreesToRadians()

    # Latitude corrections (degrees)
    delta_beta =
      5.128122 * :math.sin(f_rad) +
        0.280602 * :math.sin(m_prime_rad + f_rad) +
        0.277693 * :math.sin(m_prime_rad - f_rad) +
        0.173237 * :math.sin(2.0 * d_rad - f_rad) +
        0.055413 * :math.sin(2.0 * d_rad - m_prime_rad + f_rad) +
        0.046271 * :math.sin(2.0 * d_rad - m_prime_rad - f_rad) +
        0.032573 * :math.sin(2.0 * d_rad + f_rad) +
        0.017198 * :math.sin(2.0 * m_prime_rad + f_rad) +
        0.009266 * :math.sin(2.0 * d_rad + m_prime_rad - f_rad)

    beta_rad = delta_beta * Constants.degreesToRadians()

    # Distance, from the horizontal parallax series (Montenbruck & Gill,
    # "Satellite Orbits", Appendix C), in arcseconds. The Earth's equatorial
    # radius subtends this angle at the Moon, so r = R_earth / sin(parallax).
    #
    # Going through the parallax rather than a series in Earth radii is what
    # gets the amplitude right: the leading term is 186.54" against a 3422.7"
    # mean, which is 3.28 Earth radii of variation - the Moon really does swing
    # between about 356 500 km and 406 700 km over an anomalistic month.
    parallax_arcsec =
      3422.7 +
        186.5398 * :math.cos(m_prime_rad) +
        34.3117 * :math.cos(2.0 * d_rad - m_prime_rad) +
        28.2333 * :math.cos(2.0 * d_rad) +
        10.1657 * :math.cos(2.0 * m_prime_rad) +
        3.0861 * :math.cos(2.0 * d_rad + m_prime_rad) -
        1.9178 * :math.cos(2.0 * d_rad - m_rad)

    r_m = @earth_radius / :math.sin(parallax_arcsec * Constants.arcsecToRadians())

    # Obliquity of the ecliptic
    epsilon = Math.polyEval(obliquityPoly(), t)
    epsilon_rad = epsilon * Constants.degreesToRadians()

    # Convert ecliptic to equatorial (ECI)
    cos_lambda = :math.cos(lambda_rad)
    sin_lambda = :math.sin(lambda_rad)
    cos_beta = :math.cos(beta_rad)
    sin_beta = :math.sin(beta_rad)
    cos_epsilon = :math.cos(epsilon_rad)
    sin_epsilon = :math.sin(epsilon_rad)

    # Position in ecliptic coordinates
    x_ecl = r_m * cos_beta * cos_lambda
    y_ecl = r_m * cos_beta * sin_lambda
    z_ecl = r_m * sin_beta

    # Rotate to equatorial (ECI) frame
    x = x_ecl
    y = y_ecl * cos_epsilon - z_ecl * sin_epsilon
    z = y_ecl * sin_epsilon + z_ecl * cos_epsilon

    %Vector3D{x: x, y: y, z: z}
  end

  @doc """
  Calculate the Moon's position in ECI frame using a UTC struct.

  ## Parameters
    - `utc` - `%SpaceDust.Time.UTC{}` struct

  ## Returns
    - `%Vector3D{}` - Moon position in ECI frame (meters)
  """
  @spec eci_position_utc(UTC.t()) :: Vector.vector()
  def eci_position_utc(%UTC{} = utc) do
    eci_position(UTC.to_datetime(utc))
  end

  @doc """
  Calculate the Moon's apparent right ascension and declination.

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
  Calculate the distance from Earth to the Moon in meters.

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
  Calculate the Moon's unit vector from Earth in ECI frame.

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - Unit vector pointing from Earth to Moon
  """
  @spec direction(DateTime.t()) :: Vector.vector()
  def direction(epochUtc) do
    pos = eci_position(epochUtc)
    Vector.normalize(pos)
  end

  @doc """
  Calculate the Moon's phase angle (angle between Sun and Moon as seen from Earth).

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - Phase angle in radians (0 = new moon, π = full moon)
  """
  @spec phase_angle(DateTime.t()) :: float()
  def phase_angle(epochUtc) do
    moon_dir = direction(epochUtc)
    sun_dir = SpaceDust.Bodies.Sun.direction(epochUtc)

    # Phase angle is the angle between the sun and moon vectors
    cos_angle = Vector.dot(moon_dir, sun_dir)
    :math.acos(cos_angle)
  end

  # Helper to normalize degrees to 0-360 range
  defp rem_degrees(deg) do
    d = :math.fmod(deg, 360.0)
    if d < 0, do: d + 360.0, else: d
  end
end
