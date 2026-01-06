defmodule SpaceDust.Observations.AzEl do
  @moduledoc """
  Azimuth and Elevation (Altitude) observation.

  Represents an angular observation in the local horizontal coordinate system:
  - Azimuth (Az): Angle measured clockwise from true North, in radians [0, 2π)
  - Elevation (El): Angle measured above the local horizon, in radians [-π/2, +π/2]
    Also called "altitude" in astronomical contexts.

  Optionally includes range (slant range) and range rate if available.
  """

  @enforce_keys [:epoch, :azimuth, :elevation]
  defstruct [
    :epoch,
    :azimuth,
    :elevation,
    :range,
    :range_rate,
    :azimuth_rate,
    :elevation_rate
  ]

  @type t :: %__MODULE__{
          epoch: DateTime.t(),
          azimuth: float(),
          elevation: float(),
          range: float() | nil,
          range_rate: float() | nil,
          azimuth_rate: float() | nil,
          elevation_rate: float() | nil
        }

  @doc """
  Create a new Az/El observation.

  ## Parameters
    - epoch: UTC DateTime of the observation
    - azimuth: Azimuth in radians [0, 2π), measured clockwise from North
    - elevation: Elevation in radians [-π/2, +π/2], measured above horizon
    - opts: Optional parameters
      - :range - Slant range in kilometers
      - :range_rate - Range rate in km/s
      - :azimuth_rate - Azimuth rate in rad/s
      - :elevation_rate - Elevation rate in rad/s

  ## Example
      iex> SpaceDust.Observations.AzEl.new(~U[2024-01-01 12:00:00Z], 1.5, 0.3)
  """
  @spec new(DateTime.t(), float(), float(), keyword()) :: t()
  def new(epoch, azimuth, elevation, opts \\ []) do
    %__MODULE__{
      epoch: epoch,
      azimuth: normalize_az(azimuth),
      elevation: elevation,
      range: Keyword.get(opts, :range),
      range_rate: Keyword.get(opts, :range_rate),
      azimuth_rate: Keyword.get(opts, :azimuth_rate),
      elevation_rate: Keyword.get(opts, :elevation_rate)
    }
  end

  @doc """
  Create Az/El from degrees instead of radians.
  """
  @spec from_degrees(DateTime.t(), float(), float(), keyword()) :: t()
  def from_degrees(epoch, az_deg, el_deg, opts \\ []) do
    az_rad = az_deg * :math.pi() / 180.0
    el_rad = el_deg * :math.pi() / 180.0
    new(epoch, az_rad, el_rad, opts)
  end

  @doc """
  Convert to degrees.
  Returns {az_degrees, el_degrees}.
  """
  @spec to_degrees(t()) :: {float(), float()}
  def to_degrees(%__MODULE__{azimuth: az, elevation: el}) do
    {az * 180.0 / :math.pi(), el * 180.0 / :math.pi()}
  end

  @doc """
  Check if the target is above the horizon.
  """
  @spec above_horizon?(t()) :: boolean()
  def above_horizon?(%__MODULE__{elevation: el}) do
    el > 0
  end

  @doc """
  Check if the target is above a minimum elevation.
  """
  @spec above_elevation?(t(), float()) :: boolean()
  def above_elevation?(%__MODULE__{elevation: el}, min_elevation_rad) do
    el >= min_elevation_rad
  end

  @doc """
  Get compass direction from azimuth.
  """
  @spec compass_direction(t()) :: String.t()
  def compass_direction(%__MODULE__{azimuth: az}) do
    az_deg = az * 180.0 / :math.pi()

    cond do
      az_deg < 22.5 or az_deg >= 337.5 -> "N"
      az_deg < 67.5 -> "NE"
      az_deg < 112.5 -> "E"
      az_deg < 157.5 -> "SE"
      az_deg < 202.5 -> "S"
      az_deg < 247.5 -> "SW"
      az_deg < 292.5 -> "W"
      true -> "NW"
    end
  end

  @doc """
  Get a formatted string representation.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = obs) do
    {az_deg, el_deg} = to_degrees(obs)
    dir = compass_direction(obs)
    "Az: #{Float.round(az_deg, 2)}° (#{dir}), El: #{Float.round(el_deg, 2)}°"
  end

  # Normalize azimuth to [0, 2π)
  defp normalize_az(az) do
    twopi = 2.0 * :math.pi()
    az = :math.fmod(az, twopi)
    if az < 0, do: az + twopi, else: az
  end
end
