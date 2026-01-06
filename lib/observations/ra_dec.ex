defmodule SpaceDust.Observations.RaDec do
  @moduledoc """
  Right Ascension and Declination observation.

  Represents an angular observation in the equatorial coordinate system:
  - Right Ascension (RA): Angle measured eastward along the celestial equator
    from the vernal equinox, in radians [0, 2π)
  - Declination (Dec): Angle measured north (+) or south (-) from the
    celestial equator, in radians [-π/2, +π/2]

  Optionally includes range (distance) and range rate if available.
  """

  @enforce_keys [:epoch, :right_ascension, :declination]
  defstruct [
    :epoch,
    :right_ascension,
    :declination,
    :range,
    :range_rate,
    :right_ascension_rate,
    :declination_rate
  ]

  @type t :: %__MODULE__{
          epoch: DateTime.t(),
          right_ascension: float(),
          declination: float(),
          range: float() | nil,
          range_rate: float() | nil,
          right_ascension_rate: float() | nil,
          declination_rate: float() | nil
        }

  @doc """
  Create a new RA/Dec observation.

  ## Parameters
    - epoch: UTC DateTime of the observation
    - right_ascension: Right ascension in radians [0, 2π)
    - declination: Declination in radians [-π/2, +π/2]
    - opts: Optional parameters
      - :range - Distance in kilometers
      - :range_rate - Range rate in km/s
      - :right_ascension_rate - RA rate in rad/s
      - :declination_rate - Dec rate in rad/s

  ## Example
      iex> SpaceDust.Observations.RaDec.new(~U[2024-01-01 12:00:00Z], 1.5, 0.3)
  """
  @spec new(DateTime.t(), float(), float(), keyword()) :: t()
  def new(epoch, right_ascension, declination, opts \\ []) do
    %__MODULE__{
      epoch: epoch,
      right_ascension: normalize_ra(right_ascension),
      declination: declination,
      range: Keyword.get(opts, :range),
      range_rate: Keyword.get(opts, :range_rate),
      right_ascension_rate: Keyword.get(opts, :right_ascension_rate),
      declination_rate: Keyword.get(opts, :declination_rate)
    }
  end

  @doc """
  Create RA/Dec from degrees instead of radians.
  """
  @spec from_degrees(DateTime.t(), float(), float(), keyword()) :: t()
  def from_degrees(epoch, ra_deg, dec_deg, opts \\ []) do
    ra_rad = ra_deg * :math.pi() / 180.0
    dec_rad = dec_deg * :math.pi() / 180.0
    new(epoch, ra_rad, dec_rad, opts)
  end

  @doc """
  Create RA/Dec from hours/minutes/seconds (RA) and degrees/arcmin/arcsec (Dec).
  """
  @spec from_hms_dms(DateTime.t(), {integer(), integer(), float()}, {integer(), integer(), float()}, keyword()) :: t()
  def from_hms_dms(epoch, {h, m, s}, {d, am, as}, opts \\ []) do
    # Convert RA from HMS to radians (1 hour = 15 degrees)
    ra_hours = h + m / 60.0 + s / 3600.0
    ra_rad = ra_hours * 15.0 * :math.pi() / 180.0

    # Convert Dec from DMS to radians
    sign = if d < 0, do: -1, else: 1
    dec_deg = abs(d) + am / 60.0 + as / 3600.0
    dec_rad = sign * dec_deg * :math.pi() / 180.0

    new(epoch, ra_rad, dec_rad, opts)
  end

  @doc """
  Convert to degrees.
  Returns {ra_degrees, dec_degrees}.
  """
  @spec to_degrees(t()) :: {float(), float()}
  def to_degrees(%__MODULE__{right_ascension: ra, declination: dec}) do
    {ra * 180.0 / :math.pi(), dec * 180.0 / :math.pi()}
  end

  @doc """
  Convert RA to hours/minutes/seconds string format.
  """
  @spec ra_to_hms(t()) :: String.t()
  def ra_to_hms(%__MODULE__{right_ascension: ra}) do
    # Convert radians to hours
    hours_total = ra * 12.0 / :math.pi()
    h = trunc(hours_total)
    m_total = (hours_total - h) * 60.0
    m = trunc(m_total)
    s = (m_total - m) * 60.0

    "#{h}h #{m}m #{Float.round(s, 2)}s"
  end

  @doc """
  Convert Dec to degrees/arcmin/arcsec string format.
  """
  @spec dec_to_dms(t()) :: String.t()
  def dec_to_dms(%__MODULE__{declination: dec}) do
    dec_deg = dec * 180.0 / :math.pi()
    sign = if dec_deg < 0, do: "-", else: "+"
    dec_deg = abs(dec_deg)
    d = trunc(dec_deg)
    m_total = (dec_deg - d) * 60.0
    m = trunc(m_total)
    s = (m_total - m) * 60.0

    "#{sign}#{d}° #{m}' #{Float.round(s, 2)}\""
  end

  @doc """
  Get a formatted string representation.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = obs) do
    "RA: #{ra_to_hms(obs)}, Dec: #{dec_to_dms(obs)}"
  end

  # Normalize RA to [0, 2π)
  defp normalize_ra(ra) do
    twopi = 2.0 * :math.pi()
    ra = :math.fmod(ra, twopi)
    if ra < 0, do: ra + twopi, else: ra
  end
end
