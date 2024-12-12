defmodule SpaceDust.Utils.Tle do

  alias SpaceDust.Utils.TwoLineElementSet, as: TwoLineElementSet
  alias SpaceDust.Utils.Constants, as: Constants

  @microsecondsPerDay Constants.secondsPerDay * 1_000_000

  @doc "parse a two line element set (TLE) from a string"
  def parseTlE(line1, line2) do
    # check to ensure each line is 69 characters
    case {String.length(line1), String.length(line2)} do
      {69, 69} -> # TLE has correct number of characters, proceed with parsing
        try do
          lastDigitsOfYear = String.to_integer(String.slice(line1, 18..19))
          currentYear = Date.utc_today().year

          epochYear = if lastDigitsOfYear > currentYear - 2000 do
            1900 + lastDigitsOfYear
          else
            2000 + lastDigitsOfYear
          end

          dayOfYear = String.to_float(String.slice(line1, 20..31))
          daysToAdd = trunc(dayOfYear)
          microsecondsToAdd = trunc((dayOfYear - daysToAdd) * @microsecondsPerDay)
          startOfYear = DateTime.new!(Date.new!(epochYear, 1, 1), Time.new!(0, 0, 0, 0))

          epoch = DateTime.add(startOfYear, daysToAdd)
          |> DateTime.add(microsecondsToAdd, :microsecond)

          meanMotionDoubleDot = if String.at(line1, 44) == "-" do
            (-1) * String.to_float(String.replace("0." <> String.slice(line1, 45..49), " ", "")) * Float.pow(10.0, String.to_integer(String.slice(line1, 50..51)))
          else
            String.to_float(String.replace("0." <> String.slice(line1, 45..49), " ", "")) * Float.pow(10.0, String.to_integer(String.slice(line1, 50..51)))
          end

          meanMotionDot = if String.at(line1, 33) == "-" do
            (-1) * String.to_float(String.replace("0" <> String.slice(line1, 34..42), " ", ""))
          else
            String.to_float(String.replace("0" <> String.slice(line1, 34..42), " ", ""))
          end

          bStar = if String.at(line1, 53) == "-" do
            (-1) * String.to_float(String.replace("0." <> String.slice(line1, 54..58), " ", "")) * Float.pow(10.0, String.to_integer(String.slice(line1, 59..60)))
          else
            String.to_float(String.replace("0." <> String.slice(line1, 53..58), " ", "")) * Float.pow(10.0, String.to_integer(String.slice(line1, 59..60)))
          end

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
            elementSetNumber: String.to_integer(String.replace(String.slice(line1, 64..67), " ", "")),

            # line 2 parameters
            line2: line2,
            inclinationDeg: String.to_float(String.replace(String.slice(line2, 8..15), " ", "")),
            raanDeg: String.to_float(String.replace(String.slice(line2, 17..24), " ", "")),
            eccentricity: String.to_float(String.replace("0." <> String.slice(line2, 26..32), " ", "")),
            argPerigeeDeg: String.to_float(String.replace(String.slice(line2, 34..41), " ", "")),
            meanAnomalyDeg: String.to_float(String.replace(String.slice(line2, 43..50), " ", "")),
            meanMotion: String.to_float(String.replace(String.slice(line2, 52..62), " ", "")),
            revNumber: String.to_integer(String.replace(String.slice(line2, 63..67), " ", ""))
          }
          {:ok, tle}
        rescue
          ArgumentError -> {:error, "Unable to parse TLE- check all fields are correctly spaced"}
        end
      _ -> {:error, "Unable to parse TLE- line length is incorrect"}
    end
  end
end
