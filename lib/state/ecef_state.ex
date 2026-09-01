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
    # One implementation of this conversion, in GeodeticState. This module used
    # to carry a second copy with its own WGS84 constants, which is how the two
    # drifted: only one of them ever got the polar-altitude branch.
    SpaceDust.State.GeodeticState.ecef_to_geodetic(x, y, z)
  end
end
