defmodule SpaceDust.State.GeodeticState do
  @moduledoc """
  State in geodetic coordinates (latitude, longitude, altitude).

  Uses WGS84 ellipsoid for Earth reference. This is the standard
  representation for ground-based observer locations.

  - Latitude: Geodetic latitude in degrees (-90 to +90, positive North)
  - Longitude: Geodetic longitude in degrees (-180 to +180, positive East)
  - Altitude: Height above WGS84 ellipsoid in kilometers
  """

  alias SpaceDust.State.ECEFState

  @enforce_keys [:latitude, :longitude, :altitude]
  defstruct [:latitude, :longitude, :altitude]

  # WGS84 parameters
  @earth_radius_eq 6378.137  # Equatorial radius in km
  @earth_flattening 1.0 / 298.257223563
  @earth_e2 2 * @earth_flattening - @earth_flattening * @earth_flattening  # First eccentricity squared

  @type t :: %__MODULE__{
          latitude: float(),
          longitude: float(),
          altitude: float()
        }

  @doc """
  Create a new geodetic state.

  ## Parameters
    - latitude: Geodetic latitude in degrees (-90 to +90)
    - longitude: Geodetic longitude in degrees (-180 to +180)
    - altitude: Height above WGS84 ellipsoid in kilometers

  ## Example
      iex> SpaceDust.State.GeodeticState.new(40.0, -105.0, 1.6)
  """
  @spec new(float(), float(), float()) :: t()
  def new(latitude, longitude, altitude) do
    %__MODULE__{
      latitude: latitude,
      longitude: longitude,
      altitude: altitude
    }
  end

  @doc """
  Convert geodetic coordinates to ECEF position.

  Returns an ECEF position vector {x, y, z} in kilometers.
  Velocity is set to zero (stationary observer).
  """
  @spec to_ecef(t(), DateTime.t()) :: ECEFState.t()
  def to_ecef(%__MODULE__{latitude: lat, longitude: lon, altitude: alt}, epoch) do
    lat_rad = lat * :math.pi() / 180.0
    lon_rad = lon * :math.pi() / 180.0

    sin_lat = :math.sin(lat_rad)
    cos_lat = :math.cos(lat_rad)
    sin_lon = :math.sin(lon_rad)
    cos_lon = :math.cos(lon_rad)

    # Radius of curvature in the prime vertical
    n = @earth_radius_eq / :math.sqrt(1 - @earth_e2 * sin_lat * sin_lat)

    # ECEF position
    x = (n + alt) * cos_lat * cos_lon
    y = (n + alt) * cos_lat * sin_lon
    z = (n * (1 - @earth_e2) + alt) * sin_lat

    # Stationary observer - velocity is zero in ECEF
    ECEFState.new(epoch, {x, y, z}, {0.0, 0.0, 0.0})
  end

  @doc """
  Convert geodetic state to ECI position at a given epoch.
  """
  @spec to_eci(t(), DateTime.t()) :: SpaceDust.State.ECIState.t()
  def to_eci(%__MODULE__{} = geodetic, epoch) do
    ecef = to_ecef(geodetic, epoch)
    SpaceDust.State.Transforms.ecef_to_eci(ecef)
  end

  @doc """
  Create geodetic state from an ECEF state.
  Uses iterative algorithm for accurate conversion.
  """
  @spec from_ecef(ECEFState.t()) :: t()
  def from_ecef(%ECEFState{position: {x, y, z}}) do
    {lat_deg, lon_deg, alt_km} = ecef_to_geodetic(x, y, z)
    new(lat_deg, lon_deg, alt_km)
  end

  # Internal ECEF to geodetic conversion
  defp ecef_to_geodetic(x, y, z) do
    lon = :math.atan2(y, x) * 180.0 / :math.pi()

    # Iterative calculation for latitude
    p = :math.sqrt(x * x + y * y)
    lat = :math.atan2(z, p * (1 - @earth_e2))

    # Iterate to convergence
    lat = iterate_latitude(lat, p, z, 10)

    # Calculate altitude
    sin_lat = :math.sin(lat)
    n = @earth_radius_eq / :math.sqrt(1 - @earth_e2 * sin_lat * sin_lat)
    alt = p / :math.cos(lat) - n

    lat_deg = lat * 180.0 / :math.pi()

    {lat_deg, lon, alt}
  end

  defp iterate_latitude(lat, _p, _z, 0), do: lat
  defp iterate_latitude(lat, p, z, iterations) do
    sin_lat = :math.sin(lat)
    n = @earth_radius_eq / :math.sqrt(1 - @earth_e2 * sin_lat * sin_lat)
    new_lat = :math.atan2(z + @earth_e2 * n * sin_lat, p)

    if abs(new_lat - lat) < 1.0e-12 do
      new_lat
    else
      iterate_latitude(new_lat, p, z, iterations - 1)
    end
  end

  @doc """
  Get the local sidereal time at the observer's location.
  Returns LST in radians.
  """
  @spec local_sidereal_time(t(), DateTime.t()) :: float()
  def local_sidereal_time(%__MODULE__{longitude: lon}, epoch) do
    nutation = SpaceDust.Bodies.Earth.nutationAngles(epoch)
    gast = nutation.gast
    lon_rad = lon * :math.pi() / 180.0

    # Local sidereal time = GAST + observer longitude
    lst = gast + lon_rad

    # Normalize to [0, 2π]
    twopi = 2.0 * :math.pi()
    lst = :math.fmod(lst, twopi)
    if lst < 0, do: lst + twopi, else: lst
  end
end
