defmodule IngestTest do
  use ExUnit.Case

  test "pull celestrak TLE" do
    {:ok, tle} = SpaceDust.Ingest.Celestrak.pullLatestTLE("25544")
    assert tle.catalogNumber == "25544"
  end
end
