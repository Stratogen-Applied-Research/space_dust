defmodule SpaceDust.Ingest.Celestrak do
  @moduledoc """
  Client for retrieving Two-Line Element (TLE) data from Celestrak.

  Celestrak is a public service that provides NORAD two-line element sets
  for satellites. This module provides functions to fetch the latest TLE
  data for specific satellites by their NORAD catalog number.

  ## Example

      # Fetch TLE for the International Space Station (NORAD ID: 25544)
      {:ok, tle} = SpaceDust.Ingest.Celestrak.pullLatestTLE("25544")

      # Fetch TLE for a geostationary satellite
      {:ok, tle} = SpaceDust.Ingest.Celestrak.pullLatestTLE("40425")

  ## Notes

  - Requires network access to celestrak.org
  - TLEs are typically updated several times per day
  - NORAD catalog numbers can be found at space-track.org or celestrak.org
  """

  alias SpaceDust.Utils.Tle, as: TLE

  @baseUrl "https://celestrak.org/NORAD/elements/gp-last.php?"
  @targetIdSpecifier "CATNR="
  @tleSpecifier "&FORMAT=TLE"

  @doc """
  Fetch the latest TLE for a satellite from Celestrak.

  ## Parameters

    - `targetId` - NORAD catalog number as a string (e.g., "25544" for ISS)

  ## Returns

    - `{:ok, %TwoLineElementSet{}}` - Successfully retrieved and parsed TLE
    - `{:error, reason}` - Failed to retrieve or parse TLE

  ## Example

      iex> {:ok, tle} = SpaceDust.Ingest.Celestrak.pullLatestTLE("25544")
      iex> tle.inclinationDeg
      51.6...

  """
  @spec pullLatestTLE(String.t()) :: {:ok, SpaceDust.Utils.TwoLineElementSet.t()} | {:error, String.t()}
  def pullLatestTLE(targetId) do
    response = Req.get!(@baseUrl <> @targetIdSpecifier <> targetId <> @tleSpecifier)

    case response.status do
      200 -> parseTleResponseBody(response.body)
      _ -> {:error, "Failed to retrieve TLE data from Celestrak"}
    end
  end

  @doc """
  Parse the body of a Celestrak `FORMAT=TLE` response into a TLE.

  Split out from `pullLatestTLE/1` so the parsing can be exercised without
  reaching Celestrak; the live endpoint rejects datacenter traffic, so CI has no
  way to fetch a real response.

  ## Returns

    - `{:ok, %TwoLineElementSet{}}` - Successfully parsed TLE
    - `{:error, reason}` - The body carried no usable element set
  """
  @spec parseTleResponseBody(String.t()) ::
          {:ok, SpaceDust.Utils.TwoLineElementSet.t()} | {:error, String.t()}
  def parseTleResponseBody(body) when is_binary(body) do
    lines =
      body
      |> String.split("\n")
      |> Enum.map(&String.trim/1)

    # line 1 has "1" at the beginning, line 2 has "2"
    line1 = Enum.find(lines, fn line -> String.starts_with?(line, "1") end)
    line2 = Enum.find(lines, fn line -> String.starts_with?(line, "2") end)

    # Celestrak answers an unknown catalog number with a short text body rather
    # than an error status, so a missing line is a routine outcome here.
    if is_nil(line1) or is_nil(line2) do
      {:error, "No TLE found in Celestrak response"}
    else
      TLE.parseTLE(line1, line2)
    end
  end
end
