defmodule SpaceDust.Time.TT do
  @moduledoc """
  Terrestrial Time (TT).

  TT is the modern astronomical time standard for geocentric ephemerides.
  It provides a uniform time scale for planetary and lunar ephemeris calculations.

  TT = TAI + 32.184 seconds

  The 32.184 second offset was chosen to maintain continuity with the older
  Ephemeris Time (ET) standard at the time of the transition.

  Internally stores time as fractional seconds since a TT reference epoch.
  """

  alias SpaceDust.Time.Epoch

  @enforce_keys [:tt_seconds]
  defstruct [:tt_seconds]

  @type t :: %__MODULE__{
          tt_seconds: float()
        }

  @doc """
  Create a TT time from TT seconds.
  """
  @spec new(float()) :: t()
  def new(tt_seconds) when is_number(tt_seconds) do
    %__MODULE__{tt_seconds: tt_seconds / 1}
  end

  @doc """
  Get the TT seconds value.
  """
  @spec to_seconds(t()) :: float()
  def to_seconds(%__MODULE__{tt_seconds: s}), do: s

  @doc """
  Convert to Nx tensor.
  """
  @spec to_tensor(t()) :: Nx.Tensor.t()
  def to_tensor(%__MODULE__{tt_seconds: s}) do
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
  Add seconds to TT time.
  """
  @spec add(t(), number()) :: t()
  def add(%__MODULE__{tt_seconds: s}, seconds) do
    new(s + seconds)
  end

  @doc """
  Difference between two TT times in seconds.
  """
  @spec diff(t(), t()) :: float()
  def diff(%__MODULE__{tt_seconds: s1}, %__MODULE__{tt_seconds: s2}) do
    s1 - s2
  end

  @doc """
  Convert TT to Julian Date.
  """
  @spec to_jd(t()) :: float()
  def to_jd(%__MODULE__{tt_seconds: s}) do
    s / Epoch.seconds_per_day() + Epoch.unix_epoch_jd()
  end

  @doc """
  Create TT from Julian Date (in TT scale).
  """
  @spec from_jd(float()) :: t()
  def from_jd(jd) do
    tt_seconds = (jd - Epoch.unix_epoch_jd()) * Epoch.seconds_per_day()
    new(tt_seconds)
  end

  @doc """
  Calculate Julian centuries since J2000.0 in TT.
  This is commonly used for precession/nutation calculations.
  """
  @spec julian_centuries_j2000(t()) :: float()
  def julian_centuries_j2000(%__MODULE__{} = tt) do
    jd = to_jd(tt)
    (jd - Epoch.j2000_jd()) / 36525.0
  end
end
