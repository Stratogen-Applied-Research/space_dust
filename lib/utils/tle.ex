defmodule SpaceDust.Utils.Tle do
  @moduledoc """
  Parsing and propagation utilities for Two-Line Element Sets (TLEs).

  This module provides functions to:
  - Parse TLE strings into structured data
  - Propagate TLEs to compute satellite position/velocity at any time

  ## TLE Format

  A TLE consists of two 69-character lines containing orbital elements in a
  fixed-width format. The format is standardized by NORAD/USSPACECOM.

  ## SGP4 Propagation

  TLE propagation uses the SGP4 (Simplified General Perturbations 4) algorithm,
  which accounts for:
  - Earth's oblateness (J2 perturbation)
  - Atmospheric drag
  - Solar/lunar gravitational effects (for high-altitude orbits)

  The output is in the TEME (True Equator Mean Equinox) reference frame,
  which can be converted to ECI J2000 using `SpaceDust.State.Transforms`.

  ## Example

      # Parse a TLE
      line1 = "1 25544U 98067A   24001.50000000  .00016717  00000-0  10270-3 0  9002"
      line2 = "2 25544  51.6400 208.1200 0001234  85.0000 275.0000 15.48919100123456"
      {:ok, tle} = SpaceDust.Utils.Tle.parseTLE(line1, line2)

      # Propagate to a future time
      epoch = ~U[2024-01-02 12:00:00Z]
      {position, velocity} = SpaceDust.Utils.Tle.getRVatTime(tle, epoch)
      # position is {x, y, z} in km
      # velocity is {vx, vy, vz} in km/s

  """

  require Logger
  alias SpaceDust.Utils.TwoLineElementSet, as: TwoLineElementSet
  alias SpaceDust.Utils.Constants, as: Constants

  @microsecondsPerDay Constants.secondsPerDay() * 1_000_000

  @doc """
  Parse a Two-Line Element set from its string representation.

  ## Parameters

    - `line1` - First line of the TLE (69 characters)
    - `line2` - Second line of the TLE (69 characters)

  ## Returns

    - `{:ok, %TwoLineElementSet{}}` - Successfully parsed TLE
    - `{:error, reason}` - Parsing failed

  ## Example

      line1 = "1 25544U 98067A   24001.50000000  .00016717  00000-0  10270-3 0  9002"
      line2 = "2 25544  51.6400 208.1200 0001234  85.0000 275.0000 15.48919100123456"
      {:ok, tle} = SpaceDust.Utils.Tle.parseTLE(line1, line2)

  """
  @spec parseTLE(String.t(), String.t()) :: {:ok, TwoLineElementSet.t()} | {:error, String.t()}
  def parseTLE(line1, line2) do
    # check to ensure each line is 69 characters
    case {String.length(line1), String.length(line2)} do
      # TLE has correct number of characters, proceed with parsing
      {69, 69} ->
        try do
          # NORAD's two-digit epoch year uses a fixed pivot at 57: 57-99 are
          # 1957-1999, 00-56 are 2000-2056. Pivoting on the current year instead
          # sends near-future element sets a century backward - a 2030 epoch
          # parsed as 1930 - and makes the same TLE parse differently as the
          # calendar advances, so a cached result stops matching a fresh one.
          lastDigitsOfYear = String.to_integer(String.slice(line1, 18..19))

          epochYear =
            if lastDigitsOfYear < 57 do
              2000 + lastDigitsOfYear
            else
              1900 + lastDigitsOfYear
            end

          # day 1 is 0 days from the start of the year
          dayOfYear = String.to_float(String.slice(line1, 20..31)) - 1
          daysToAdd = trunc(dayOfYear)
          microsecondsToAdd = trunc((dayOfYear - daysToAdd) * @microsecondsPerDay)
          startOfYear = DateTime.new!(Date.new!(epochYear, 1, 1), Time.new!(0, 0, 0, 0))

          epoch =
            DateTime.add(startOfYear, daysToAdd, :day)
            |> DateTime.add(microsecondsToAdd, :microsecond)

          meanMotionDoubleDot = parseExponential(line1, 44)

          meanMotionDot =
            if String.at(line1, 33) == "-" do
              -1 * String.to_float(String.replace("0" <> String.slice(line1, 34..42), " ", ""))
            else
              String.to_float(String.replace("0" <> String.slice(line1, 34..42), " ", ""))
            end

          bStar = parseExponential(line1, 53)

          tle = %TwoLineElementSet{
            # line 1 parameters
            line1: line1,
            catalogNumber: String.replace(String.slice(line1, 2..6), " ", ""),
            classification: String.at(line1, 7),
            internationalDesignator: String.replace(String.slice(line1, 9..16), " ", ""),
            epoch: epoch,
            meanMotionDot: meanMotionDot,
            meanMotionDoubleDot: meanMotionDoubleDot,
            bStar: bStar,
            ephemerisType: String.to_integer(String.at(line1, 62)),
            elementSetNumber:
              String.to_integer(String.replace(String.slice(line1, 64..67), " ", "")),

            # line 2 parameters
            line2: line2,
            inclinationDeg: String.to_float(String.replace(String.slice(line2, 8..15), " ", "")),
            raanDeg: String.to_float(String.replace(String.slice(line2, 17..24), " ", "")),
            eccentricity:
              String.to_float(String.replace("0." <> String.slice(line2, 26..32), " ", "")),
            argPerigeeDeg: String.to_float(String.replace(String.slice(line2, 34..41), " ", "")),
            meanAnomalyDeg: String.to_float(String.replace(String.slice(line2, 43..50), " ", "")),
            meanMotion: String.to_float(String.replace(String.slice(line2, 52..62), " ", "")),
            revNumber: String.to_integer(String.replace(String.slice(line2, 63..67), " ", ""))
          }

          {:ok, %{tle | sgp4Tle: sgp4Handle(line1, line2)}}
        rescue
          ArgumentError -> {:error, "Unable to parse TLE- check all fields are correctly spaced"}
        end

      _ ->
        {:error, "Unable to parse TLE- line length is incorrect"}
    end
  end

  # Read one of the TLE's assumed-decimal-point exponential fields, which occupy
  # eight columns starting at `offset`: a sign, a five-digit mantissa with an
  # implied leading "0.", then a signed one-digit exponent.
  #
  # The sign column is blank for a positive value in most producers' output, but
  # not all of them - some write "+". Both have to be accepted: reading the sign
  # column as part of the mantissa makes "+10270-3" fail String.to_float and
  # rejects the whole element set.
  defp parseExponential(line, offset) do
    sign = if String.at(line, offset) == "-", do: -1.0, else: 1.0

    mantissa =
      line
      |> String.slice((offset + 1)..(offset + 5))
      |> String.replace(" ", "")

    exponent =
      line
      |> String.slice((offset + 6)..(offset + 7))
      |> String.replace(" ", "")

    mantissa = if mantissa == "", do: "0", else: mantissa
    exponent = if exponent in ["", "+", "-"], do: "0", else: exponent

    sign * String.to_float("0." <> mantissa) * Float.pow(10.0, String.to_integer(exponent))
  end

  @doc """
  Propagate a TLE to compute position and velocity at a given epoch.

  Uses the SGP4 algorithm via the sgp4_ex library, which propagates with
  Vallado's native C++ NIF when it is available and transparently falls back to
  an equivalent pure-Elixir implementation when it is not. Both backends produce
  identical results. The output is in the TEME reference frame.

  ## Parameters

    - `twoLineElementSet` - Parsed TLE from `parseTLE/2`
    - `utcEpoch` - Target time as a DateTime in UTC

  ## Returns

    - `{{x, y, z}, {vx, vy, vz}}` - Position (km) and velocity (km/s) in TEME frame
    - `{:error, reason}` - Propagation failed

  ## Example

      {:ok, tle} = SpaceDust.Utils.Tle.parseTLE(line1, line2)
      {position, velocity} = SpaceDust.Utils.Tle.getRVatTime(tle, ~U[2024-01-15 12:00:00Z])

      # Convert to ECI J2000 for further calculations
      teme = SpaceDust.State.TEMEState.new(epoch, position, velocity)
      eci = SpaceDust.State.Transforms.teme_to_eci(teme)

  ## Notes

    - Propagation accuracy degrades as time increases from the TLE epoch
    - TLEs are typically valid for a few days before/after their epoch
    - For best results, use the most recent TLE available

  """
  @spec getRVatTime(TwoLineElementSet.t(), DateTime.t()) ::
          {{float(), float(), float()}, {float(), float(), float()}} | {:error, term()}
  def getRVatTime(twoLineElementSet, utcEpoch) do
    # parseTLE/2 already paid for the sgp4_ex parse; reuse it rather than
    # re-parsing the same 69-character lines on every propagation. Parsing costs
    # roughly eighteen times as much as the propagation itself, and reusing the
    # handle is also what lets sgp4_ex hit its own cache of the initialized
    # satellite record. Structs built by hand carry no handle, so fall back to
    # parsing on demand - that path keeps the original error behaviour.
    case sgp4Tle(twoLineElementSet) do
      {:ok, sgp4_tle} ->
        case Sgp4Ex.propagate_tle_to_epoch(sgp4_tle, utcEpoch) do
          {:ok, %Sgp4Ex.TemeState{position: {rx, ry, rz}, velocity: {vx, vy, vz}}} ->
            {{rx, ry, rz}, {vx, vy, vz}}

          {:error, reason} ->
            Logger.error("SGP4 propagation failed: #{reason}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to parse TLE: #{reason}")
        {:error, reason}
    end
  end

  defp sgp4Tle(%TwoLineElementSet{sgp4Tle: %Sgp4Ex.TLE{} = handle}), do: {:ok, handle}

  defp sgp4Tle(%TwoLineElementSet{line1: line1, line2: line2}),
    do: Sgp4Ex.parse_tle(line1, line2)

  # sgp4_ex is stricter than parseTLE/2 about some fields, so a set this module
  # accepts can still be rejected here. Store nothing in that case and let
  # getRVatTime/2 surface the parse error, exactly as it did before the handle
  # was cached.
  defp sgp4Handle(line1, line2) do
    case Sgp4Ex.parse_tle(line1, line2) do
      {:ok, handle} -> handle
      {:error, _reason} -> nil
    end
  end
end
