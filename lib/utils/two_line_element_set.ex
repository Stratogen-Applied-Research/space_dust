defmodule SpaceDust.Utils.TwoLineElementSet do
  @moduledoc """
  Two-Line Element Set (TLE) data structure.

  A TLE is a standardized format for describing the orbit of an Earth-orbiting
  object. TLEs are used with the SGP4/SDP4 propagators to predict satellite
  positions at future times.

  ## Fields

  ### Line 1 Elements

    - `line1` - Raw TLE line 1 string
    - `catalogNumber` - NORAD catalog number (5 digits)
    - `classification` - Security classification (U = Unclassified)
    - `internationalDesignator` - Launch year, launch number, piece
    - `epoch` - TLE epoch as DateTime
    - `meanMotionDot` - First derivative of mean motion (rev/day^2)
    - `meanMotionDoubleDot` - Second derivative of mean motion (rev/day^3)
    - `bStar` - BSTAR drag coefficient (1/Earth radii)
    - `ephemerisType` - Ephemeris type (usually 0)
    - `elementSetNumber` - Element set number

  ### Line 2 Elements

    - `line2` - Raw TLE line 2 string
    - `inclinationDeg` - Orbital inclination (degrees)
    - `raanDeg` - Right Ascension of Ascending Node (degrees)
    - `eccentricity` - Orbital eccentricity (dimensionless, 0-1)
    - `argPerigeeDeg` - Argument of perigee (degrees)
    - `meanAnomalyDeg` - Mean anomaly at epoch (degrees)
    - `meanMotion` - Mean motion (revolutions per day)
    - `revNumber` - Revolution number at epoch

  ## Example

      {:ok, tle} = SpaceDust.Utils.Tle.parseTLE(line1, line2)
      IO.puts("Satellite: \#{tle.catalogNumber}")
      IO.puts("Inclination: \#{tle.inclinationDeg} degrees")
      IO.puts("Period: \#{1440 / tle.meanMotion} minutes")

  """

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

  @type t :: %__MODULE__{
          line1: String.t(),
          line2: String.t(),
          catalogNumber: String.t() | nil,
          classification: String.t() | nil,
          internationalDesignator: String.t() | nil,
          epoch: DateTime.t() | nil,
          meanMotionDot: float() | nil,
          meanMotionDoubleDot: float() | nil,
          bStar: float() | nil,
          ephemerisType: integer() | nil,
          elementSetNumber: integer() | nil,
          inclinationDeg: float() | nil,
          raanDeg: float() | nil,
          eccentricity: float() | nil,
          argPerigeeDeg: float() | nil,
          meanAnomalyDeg: float() | nil,
          meanMotion: float() | nil,
          revNumber: integer() | nil
        }
end
