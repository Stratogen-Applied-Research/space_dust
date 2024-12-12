defmodule SpaceDust.Time.TimeConversions do

  alias SpaceDust.Utils.Constants, as: Constants

  @doc "convert a Julian date to a DateTime"
  def julianDateToDateTime(julianDate) do
    # convert the Julian date to a Unix timestamp
    unixTimestamp = (julianDate - Constants.unixEpochJulianDate) * Constants.secondsPerDay
    # convert the Unix timestamp to a DateTime
    DateTime.from_unix(unixTimestamp)
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
