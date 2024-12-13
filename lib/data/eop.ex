defmodule SpaceDust.Data.EarthOrientationParameters do
  @moduledoc """
  Parameters required to compute the CRS-TRS transformation matrix
  """
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
  """

  # this pulls the dEps, dPsi data from the IERS
  @eopDataUrl "https://datacenter.iers.org/data/latestVersion/EOP_20_C04_12h_dPsi_dEps_1984-now.txt"
  @eopDataPath "eop_data.txt"

  alias SpaceDust.Data.EarthOrientationParameters, as: EarthOrientationParameters

  @spec pullEOPData() :: {:error, String.t()} | {:ok, list()}
  @doc "pull EOP data from the IERS - realistically only needed once a year, or at container start"
  def pullEOPData() do
    response = Req.get!(@eopDataUrl)
    IO.inspect(response)

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

  @spec parseEopLine(String.t()) :: {:error, String.t()} | {:ok, EarthOrientationParameters.t()}
  def parseEopLine(line) do
    # line columns:
    # YR  MM  DD  HH       MJD        x(")        y(")  UT1-UTC(s)     dPsi(")     dEps(")      xrt(")      yrt(")      LOD(s)        x Er        y Er  UT1-UTC Er     dPsi Er     dEps Er      xrt Er      yrt Er      LOD Er
    # we want MJD, X, Y, UT1-UTC, dPsi, dEps, LOD

    try do
      # split the line into columns
      columns =
        String.split(line, " ")
        # remove empty columns
        |> Enum.reject(&(&1 == ""))

      # extract the columns we want
      mjd = String.to_float(Enum.at(columns, 4))
      x = String.to_float(Enum.at(columns, 5))
      y = String.to_float(Enum.at(columns, 6))
      ut1UTC = String.to_float(Enum.at(columns, 7))
      dPsi = String.to_float(Enum.at(columns, 8))
      dEps = String.to_float(Enum.at(columns, 9))
      lod = String.to_float(Enum.at(columns, 12))

      {:ok,
       %EarthOrientationParameters{
         modifiedJulianDate: mjd,
         polarMotionX: x,
         polarMotionY: y,
         ut1UTC: ut1UTC,
         dPsi: dPsi,
         dEps: dEps,
         lod: lod
       }}
    rescue
      ArgumentError -> {:error, "Unable to parse EOP line"}
    end
  end
end
