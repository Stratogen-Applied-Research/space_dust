defmodule IngestTest do
  use ExUnit.Case

  alias SpaceDust.Ingest.Celestrak

  # A verbatim gp-last.php?FORMAT=TLE response.
  @celestrakResponse """
  ISS (ZARYA)             
  1 25544U 98067A   26243.46624056  .00005046  00000+0  99862-4 0  9992
  2 25544  51.6314 287.5025 0005045  92.8598 267.2968 15.48949540583427
  """

  describe "parsing a Celestrak response" do
    test "reads the element set out of a TLE-format body" do
      assert {:ok, tle} = Celestrak.parseTleResponseBody(@celestrakResponse)
      assert tle.catalogNumber == "25544"
      assert tle.inclinationDeg == 51.6314
    end

    test "tolerates CRLF line endings" do
      body = String.replace(@celestrakResponse, "\n", "\r\n")
      assert {:ok, tle} = Celestrak.parseTleResponseBody(body)
      assert tle.catalogNumber == "25544"
    end

    test "reports an unknown catalog number rather than crashing" do
      # What Celestrak returns for a catalog number it does not know: HTTP 200
      # with a plain-text body and no element set.
      assert {:error, _} = Celestrak.parseTleResponseBody("No GP data found\n")
    end
  end

  # Celestrak answers datacenter IPs with HTTP 503, so this cannot run on a
  # hosted CI runner. It stays in the suite for local runs, where it is the only
  # thing that catches the live endpoint moving or its certificate expiring.
  # Run it with: mix test --include external
  @tag :external
  test "pull celestrak TLE" do
    {:ok, tle} = Celestrak.pullLatestTLE("25544")
    assert tle.catalogNumber == "25544"
  end
end
