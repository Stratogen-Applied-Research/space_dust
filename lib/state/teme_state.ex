defmodule SpaceDust.State.TEMEState do
  @moduledoc """
  State vector in True Equator Mean Equinox (TEME) reference frame.

  TEME is the reference frame used by SGP4/SDP4 propagators. Position and
  velocity are in kilometers and kilometers/second respectively.
  """

  @enforce_keys [:epoch, :position, :velocity]
  defstruct [:epoch, :position, :velocity]

  @type t :: %__MODULE__{
          epoch: DateTime.t(),
          position: {float(), float(), float()},
          velocity: {float(), float(), float()}
        }

  @doc """
  Create a new TEME state from position and velocity tuples.

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
  Create a TEME state from Nx tensors.
  """
  @spec from_tensors(DateTime.t(), Nx.Tensor.t(), Nx.Tensor.t()) :: t()
  def from_tensors(epoch, pos_tensor, vel_tensor) do
    [x, y, z] = Nx.to_flat_list(pos_tensor)
    [vx, vy, vz] = Nx.to_flat_list(vel_tensor)
    new(epoch, {x, y, z}, {vx, vy, vz})
  end
end
