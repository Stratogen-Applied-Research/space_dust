defmodule SpaceDust.Propagator.SGP4.Helpers do
  alias SpaceDust.Utils.Constants, as: Constants

  @doc """
  set the gravitational constants for a satrec given the wgs type
  """
  def getgravconst(rec, whichconst) do
    recCopy =
      Map.from_struct(rec)
      |> Map.put(:__struct__, Satrec)
      |> struct()
      |> Map.put(:whichconst, whichconst)

    case whichconst do
      :wgs72old ->
        Map.put(recCopy, :mu, 398_600.79964)
        |> Map.put(:radiusearthkm, 6378.135)
        |> Map.put(:xke, 0.0743669161)
        |> Map.put(:tumin, 1.0 / rec.xke)
        |> Map.put(:j2, 0.001082616)
        |> Map.put(:j3, -0.00000253881)
        |> Map.put(:j4, -0.00000165597)
        |> Map.put(:j3oj2, rec.j3 / rec.j2)

      :wgs72 ->
        Map.put(recCopy, :mu, 398_600.8)
        |> Map.put(:radiusearthkm, 6378.135)
        |> Map.put(
          :xke,
          60.0 / :math.sqrt(rec.radiusearthkm * rec.radiusearthkm * rec.radiusearthkm / rec.mu)
        )
        |> Map.put(:tumin, 1.0 / rec.xke)
        |> Map.put(:j2, 0.001082616)
        |> Map.put(:j3, -0.00000253881)
        |> Map.put(:j4, -0.00000165597)
        |> Map.put(:j3oj2, rec.j3 / rec.j2)

      :wgs84 ->
        Map.put(recCopy, :mu, 398_600.5)
        |> Map.put(:radiusearthkm, 6378.137)
        |> Map.put(
          :xke,
          60.0 / :math.sqrt(rec.radiusearthkm * rec.radiusearthkm * rec.radiusearthkm / rec.mu)
        )
        |> Map.put(:tumin, 1.0 / rec.xke)
        |> Map.put(:j2, 0.00108262998905)
        |> Map.put(:j3, -0.00000253215306)
        |> Map.put(:j4, -0.00000161098761)
        |> Map.put(:j3oj2, rec.j3 / rec.j2)
    end
  end

  @doc """
  Calculate Greenwich Sidereal Time (GST) from Julian Date
  """
  @spec gstime(number()) :: float()
  def gstime(jdut1) do
    tut1 = (jdut1 - Constants.j2000()) / 36525.0

    temp =
      -6.2e-6 * tut1 * tut1 * tut1 + 0.093104 * tut1 * tut1 +
        (876_600.0 * 3600 + 8_640_184.812866) * tut1 + 67310.54841

    # //360/86400 = 1/240, to deg, to rad
    temp = :math.fmod(temp * Constants.degreesToRadians() / 240.0, Constants.twopi())

    # // ------------------------ check quadrants ---------------------
    if temp < 0.0 do
      temp + Constants.twopi()
    else
      temp
    end
  end

  @doc """
  Calculate Julian Day from year, month, day, hour, minute, and second
  """
  @spec jday(number(), number(), number(), number(), number(), number()) :: {float(), float()}
  def jday(year, mon, day, hr, minute, sec) do
    jd =
      367.0 * year -
        :math.floor(7 * (year + :math.floor((mon + 9) / 12.0)) * 0.25) +
        :math.floor(275 * mon / 9.0) +
        day + 1_721_013.5

    jdFrac = (sec + minute * 60.0 + hr * 3600.0) / 86400.0

    # // check that the day and fractional day are correct
    if abs(jdFrac) > 1.0 do
      dtt = :math.floor(jdFrac)
      jd = jd + dtt
      {jd, jdFrac - dtt}
    else
      {jd, jdFrac}
    end
  end
end
