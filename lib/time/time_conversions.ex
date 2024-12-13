defmodule SpaceDust.Time.TimeConversions do
  alias SpaceDust.Utils.Constants, as: Constants
  alias SpaceDust.Data.LeapSecond, as: LeapSecond
  alias SpaceDust.Math.Functions, as: Math
  alias SpaceDust.Utils.Constants, as: Constants

  @gmstPoly [-6.2e-6, 0.093104, 876_600 * 3600 + 8_640_184.812866, 67310.54841]

  @spec julianDateToDateTime(number()) :: DateTime.t()
  @doc "convert a Julian date to a DateTime"
  def julianDateToDateTime(julianDate) do
    # convert the Julian date to a Unix timestamp
    unixTimestamp = (julianDate - Constants.unixEpochJulianDate()) * Constants.secondsPerDay()
    unixSeconds = trunc(unixTimestamp)
    unixMicroseconds = trunc((unixTimestamp - unixSeconds) * 1_000_000)
    # convert the Unix timestamp to a DateTime
    {:ok, dateTimeToSecond} = DateTime.from_unix(unixSeconds, :second)
    DateTime.add(dateTimeToSecond, unixMicroseconds, :microsecond)
  end

  @spec dateTimeToJulianDate(DateTime.t()) :: float()
  @doc "convert a DateTime to a Julian date"
  def dateTimeToJulianDate(dateTime) do
    # convert the DateTime to a Unix timestamp
    unixTimestamp = DateTime.to_unix(dateTime, :millisecond) / 1_000
    # convert the Unix timestamp to a Julian date
    unixTimestamp / Constants.secondsPerDay() + Constants.unixEpochJulianDate()
  end

  @doc "convert a Julian date to Julian centuries"
  def julianDateToJulianCenturies(julianDate) do
    julianDate / 36525.0
  end

  @spec julianDateToModifiedJulianDate(number()) :: float()
  @doc "convert a Julian date to a Modified Julian date"
  def julianDateToModifiedJulianDate(julianDate) do
    julianDate - 2_400_000.5
  end

  @spec utcToTAI(DateTime.t()) :: DateTime.t()
  @doc "convert a UTC DateTime to TAI"
  def utcToTAI(dateTime) do
    # leap seconds are added to UTC to get TAI
    julianDate = dateTimeToJulianDate(dateTime)
    leapSeconds = LeapSecond.julianDateToLeapSeconds(julianDate)
    DateTime.add(dateTime, leapSeconds, :second)
  end

  @spec taiToUTC(DateTime.t()) :: DateTime.t()
  @doc "convert a TAI DateTime to UTC"
  def taiToUTC(dateTime) do
    # leap seconds are subtracted from TAI to get UTC
    julianDate = dateTimeToJulianDate(dateTime)
    leapSeconds = LeapSecond.julianDateToLeapSeconds(julianDate)
    DateTime.add(dateTime, -leapSeconds, :second)
  end

  @spec utcToTT(DateTime.t()) :: DateTime.t()
  @doc "convert a UTC DateTime to TT"
  def utcToTT(dateTime) do
    # TT is 32.184 seconds ahead of TAI
    DateTime.add(utcToTAI(dateTime), 32_184, :millisecond)
  end

  @spec ttToUTC(DateTime.t()) :: DateTime.t()
  @doc "convert a TT DateTime to UTC"
  def ttToUTC(dateTime) do
    # TT is 32.184 seconds ahead of TAI
    DateTime.add(taiToUTC(dateTime), -32_184, :millisecond)
  end

  @doc "convert a UTC DateTime to GMST angle"
  def utcToGmstAngle(dateTime) do
    julianCenturies =
      dateTimeToJulianDate(dateTime)
      |> julianDateToJulianCenturies()

    seconds = Math.polyEval(@gmstPoly, julianCenturies)
    fractionalRevolution = seconds / Constants.secondsPerDay()

    # get the modulus of the fractional revolution
    result = fractionalRevolution - trunc(fractionalRevolution)

    # convert the result to an angle
    angle = result * :math.pi() * 2.0

    if angle < 0.0 do
      angle + :math.pi() * 2.0
    else
      angle
    end
  end
end
