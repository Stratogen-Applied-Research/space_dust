defmodule SpaceDust.Time.TAI do
  @moduledoc """
  International Atomic Time (TAI - Temps Atomique International).

  TAI is a continuous time scale based on atomic clocks. Unlike UTC, TAI does not
  include leap seconds, making it ideal for precise scientific calculations.

  TAI = UTC + leap_seconds

  Internally stores time as fractional seconds since a TAI reference epoch
  (equivalent to Unix epoch in TAI scale).
  """

  alias SpaceDust.Time.Epoch

  @enforce_keys [:tai_seconds]
  defstruct [:tai_seconds]

  @type t :: %__MODULE__{
          tai_seconds: float()
        }

  @doc """
  Create a TAI time from TAI seconds (since TAI epoch corresponding to Unix epoch).
  """
  @spec new(float()) :: t()
  def new(tai_seconds) when is_number(tai_seconds) do
    %__MODULE__{tai_seconds: tai_seconds / 1}
  end

  @doc """
  Get the TAI seconds value.
  """
  @spec to_seconds(t()) :: float()
  def to_seconds(%__MODULE__{tai_seconds: s}), do: s

  @doc """
  Convert to Nx tensor.
  """
  @spec to_tensor(t()) :: Nx.Tensor.t()
  def to_tensor(%__MODULE__{tai_seconds: s}) do
    Nx.tensor(s, type: :f64)
  end

  @doc """
  Create from Nx tensor.
  """
  @spec from_tensor(Nx.Tensor.t()) :: t()
  def from_tensor(tensor) do
    new(Nx.to_number(tensor))
  end

  @doc """
  Add seconds to TAI time.
  """
  @spec add(t(), number()) :: t()
  def add(%__MODULE__{tai_seconds: s}, seconds) do
    new(s + seconds)
  end

  @doc """
  Difference between two TAI times in seconds.
  """
  @spec diff(t(), t()) :: float()
  def diff(%__MODULE__{tai_seconds: s1}, %__MODULE__{tai_seconds: s2}) do
    s1 - s2
  end

  @doc """
  Convert TAI to Julian Date.
  Note: This is the Julian Date in the TAI time scale.
  """
  @spec to_jd(t()) :: float()
  def to_jd(%__MODULE__{tai_seconds: s}) do
    # TAI seconds to days, offset by Unix epoch JD
    s / Epoch.seconds_per_day() + Epoch.unix_epoch_jd()
  end

  @doc """
  Create TAI from Julian Date (in TAI scale).
  """
  @spec from_jd(float()) :: t()
  def from_jd(jd) do
    tai_seconds = (jd - Epoch.unix_epoch_jd()) * Epoch.seconds_per_day()
    new(tai_seconds)
  end
end
