defmodule SpaceDust.Bodies.Barycenter do
  @moduledoc """
  Barycentric coordinate calculations for solar system bodies.

  Provides functions to compute positions relative to the solar system barycenter
  (SSB) and the Earth-Moon barycenter (EMB). Useful for sun-centric mission
  planning and high-precision orbital mechanics.

  ## Coordinate Systems

  - **Heliocentric** - Centered on the Sun
  - **Barycentric** - Centered on the solar system barycenter (SSB)
  - **Geocentric** - Centered on Earth (ECI)
  - **Earth-Moon Barycentric** - Centered on the Earth-Moon system barycenter (EMB)

  For most practical purposes in Earth orbit, the SSB and Sun center are
  effectively equivalent. The main difference is when computing positions of
  outer planets or for high-precision ephemeris work.
  """

  alias SpaceDust.Math.Vector
  alias SpaceDust.Math.Vector.Vector3D
  alias SpaceDust.Bodies.{Sun, Moon}

  # Mass ratios (dimensionless)
  # Earth/Moon mass ratio
  @earth_moon_ratio 81.30056

  # Sun/Earth mass ratio
  @sun_earth_ratio 332_946.0

  # Sun mass in kg
  @sun_mass 1.989e30

  # Earth mass in kg
  @earth_mass 5.972e24

  # Moon mass in kg
  @moon_mass 7.342e22

  @doc "Earth to Moon mass ratio"
  def earth_moon_mass_ratio, do: @earth_moon_ratio

  @doc "Sun to Earth mass ratio"
  def sun_earth_mass_ratio, do: @sun_earth_ratio

  @doc "Sun mass in kg"
  def sun_mass, do: @sun_mass

  @doc "Earth mass in kg"
  def earth_mass, do: @earth_mass

  @doc "Moon mass in kg"
  def moon_mass, do: @moon_mass

  @doc """
  Calculate the Earth-Moon barycenter position in ECI frame.

  The EMB is located along the line from Earth to Moon, at a distance
  proportional to the mass ratio.

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - EMB position in ECI frame (meters from Earth center)

  ## Example
      iex> SpaceDust.Bodies.Barycenter.earth_moon_barycenter(~U[2024-01-01 12:00:00Z])
  """
  @spec earth_moon_barycenter(DateTime.t()) :: Vector.vector()
  def earth_moon_barycenter(epochUtc) do
    moon_pos = Moon.eci_position(epochUtc)

    # EMB is at: r_emb = M_moon / (M_earth + M_moon) * r_moon
    # Using mass ratio: r_emb = r_moon / (1 + earth_moon_ratio)
    factor = 1.0 / (1.0 + @earth_moon_ratio)
    Vector.scale(moon_pos, factor)
  end

  @doc """
  Calculate Earth's position relative to the Earth-Moon barycenter.

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - Earth position in EMB frame (meters)
  """
  @spec earth_position_emb(DateTime.t()) :: Vector.vector()
  def earth_position_emb(epochUtc) do
    emb = earth_moon_barycenter(epochUtc)
    # Earth position from EMB is just the negative of EMB from Earth
    Vector.scale(emb, -1.0)
  end

  @doc """
  Calculate Moon's position relative to the Earth-Moon barycenter.

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - Moon position in EMB frame (meters)
  """
  @spec moon_position_emb(DateTime.t()) :: Vector.vector()
  def moon_position_emb(epochUtc) do
    moon_pos = Moon.eci_position(epochUtc)
    emb = earth_moon_barycenter(epochUtc)
    Vector.subtract(moon_pos, emb)
  end

  @doc """
  Calculate Earth's position in heliocentric coordinates.

  Earth's heliocentric position is the negative of the Sun's geocentric position.

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - Earth position in heliocentric frame (meters)

  ## Example
      iex> SpaceDust.Bodies.Barycenter.earth_heliocentric(~U[2024-01-01 12:00:00Z])
  """
  @spec earth_heliocentric(DateTime.t()) :: Vector.vector()
  def earth_heliocentric(epochUtc) do
    sun_pos = Sun.eci_position(epochUtc)
    # Earth's position from Sun is negative of Sun's position from Earth
    Vector.scale(sun_pos, -1.0)
  end

  @doc """
  Calculate Moon's position in heliocentric coordinates.

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - Moon position in heliocentric frame (meters)
  """
  @spec moon_heliocentric(DateTime.t()) :: Vector.vector()
  def moon_heliocentric(epochUtc) do
    moon_eci = Moon.eci_position(epochUtc)
    earth_helio = earth_heliocentric(epochUtc)
    Vector.add(earth_helio, moon_eci)
  end

  @doc """
  Calculate Earth-Moon barycenter position in heliocentric coordinates.

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - EMB position in heliocentric frame (meters)
  """
  @spec emb_heliocentric(DateTime.t()) :: Vector.vector()
  def emb_heliocentric(epochUtc) do
    emb_eci = earth_moon_barycenter(epochUtc)
    earth_helio = earth_heliocentric(epochUtc)
    Vector.add(earth_helio, emb_eci)
  end

  @doc """
  Convert an ECI position to heliocentric coordinates.

  ## Parameters
    - `eci_position` - Position vector in ECI frame (meters)
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - Position in heliocentric frame (meters)
  """
  @spec eci_to_heliocentric(Vector.vector(), DateTime.t()) :: Vector.vector()
  def eci_to_heliocentric(%Vector3D{} = eci_position, epochUtc) do
    earth_helio = earth_heliocentric(epochUtc)
    Vector.add(earth_helio, eci_position)
  end

  @doc """
  Convert a heliocentric position to ECI coordinates.

  ## Parameters
    - `helio_position` - Position vector in heliocentric frame (meters)
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - Position in ECI frame (meters)
  """
  @spec heliocentric_to_eci(Vector.vector(), DateTime.t()) :: Vector.vector()
  def heliocentric_to_eci(%Vector3D{} = helio_position, epochUtc) do
    sun_pos = Sun.eci_position(epochUtc)
    Vector.add(sun_pos, helio_position)
  end

  @doc """
  Calculate orbital elements of Earth around the Sun.

  Returns basic orbital parameters for Earth's heliocentric orbit
  at the given epoch.

  ## Parameters
    - `epochUtc` - DateTime in UTC

  ## Returns
    - Map with orbital elements:
      - `:semi_major_axis` - Semi-major axis in meters
      - `:distance` - Current distance from Sun in meters
      - `:true_anomaly` - True anomaly in radians
      - `:mean_anomaly` - Mean anomaly in radians (approximate)
  """
  @spec earth_orbital_elements(DateTime.t()) :: map()
  def earth_orbital_elements(epochUtc) do
    earth_pos = earth_heliocentric(epochUtc)
    r = Vector.magnitude(earth_pos)

    # Earth's orbit parameters (approximate)
    a = Sun.au()  # Semi-major axis ~1 AU
    e = 0.0167086  # Eccentricity

    # True anomaly from position (simplified, assumes circular for longitude)
    # In heliocentric coordinates, x points toward vernal equinox
    true_anomaly = :math.atan2(earth_pos.y, earth_pos.x)
    true_anomaly_norm =
      if true_anomaly < 0,
        do: true_anomaly + 2.0 * :math.pi(),
        else: true_anomaly

    # Eccentric anomaly from true anomaly
    tan_half_nu = :math.tan(true_anomaly_norm / 2.0)
    e_factor = :math.sqrt((1.0 - e) / (1.0 + e))
    eccentric_anomaly = 2.0 * :math.atan(e_factor * tan_half_nu)

    # Mean anomaly from eccentric anomaly
    mean_anomaly = eccentric_anomaly - e * :math.sin(eccentric_anomaly)

    %{
      semi_major_axis: a,
      eccentricity: e,
      distance: r,
      true_anomaly: true_anomaly_norm,
      eccentric_anomaly: eccentric_anomaly,
      mean_anomaly: mean_anomaly
    }
  end

  @doc """
  Calculate the distance between two bodies at a given time.

  ## Parameters
    - `body1` - Atom identifying first body (:sun, :earth, :moon)
    - `body2` - Atom identifying second body (:sun, :earth, :moon)
    - `epochUtc` - DateTime in UTC

  ## Returns
    - Distance in meters

  ## Example
      iex> SpaceDust.Bodies.Barycenter.distance_between(:earth, :moon, ~U[2024-01-01 12:00:00Z])
  """
  @spec distance_between(atom(), atom(), DateTime.t()) :: float()
  def distance_between(body1, body2, epochUtc) do
    pos1 = body_heliocentric_position(body1, epochUtc)
    pos2 = body_heliocentric_position(body2, epochUtc)
    diff = Vector.subtract(pos1, pos2)
    Vector.magnitude(diff)
  end

  @doc """
  Get the heliocentric position of a named body.

  ## Parameters
    - `body` - Atom identifying the body (:sun, :earth, :moon, :emb)
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - Position in heliocentric frame (meters)
  """
  @spec body_heliocentric_position(atom(), DateTime.t()) :: Vector.vector()
  def body_heliocentric_position(body, epochUtc) do
    case body do
      :sun -> %Vector3D{x: 0.0, y: 0.0, z: 0.0}
      :earth -> earth_heliocentric(epochUtc)
      :moon -> moon_heliocentric(epochUtc)
      :emb -> emb_heliocentric(epochUtc)
      _ -> raise ArgumentError, "Unknown body: #{body}"
    end
  end

  @doc """
  Get the ECI position of a named body.

  ## Parameters
    - `body` - Atom identifying the body (:sun, :earth, :moon, :emb)
    - `epochUtc` - DateTime in UTC

  ## Returns
    - `%Vector3D{}` - Position in ECI frame (meters)
  """
  @spec body_eci_position(atom(), DateTime.t()) :: Vector.vector()
  def body_eci_position(body, epochUtc) do
    case body do
      :sun -> Sun.eci_position(epochUtc)
      :earth -> %Vector3D{x: 0.0, y: 0.0, z: 0.0}
      :moon -> Moon.eci_position(epochUtc)
      :emb -> earth_moon_barycenter(epochUtc)
      _ -> raise ArgumentError, "Unknown body: #{body}"
    end
  end
end
