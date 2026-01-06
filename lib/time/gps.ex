defmodule SpaceDust.Time.GPS do
  @moduledoc """
  GPS Time.

  GPS Time is a continuous time scale used by the Global Positioning System.
  It started at midnight UTC on January 6, 1980 (the GPS epoch) and does not
  include leap seconds.

  GPS = TAI - 19 seconds

  At the GPS epoch, GPS time was synchronized with UTC. Since then, leap seconds
  have been added to UTC but not to GPS time, so they have diverged.

  GPS time is often expressed as a week number and seconds of week.

  Internally stores time as fractional seconds since GPS epoch.
  """

  @enforce_keys [:gps_seconds]
  defstruct [:gps_seconds]

  @type t :: %__MODULE__{
          gps_seconds: float()
        }

  # GPS epoch: 1980-01-06 00:00:00 UTC
  # In Unix seconds: 315964800
  @gps_epoch_unix 315_964_800

  # Seconds per GPS week
  @seconds_per_week 604_800

  @doc """
  Create a GPS time from GPS seconds (since GPS epoch).
  """
  @spec new(float()) :: t()
  def new(gps_seconds) when is_number(gps_seconds) do
    %__MODULE__{gps_seconds: gps_seconds / 1}
  end

  @doc """
  Get the GPS seconds value (since GPS epoch).
  """
  @spec to_seconds(t()) :: float()
  def to_seconds(%__MODULE__{gps_seconds: s}), do: s

  @doc """
  Create from GPS week number and seconds of week.
  """
  @spec from_week_and_seconds(integer(), float()) :: t()
  def from_week_and_seconds(week, seconds_of_week) do
    gps_seconds = week * @seconds_per_week + seconds_of_week
    new(gps_seconds)
  end

  @doc """
  Convert to GPS week number and seconds of week.
  Returns {week_number, seconds_of_week}.
  """
  @spec to_week_and_seconds(t()) :: {integer(), float()}
  def to_week_and_seconds(%__MODULE__{gps_seconds: s}) do
    week = trunc(s / @seconds_per_week)
    seconds_of_week = s - week * @seconds_per_week
    {week, seconds_of_week}
  end

  @doc """
  Get GPS week number.
  """
  @spec week_number(t()) :: integer()
  def week_number(%__MODULE__{gps_seconds: s}) do
    trunc(s / @seconds_per_week)
  end

  @doc """
  Get seconds of week (0 to 604800).
  """
  @spec seconds_of_week(t()) :: float()
  def seconds_of_week(%__MODULE__{gps_seconds: s}) do
    s - trunc(s / @seconds_per_week) * @seconds_per_week
  end

  @doc """
  Get day of week (0 = Sunday).
  """
  @spec day_of_week(t()) :: integer()
  def day_of_week(%__MODULE__{} = gps) do
    trunc(seconds_of_week(gps) / 86400)
  end

  @doc """
  Convert to Nx tensor (GPS seconds since epoch).
  """
  @spec to_tensor(t()) :: Nx.Tensor.t()
  def to_tensor(%__MODULE__{gps_seconds: s}) do
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
  Add seconds to GPS time.
  """
  @spec add(t(), number()) :: t()
  def add(%__MODULE__{gps_seconds: s}, seconds) do
    new(s + seconds)
  end

  @doc """
  Difference between two GPS times in seconds.
  """
  @spec diff(t(), t()) :: float()
  def diff(%__MODULE__{gps_seconds: s1}, %__MODULE__{gps_seconds: s2}) do
    s1 - s2
  end

  @doc """
  Get the GPS epoch in Unix seconds.
  """
  def gps_epoch_unix, do: @gps_epoch_unix

  @doc """
  Seconds per GPS week.
  """
  def seconds_per_week, do: @seconds_per_week
end
