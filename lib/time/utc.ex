defmodule SpaceDust.Time.UTC do
  @moduledoc """
  Coordinated Universal Time (UTC).

  UTC is the primary civil time standard. It is kept within 0.9 seconds of UT1
  (astronomical time based on Earth's rotation) by the insertion of leap seconds.

  Internally stores time as fractional seconds since Unix epoch (1970-01-01 00:00:00 UTC).
  """

  alias SpaceDust.Time.Epoch

  @enforce_keys [:unix_seconds]
  defstruct [:unix_seconds]

  @type t :: %__MODULE__{
          unix_seconds: float()
        }

  @doc """
  Create a UTC time from Unix seconds.
  """
  @spec new(float()) :: t()
  def new(unix_seconds) when is_number(unix_seconds) do
    %__MODULE__{unix_seconds: unix_seconds / 1}
  end

  @doc """
  Create a UTC time from an Elixir DateTime.
  """
  @spec from_datetime(DateTime.t()) :: t()
  def from_datetime(%DateTime{} = dt) do
    unix_seconds = DateTime.to_unix(dt, :microsecond) / 1_000_000
    new(unix_seconds)
  end

  @doc """
  Convert to an Elixir DateTime.
  """
  @spec to_datetime(t()) :: DateTime.t()
  def to_datetime(%__MODULE__{unix_seconds: unix_seconds}) do
    seconds = trunc(unix_seconds)
    microseconds = trunc((unix_seconds - seconds) * 1_000_000)
    {:ok, dt} = DateTime.from_unix(seconds, :second)
    DateTime.add(dt, microseconds, :microsecond)
  end

  @doc """
  Create a UTC time from a sigil-style DateTime.

  ## Example
      iex> SpaceDust.Time.UTC.from_iso8601!("2024-01-01T12:00:00Z")
  """
  @spec from_iso8601!(String.t()) :: t()
  def from_iso8601!(iso_string) do
    {:ok, dt, _} = DateTime.from_iso8601(iso_string)
    from_datetime(dt)
  end

  @doc """
  Get the Unix seconds value.
  """
  @spec to_unix(t()) :: float()
  def to_unix(%__MODULE__{unix_seconds: s}), do: s

  @doc """
  Create from year, month, day, hour, minute, second.
  """
  @spec from_components(integer(), integer(), integer(), integer(), integer(), number()) :: t()
  def from_components(year, month, day, hour, minute, second) do
    whole_second = trunc(second)
    microsecond = trunc((second - whole_second) * 1_000_000)

    {:ok, dt} = DateTime.new(
      Date.new!(year, month, day),
      Time.new!(hour, minute, whole_second, {microsecond, 6})
    )
    from_datetime(dt)
  end

  @doc """
  Convert to Julian Date.
  """
  @spec to_jd(t()) :: float()
  def to_jd(%__MODULE__{unix_seconds: s}) do
    s / Epoch.seconds_per_day() + Epoch.unix_epoch_jd()
  end

  @doc """
  Create from Julian Date.
  """
  @spec from_jd(float()) :: t()
  def from_jd(jd) do
    unix_seconds = (jd - Epoch.unix_epoch_jd()) * Epoch.seconds_per_day()
    new(unix_seconds)
  end

  @doc """
  Convert to Modified Julian Date.
  """
  @spec to_mjd(t()) :: float()
  def to_mjd(%__MODULE__{} = utc) do
    to_jd(utc) - 2_400_000.5
  end

  @doc """
  Create from Modified Julian Date.
  """
  @spec from_mjd(float()) :: t()
  def from_mjd(mjd) do
    from_jd(mjd + 2_400_000.5)
  end

  @doc """
  Convert to Nx tensor (unix seconds).
  """
  @spec to_tensor(t()) :: Nx.Tensor.t()
  def to_tensor(%__MODULE__{unix_seconds: s}) do
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
  Add seconds to UTC time.
  """
  @spec add(t(), number()) :: t()
  def add(%__MODULE__{unix_seconds: s}, seconds) do
    new(s + seconds)
  end

  @doc """
  Difference between two UTC times in seconds.
  """
  @spec diff(t(), t()) :: float()
  def diff(%__MODULE__{unix_seconds: s1}, %__MODULE__{unix_seconds: s2}) do
    s1 - s2
  end
end
