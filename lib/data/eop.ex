defmodule SpaceDust.Data.EarthOrientationParameters do
  @moduledoc """
  Parameters required to compute the CRS-TRS transformation matrix
  """

  @type t :: %__MODULE__{
          modifiedJulianDate: float() | nil,
          polarMotionX: float() | nil,
          polarMotionY: float() | nil,
          ut1UTC: float() | nil,
          lod: float() | nil,
          dEps: float() | nil,
          dPsi: float() | nil
        }

  defstruct [
    :modifiedJulianDate,
    :polarMotionX,
    :polarMotionY,
    :ut1UTC,
    :lod,
    :dEps,
    :dPsi
  ]
end

defmodule SpaceDust.Data.EOP do
  @moduledoc """
  Earth Orientation Parameters (EOP) data - ref https://hpiers.obspm.fr/eoppc/bul/bulb/explanatory.html

  Uses the IERS finals.all data which includes both historical observations (marked 'I')
  and predictions up to ~1 year into the future (marked 'P').
  """

  # finals.all contains historical + predicted EOP data (predictions ~1 year ahead)
  @eopDataUrl "https://datacenter.iers.org/data/latestVersion/finals.all.iau2000.txt"
  rootPath = Path.expand("../..", __DIR__)
  @dataPath rootPath <> "/data"
  @eopDataPath @dataPath <> "/eop_data.txt"

  case File.exists?(@dataPath) do
    true -> IO.puts("Data directory exists")
    false -> File.mkdir(@dataPath)
  end

  require Logger
  alias SpaceDust.Data.EarthOrientationParameters, as: EarthOrientationParameters
  alias SpaceDust.Math.Functions, as: Functions

  @spec pullEOPData() :: {:error, String.t()} | {:ok, list()}
  @doc "pull EOP data from the IERS - realistically only needed once a year, or at container start"
  def pullEOPData() do
    response = Req.get!(@eopDataUrl)

    case response.status do
      200 ->
        # split the response body into lines
        lines =
          String.split(response.body, "\n")
          |> Enum.map(&String.trim/1)
          # remove empty lines
          |> Enum.reject(&(&1 == ""))
          # remove comment lines
          |> Enum.reject(&String.starts_with?(&1, "#"))

        {:ok, lines}

      _ ->
        {:error, "Failed to retrieve EOP data from IERS with status #{response.status}"}
    end
  end

  @spec saveEopData(any()) :: {:error, atom()}
  @doc "save EOP data to a file"
  def saveEopData(lines) do
    # TODO: make a data directory if it doesn't exist
    case File.write(@eopDataPath, Enum.join(lines, "\n")) do
      :ok -> {:ok, @eopDataPath}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec readSavedEopData() :: {:error, atom()} | {:ok, [binary()]}
  def readSavedEopData() do
    case File.read("eop_data.txt") do
      {:ok, data} ->
        {:ok, String.split(data, "\n")}

      {:error, :enoent} ->
        case pullEOPData() do
          {:ok, lines} ->
            saveEopData(lines)
            {:ok, lines}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def parseEopLine(line) do
    # finals.all format parsing
    # The date fields (year, month, day) at the start can vary in format,
    # but the MJD and subsequent fields are space-separated in a consistent pattern.
    #
    # Note: Sometimes the I/P flag is concatenated with negative values like "I-0.4575789"
    # We pre-process to add spaces before I/P flags to handle this.
    #
    # After MJD, the pattern is:
    #   [MJD] [flag] [PM-x] [PM-x err] [PM-y] [PM-y err] [flag] [UT1-UTC] [UT1-UTC err] [LOD] [LOD err] [flag] [dPSI] [dPSI err] [dEPS] [dEPS err] ...

    try do
      # Pre-process: Add space before I or P that's followed by a digit or minus sign
      # This handles cases like "I-0.4575789" -> "I -0.4575789"
      normalized_line = line
        |> String.replace(~r/([IP])(-?\d)/, "\\1 \\2")

      # Split by whitespace
      parts = String.split(normalized_line, ~r/\s+/, trim: true)

      # Find the MJD field (matches pattern like 41684.00 or 60681.00)
      # Must contain decimal point to distinguish from date fields like "41010"
      mjd_idx = Enum.find_index(parts, fn p ->
        String.contains?(p, ".") and
        case Float.parse(p) do
          {val, ""} -> val > 40000 and val < 70000  # MJD range: ~1970 to ~2050
          _ -> false
        end
      end)

      if mjd_idx == nil or length(parts) < mjd_idx + 9 do
        {:error, "Cannot find MJD or line too short"}
      else
        # Parse fields relative to MJD position
        mjd = parse_float(Enum.at(parts, mjd_idx))
        # Skip flag at mjd_idx + 1
        pm_x = parse_float(Enum.at(parts, mjd_idx + 2))
        # Skip PM-x error at mjd_idx + 3
        pm_y = parse_float(Enum.at(parts, mjd_idx + 4))
        # Skip PM-y error at mjd_idx + 5
        # Skip flag at mjd_idx + 6
        ut1_utc = parse_float(Enum.at(parts, mjd_idx + 7))
        # Skip UT1-UTC error at mjd_idx + 8

        # LOD is at mjd_idx + 9, but may be missing or be the nutation flag
        lod_raw = Enum.at(parts, mjd_idx + 9)
        {lod, next_offset} = case lod_raw do
          nil -> {0.0, 10}
          "I" -> {0.0, 9}   # This is actually the nutation flag
          "P" -> {0.0, 9}   # This is actually the nutation flag
          str ->
            case parse_float(str) do
              nil -> {0.0, 10}
              val -> {val / 1000.0, 11}  # Convert ms to s, skip LOD error
            end
        end

        # Find nutation values - look for next I/P flag after LOD
        nutation_flag_idx = mjd_idx + next_offset
        flag_val = Enum.at(parts, nutation_flag_idx)

        {dpsi, deps} = if flag_val in ["I", "P"] and length(parts) > nutation_flag_idx + 4 do
          dpsi_raw = parse_float(Enum.at(parts, nutation_flag_idx + 1))
          # Skip dPSI error at nutation_flag_idx + 2
          deps_raw = parse_float(Enum.at(parts, nutation_flag_idx + 3))

          dpsi = case dpsi_raw do
            nil -> 0.0
            val -> val / 1000.0  # Convert mas to arcsec
          end

          deps = case deps_raw do
            nil -> 0.0
            val -> val / 1000.0  # Convert mas to arcsec
          end

          {dpsi, deps}
        else
          {0.0, 0.0}
        end

        if mjd != nil and pm_x != nil and pm_y != nil and ut1_utc != nil do
          {:ok,
           %EarthOrientationParameters{
             modifiedJulianDate: mjd,
             polarMotionX: pm_x,
             polarMotionY: pm_y,
             ut1UTC: ut1_utc,
             dPsi: dpsi,
             dEps: deps,
             lod: lod
           }}
        else
          {:error, "Unable to parse required EOP fields"}
        end
      end
    rescue
      _ -> {:error, "Unable to parse EOP line"}
    end
  end

  # Helper to safely parse floats, returning nil for empty/invalid strings
  defp parse_float(""), do: nil
  defp parse_float(str) do
    case Float.parse(str) do
      {val, _} -> val
      :error -> nil
    end
  end

  @doc "parse an entire EOP data file"
  def parseEopData(lines) do
    eopData =
      lines
      |> Enum.map(&parseEopLine/1)
      |> Enum.filter(fn
        {:ok, _eop} -> true
        _ -> false
      end)
      |> Enum.map(fn {:ok, eop} -> eop end)

    # check if we have any EOP data
    case Enum.empty?(eopData) do
      true -> {:error, "No EOP data found"}
      false -> {:ok, eopData}
    end
  end

  @doc "interpolate between two EOP data points at a given MJD"
  def interpolateBetween(priorEop, futureEop, mjd) do
    # calculate the fraction of the time between the two EOP data points
    fraction =
      (mjd - priorEop.modifiedJulianDate) /
        (futureEop.modifiedJulianDate - priorEop.modifiedJulianDate)

    # interpolate the EOP data
    %EarthOrientationParameters{
      modifiedJulianDate: mjd,
      polarMotionX:
        Functions.linearInterpolate(priorEop.polarMotionX, futureEop.polarMotionX, fraction),
      polarMotionY:
        Functions.linearInterpolate(priorEop.polarMotionY, futureEop.polarMotionY, fraction),
      ut1UTC: Functions.linearInterpolate(priorEop.ut1UTC, futureEop.ut1UTC, fraction),
      dPsi: Functions.linearInterpolate(priorEop.dPsi, futureEop.dPsi, fraction),
      dEps: Functions.linearInterpolate(priorEop.dEps, futureEop.dEps, fraction),
      lod: Functions.linearInterpolate(priorEop.lod, futureEop.lod, fraction)
    }
  end

  @doc "get the EOP data at a given MJD, interpolating between the closest two data points"
  def getEopData(mjd) do
    case readSavedEopData() do
      {:ok, rawEopData} ->
        case parseEopData(rawEopData) do
          {:ok, eopData} ->
            # sort
            sortedData = Enum.sort_by(eopData, & &1.modifiedJulianDate)

            Enum.find(sortedData, fn eop -> eop.modifiedJulianDate >= mjd end)
            |> case do
              nil ->
                Logger.warning("MJD #{mjd} is after the last EOP data point")
                {:ok, Enum.at(sortedData, -1)}

              %EarthOrientationParameters{} = futureEop ->
                Enum.find(sortedData, fn eop -> eop.modifiedJulianDate < mjd end)
                |> case do
                  nil ->
                    Logger.warning("MJD #{mjd} is before the first EOP data point")
                    {:ok, Enum.at(sortedData, 0)}

                  %EarthOrientationParameters{} = priorEop ->
                    {:ok, interpolateBetween(priorEop, futureEop, mjd)}

                  _ ->
                    {:error, "Unable to find EOP data"}
                end

              _ ->
                {:error, "Unable to find EOP data"}
            end

          {:error, reason} ->
            Logger.error(reason)
            {:error, reason}
        end

      {:error, reason} ->
        IO.inspect(reason)
    end
  end
end
