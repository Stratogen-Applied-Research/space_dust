defmodule SpaceDust.Ingest.Celestrak do
  @moduledoc """
  Module for ingesting TLE data from Celestrak.
  """

  alias SpaceDust.Utils.Tle, as: TLE

  @baseUrl "https://www.celestrak.com/NORAD/elements/gp-last.php?"
  @targetIdSpecifier "CATNR="
  @tleSpecifier "&FORMAT=TLE"

  @doc "pull the latest TLE for a given target id from Celestrak"
  def pullLatestTLE(targetId) do
    response = Req.get!(@baseUrl <> @targetIdSpecifier <> targetId <> @tleSpecifier)
    case response.status do
      200 ->
        # split the response body into lines
        lines = String.split(response.body, "\n")
        |> Enum.map(&String.trim/1)
        # line 1 has "1" at the beginning
        line1 = Enum.find(lines, fn line -> String.starts_with?(line, "1") end)
        # line 2 has "2" at the beginning
        line2 = Enum.find(lines, fn line -> String.starts_with?(line, "2") end)
        # parse the TLE
        TLE.parseTLE(line1, line2)  # this function returns {:ok, TLE} or {:error, reason}

      _ -> {:error, "Failed to retrieve TLE data from Celestrak"}
    end
  end
end
