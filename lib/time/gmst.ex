defmodule SpaceDust.Time.GMST do
  @moduledoc """
  Greenwich Mean Sidereal Time (GMST).

  GMST is the hour angle of the mean vernal equinox measured from the Greenwich
  meridian. It represents the Earth's rotation angle and is essential for
  converting between Earth-fixed and inertial reference frames.

  GMST differs from Greenwich Apparent Sidereal Time (GAST) by the equation
  of the equinoxes (nutation in right ascension).

  Internally stores the GMST angle in radians.
  """

  @enforce_keys [:radians]
  defstruct [:radians]

  @type t :: %__MODULE__{
          radians: float()
        }

  @doc """
  Create a GMST from radians.
  """
  @spec new(float()) :: t()
  def new(radians) when is_number(radians) do
    %__MODULE__{radians: radians / 1}
  end

  @doc """
  Create from degrees.
  """
  @spec from_degrees(float()) :: t()
  def from_degrees(degrees) do
    new(degrees * :math.pi() / 180.0)
  end

  @doc """
  Create from hours.
  """
  @spec from_hours(float()) :: t()
  def from_hours(hours) do
    new(hours * :math.pi() / 12.0)
  end

  @doc """
  Get the GMST angle in radians.
  """
  @spec to_radians(t()) :: float()
  def to_radians(%__MODULE__{radians: r}), do: r

  @doc """
  Get the GMST angle in degrees.
  """
  @spec to_degrees(t()) :: float()
  def to_degrees(%__MODULE__{radians: r}) do
    r * 180.0 / :math.pi()
  end

  @doc """
  Get the GMST angle in hours.
  """
  @spec to_hours(t()) :: float()
  def to_hours(%__MODULE__{radians: r}) do
    r * 12.0 / :math.pi()
  end

  @doc """
  Normalize to range [0, 2π).
  """
  @spec normalize(t()) :: t()
  def normalize(%__MODULE__{radians: r}) do
    two_pi = 2.0 * :math.pi()
    normalized = :math.fmod(r, two_pi)
    new(if normalized < 0, do: normalized + two_pi, else: normalized)
  end

  @doc """
  Convert to Nx tensor (radians).
  """
  @spec to_tensor(t()) :: Nx.Tensor.t()
  def to_tensor(%__MODULE__{radians: r}) do
    Nx.tensor(r, type: :f64)
  end

  @doc """
  Create from Nx tensor.
  """
  @spec from_tensor(Nx.Tensor.t()) :: t()
  def from_tensor(tensor) do
    new(Nx.to_number(tensor))
  end
end
