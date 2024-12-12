defmodule SpaceDust.Time.TimeConversions do

  alias SpaceDust.Utils.Constants, as: Constants

  @doc "convert a Julian date to a DateTime"
  def julianDateToDateTime(julianDate) do
    # convert the Julian date to a Unix timestamp
    unixTimestamp = (julianDate - Constants.unixEpochJulianDate) * Constants.secondsPerDay
    unixSeconds = trunc(unixTimestamp)
    unixMicroseconds = trunc((unixTimestamp - unixSeconds) * 1_000_000)
    # convert the Unix timestamp to a DateTime
    {:ok, dateTimeToSecond} = DateTime.from_unix(unixSeconds, :second)
    DateTime.add(dateTimeToSecond, unixMicroseconds, :microsecond)
  end

  @doc "convert a DateTime to a Julian date"
  def dateTimeToJulianDate(dateTime) do
    # convert the DateTime to a Unix timestamp
    unixTimestamp = DateTime.to_unix(dateTime)
    # convert the Unix timestamp to a Julian date
    unixTimestamp / Constants.secondsPerDay + Constants.unixEpochJulianDate
  end

  @doc "convert a Julian date to a Modified Julian date"
  def julianDateToModifiedJulianDate(julianDate) do
    julianDate - 2400000.5
  end
end
