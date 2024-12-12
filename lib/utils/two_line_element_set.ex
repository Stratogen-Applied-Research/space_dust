defmodule SpaceDust.Utils.TwoLineElementSet do
  # only enforce line1/line2, since we can generate the others from these
  @enforce_keys [:line1, :line2]

  defstruct [
    :line1,
    :line2,
    :catalogNumber,
    :classification,
    :internationalDesignator,
    :epoch,
    :meanMotionDot,
    :meanMotionDoubleDot,
    :bStar,
    :ephemerisType,
    :elementSetNumber,
    :inclinationDeg,
    :raanDeg,
    :eccentricity,
    :argPerigeeDeg,
    :meanAnomalyDeg,
    :meanMotion,
    :revNumber
  ]
end
