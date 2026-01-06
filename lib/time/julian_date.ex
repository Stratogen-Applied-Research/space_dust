defmodule SpaceDust.Time.JulianDate do
  @moduledoc """
  Julian Date (JD).

  The Julian Date is a continuous count of days since the beginning of the
  Julian Period on January 1, 4713 BC (proleptic Julian calendar) at noon
  Universal Time.

  Julian Date is widely used in astronomy because it provides a uniform time
  measure without the complexities of calendar systems.

  Common reference epochs:
  - J2000.0: JD 2451545.0 (2000-01-01 12:00:00 TT)
  - Unix epoch: JD 2440587.5 (1970-01-01 00:00:00 UTC)

  Modified Julian Date (MJD) = JD - 2400000.5
  """

  alias SpaceDust.Time.Epoch

  @enforce_keys [:jd]
  defstruct [:jd]

  @type t :: %__MODULE__{
          jd: float()
        }

  @doc """
  Create a Julian Date.
  """
  @spec new(float()) :: t()
  def new(jd) when is_number(jd) do
    %__MODULE__{jd: jd / 1}
  end

  @doc """
  Get the Julian Date value.
  """
  @spec to_days(t()) :: float()
  def to_days(%__MODULE__{jd: jd}), do: jd

  @doc """
  Create from Modified Julian Date.
  """
  @spec from_mjd(float()) :: t()
  def from_mjd(mjd) do
    new(mjd + 2_400_000.5)
  end

  @doc """
  Convert to Modified Julian Date.
  """
  @spec to_mjd(t()) :: float()
  def to_mjd(%__MODULE__{jd: jd}) do
    jd - 2_400_000.5
  end

  @doc """
  Calculate Julian centuries since J2000.0.
  """
  @spec julian_centuries_j2000(t()) :: float()
  def julian_centuries_j2000(%__MODULE__{jd: jd}) do
    (jd - Epoch.j2000_jd()) / 36525.0
  end

  @doc """
  Calculate Julian millennia since J2000.0.
  """
  @spec julian_millennia_j2000(t()) :: float()
  def julian_millennia_j2000(%__MODULE__{jd: jd}) do
    (jd - Epoch.j2000_jd()) / 365250.0
  end

  @doc """
  Get J2000.0 epoch as Julian Date.
  """
  @spec j2000() :: t()
  def j2000 do
    new(Epoch.j2000_jd())
  end

  @doc """
  Convert to Nx tensor.
  """
  @spec to_tensor(t()) :: Nx.Tensor.t()
  def to_tensor(%__MODULE__{jd: jd}) do
    Nx.tensor(jd, type: :f64)
  end

  @doc """
  Create from Nx tensor.
  """
  @spec from_tensor(Nx.Tensor.t()) :: t()
  def from_tensor(tensor) do
    new(Nx.to_number(tensor))
  end

  @doc """
  Add days to Julian Date.
  """
  @spec add_days(t(), number()) :: t()
  def add_days(%__MODULE__{jd: jd}, days) do
    new(jd + days)
  end

  @doc """
  Add seconds to Julian Date.
  """
  @spec add_seconds(t(), number()) :: t()
  def add_seconds(%__MODULE__{jd: jd}, seconds) do
    new(jd + seconds / Epoch.seconds_per_day())
  end

  @doc """
  Difference between two Julian Dates in days.
  """
  @spec diff_days(t(), t()) :: float()
  def diff_days(%__MODULE__{jd: jd1}, %__MODULE__{jd: jd2}) do
    jd1 - jd2
  end

  @doc """
  Difference between two Julian Dates in seconds.
  """
  @spec diff_seconds(t(), t()) :: float()
  def diff_seconds(%__MODULE__{jd: jd1}, %__MODULE__{jd: jd2}) do
    (jd1 - jd2) * Epoch.seconds_per_day()
  end

  @doc """
  Convert to fractional day of year and year.
  Returns {year, day_of_year} where day_of_year is 1-based and fractional.
  """
  @spec to_year_and_day(t()) :: {integer(), float()}
  def to_year_and_day(%__MODULE__{jd: jd}) do
    # Algorithm from Astronomical Algorithms by Jean Meeus
    z = trunc(jd + 0.5)
    f = jd + 0.5 - z

    a = if z < 2_299_161 do
      z
    else
      alpha = trunc((z - 1_867_216.25) / 36524.25)
      z + 1 + alpha - trunc(alpha / 4)
    end

    b = a + 1524
    c = trunc((b - 122.1) / 365.25)
    d = trunc(365.25 * c)
    e = trunc((b - d) / 30.6001)

    _day = b - d - trunc(30.6001 * e) + f

    month = if e < 14, do: e - 1, else: e - 13
    year = if month > 2, do: c - 4716, else: c - 4715

    # Calculate day of year
    jan1_jd = calculate_jd(year, 1, 1.0)
    day_of_year = jd - jan1_jd + 1

    {year, day_of_year}
  end

  # Helper to calculate JD from year, month, day
  defp calculate_jd(year, month, day) when month <= 2 do
    y = year - 1
    m = month + 12

    a = trunc(y / 100)
    b = 2 - a + trunc(a / 4)

    trunc(365.25 * (y + 4716)) + trunc(30.6001 * (m + 1)) + day + b - 1524.5
  end

  defp calculate_jd(year, month, day) do
    a = trunc(year / 100)
    b = 2 - a + trunc(a / 4)

    trunc(365.25 * (year + 4716)) + trunc(30.6001 * (month + 1)) + day + b - 1524.5
  end
end
