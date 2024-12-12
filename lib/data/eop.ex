defmodule SpaceDust.Data.IersEopData do
  @moduledoc """
  IERS Earth Orientation Parameters (EOP) data
  """
  defstruct [
    :year,
    :month,
    :day,
    :modifiedJulianDate,
    :pmX,
    :errorPMX,
    :pmY,
    :errorPMY,
    :ut1UTC,
    :errorUT1UTC,
    :lod,
    :errorLOD,
    :dX,
    :errorDX,
    :dY,
    :errorDY
  ]
end

defmodule SpaceDust.Data.EarthOrientationParameters do
  @moduledoc """
  Parameters required to compute the CRS-TRS transformation matrix
  """
  defstruct [
    :pmX,
    :pmY,
    :ut1UTC,
    :lod,
    :dX,
    :dY
  ]
end

defmodule SpaceDust.Data.EOP do
  @moduledoc """
  Earth Orientation Parameters (EOP) data - ref https://hpiers.obspm.fr/eoppc/bul/bulb/explanatory.html
  """

  @eopDataUrl "https://datacenter.iers.org/data/9/finals2000A.all"

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

        {:ok, lines}

      _ ->
        {:error, "Failed to retrieve EOP data from IERS with status #{response.status}"}
    end
  end

  @doc "parse a line of EOP data from the IERS"
  def parseEOPLine(line) do
    # split the line into its components (space-delimited)
    # lines are arranged as follows: Year, Month, Day, Modified Julian Date, PM-x [arcsec], error_PM-x [arcsec] PM-y [arcsec], error_PM-y [arcsec], UT1-UTC [seconds], error_UT1-UTC [seconds], LOD [milliseconds], error_LOD [milliseconds], dX [milliarcsec], error_dX [milliarcsec], dY [milliarcsec], error_dY [milliarcsec]
    components = String.split(line, " ")
    yearLastTwoDigits = String.to_integer(Enum.at(components, 0))

    year =
      if yearLastTwoDigits > Date.utc_today().year - 2000 do
        1900 + yearLastTwoDigits
      else
        2000 + yearLastTwoDigits
      end

    month = String.to_integer(Enum.at(components, 1))
    day = String.to_integer(Enum.at(components, 2))
    modifiedJulianDate = String.to_float(Enum.at(components, 3))
    pmX = String.to_float(Enum.at(components, 4))
    errorPMX = String.to_float(Enum.at(components, 5))
    pmY = String.to_float(Enum.at(components, 6))
    errorPMY = String.to_float(Enum.at(components, 7))
    ut1UTC = String.to_float(Enum.at(components, 8))
    errorUT1UTC = String.to_float(Enum.at(components, 9))
    lod = String.to_float(Enum.at(components, 10))
    errorLOD = String.to_float(Enum.at(components, 11))
    dX = String.to_float(Enum.at(components, 12))
    errorDX = String.to_float(Enum.at(components, 13))
    dY = String.to_float(Enum.at(components, 14))
    errorDY = String.to_float(Enum.at(components, 15))

    %SpaceDust.Data.IersEopData{
      year: year,
      month: month,
      day: day,
      modifiedJulianDate: modifiedJulianDate,
      pmX: pmX,
      errorPMX: errorPMX,
      pmY: pmY,
      errorPMY: errorPMY,
      ut1UTC: ut1UTC,
      errorUT1UTC: errorUT1UTC,
      lod: lod,
      errorLOD: errorLOD,
      dX: dX,
      errorDX: errorDX,
      dY: dY,
      errorDY: errorDY
    }
  end
end
