defmodule SpaceDust.State.ECEFState do
  @moduledoc """
  State vector in Earth-Centered Earth-Fixed (ECEF) reference frame.

  ECEF is a rotating reference frame fixed to the Earth with:
  - Origin at Earth's center of mass
  - X-axis pointing toward the intersection of the prime meridian and equator
  - Z-axis pointing toward the North Pole
  - Y-axis completing the right-handed system (90° East longitude)

  Position and velocity are in kilometers and kilometers/second respectively.
  Note: Velocity in ECEF includes the Earth's rotation.
  """

  @enforce_keys [:epoch, :position, :velocity]
  defstruct [:epoch, :position, :velocity]

  @type t :: %__MODULE__{
          epoch: DateTime.t(),
          position: {float(), float(), float()},
          velocity: {float(), float(), float()}
        }

  @doc """
  Create a new ECEF state from position and velocity tuples.

  ## Parameters
    - epoch: UTC DateTime
    - position: {x, y, z} in kilometers
    - velocity: {vx, vy, vz} in km/s
  """
  @spec new(DateTime.t(), {float(), float(), float()}, {float(), float(), float()}) :: t()
  def new(epoch, {_x, _y, _z} = position, {_vx, _vy, _vz} = velocity) do
    %__MODULE__{
      epoch: epoch,
      position: position,
      velocity: velocity
    }
  end

  @doc """
  Convert position and velocity to Nx tensors for numerical operations.
  Returns {position_tensor, velocity_tensor} as 1D tensors of shape {3}.
  """
  @spec to_tensors(t()) :: {Nx.Tensor.t(), Nx.Tensor.t()}
  def to_tensors(%__MODULE__{position: {x, y, z}, velocity: {vx, vy, vz}}) do
    pos = Nx.tensor([x, y, z], type: :f64)
    vel = Nx.tensor([vx, vy, vz], type: :f64)
    {pos, vel}
  end

  @doc """
  Create an ECEF state from Nx tensors.
  """
  @spec from_tensors(DateTime.t(), Nx.Tensor.t(), Nx.Tensor.t()) :: t()
  def from_tensors(epoch, pos_tensor, vel_tensor) do
    [x, y, z] = Nx.to_flat_list(pos_tensor)
    [vx, vy, vz] = Nx.to_flat_list(vel_tensor)
    new(epoch, {x, y, z}, {vx, vy, vz})
  end

  @doc """
  Convert ECEF position to geodetic coordinates (latitude, longitude, altitude).
  Uses WGS84 ellipsoid parameters.

  Returns {latitude_deg, longitude_deg, altitude_km}
  """
  @spec to_geodetic(t()) :: {float(), float(), float()}
  def to_geodetic(%__MODULE__{position: {x, y, z}}) do
    # WGS84 parameters
    a = 6378.137  # Earth equatorial radius in km
    f = 1.0 / 298.257223563  # Flattening
    e2 = 2 * f - f * f  # First eccentricity squared

    lon = :math.atan2(y, x) * 180.0 / :math.pi()

    # Iterative calculation for latitude
    p = :math.sqrt(x * x + y * y)
    lat = :math.atan2(z, p * (1 - e2))

    # Iterate to convergence
    lat = iterate_latitude(lat, p, z, a, e2, 10)

    # Calculate altitude
    sin_lat = :math.sin(lat)
    n = a / :math.sqrt(1 - e2 * sin_lat * sin_lat)
    alt = p / :math.cos(lat) - n

    lat_deg = lat * 180.0 / :math.pi()

    {lat_deg, lon, alt}
  end

  defp iterate_latitude(lat, _p, _z, _a, _e2, 0), do: lat
  defp iterate_latitude(lat, p, z, a, e2, iterations) do
    sin_lat = :math.sin(lat)
    n = a / :math.sqrt(1 - e2 * sin_lat * sin_lat)
    new_lat = :math.atan2(z + e2 * n * sin_lat, p)

    if abs(new_lat - lat) < 1.0e-12 do
      new_lat
    else
      iterate_latitude(new_lat, p, z, a, e2, iterations - 1)
    end
  end
end
