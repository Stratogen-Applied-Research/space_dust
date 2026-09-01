defmodule SpaceDust.Time.Transforms do
  @moduledoc """
  Nx-based time transformations between different time standards.

  All conversions are performed efficiently using Nx tensors for
  potential GPU/TPU acceleration.

  ## Time Scale Relationships

  ```
  UTC <---> TAI <---> TT
    |         |
    |         +--> GPS
    |
    +--> JD/MJD
    |
    +--> GMST
  ```

  - TAI = UTC + leap_seconds
  - TT = TAI + 32.184s
  - GPS = TAI - 19s
  """

  import Nx.Defn
  alias SpaceDust.Time.{UTC, TAI, TT, GPS, JulianDate, GMST}
  alias SpaceDust.Data.{LeapSecond, EOPCache}

  # Constants for Nx
  @tt_tai_offset 32.184
  @gps_tai_offset -19
  @seconds_per_day 86_400.0
  @unix_epoch_jd 2_440_587.5

  # GMST polynomial coefficients (IAU 1982)
  @gmst_poly {
    24110.54841,      # seconds
    8640184.812866,   # seconds per century
    0.093104,         # seconds per century^2
    -6.2e-6           # seconds per century^3
  }

  # ============================================================================
  # UTC <-> TAI conversions
  # ============================================================================

  @doc """
  Convert UTC to TAI.

  TAI = UTC + leap_seconds
  """
  @spec utc_to_tai(UTC.t()) :: TAI.t()
  def utc_to_tai(%UTC{unix_seconds: utc_s}) do
    leap_seconds = LeapSecond.julianDateToLeapSeconds(
      utc_s / @seconds_per_day + @unix_epoch_jd
    )
    TAI.new(utc_s + leap_seconds)
  end

  @doc """
  Convert TAI to UTC.

  UTC = TAI - leap_seconds

  Note: This requires knowing the leap seconds at the TAI time, which
  technically requires iterating since leap seconds are defined in UTC.
  We use an approximation that works for normal use cases.
  """
  @spec tai_to_utc(TAI.t()) :: UTC.t()
  def tai_to_utc(%TAI{tai_seconds: tai_s}) do
    # First approximation: use current TAI time to estimate UTC
    approx_utc_jd = tai_s / @seconds_per_day + @unix_epoch_jd
    leap_seconds = LeapSecond.julianDateToLeapSeconds(approx_utc_jd)
    UTC.new(tai_s - leap_seconds)
  end

  # ============================================================================
  # TAI <-> TT conversions
  # ============================================================================

  @doc """
  Convert TAI to TT.

  TT = TAI + 32.184 seconds
  """
  @spec tai_to_tt(TAI.t()) :: TT.t()
  def tai_to_tt(%TAI{tai_seconds: tai_s}) do
    TT.new(tai_s + @tt_tai_offset)
  end

  @doc """
  Convert TT to TAI.

  TAI = TT - 32.184 seconds
  """
  @spec tt_to_tai(TT.t()) :: TAI.t()
  def tt_to_tai(%TT{tt_seconds: tt_s}) do
    TAI.new(tt_s - @tt_tai_offset)
  end

  # Nx-based versions for batch processing
  defn tai_to_tt_tensor(tai_tensor) do
    tai_tensor + @tt_tai_offset
  end

  defn tt_to_tai_tensor(tt_tensor) do
    tt_tensor - @tt_tai_offset
  end

  # ============================================================================
  # TAI <-> GPS conversions
  # ============================================================================

  @doc """
  Convert TAI to GPS time.

  GPS = TAI - 19 seconds (offset since GPS epoch)
  """
  @spec tai_to_gps(TAI.t()) :: GPS.t()
  def tai_to_gps(%TAI{tai_seconds: tai_s}) do
    # GPS seconds are from GPS epoch, TAI seconds are from Unix epoch
    # GPS epoch in TAI = Unix 315964800 + leap_seconds_at_gps_epoch
    # At GPS epoch (1980-01-06), there were 19 leap seconds
    gps_epoch_tai = GPS.gps_epoch_unix() + 19
    GPS.new(tai_s - gps_epoch_tai + @gps_tai_offset)
  end

  @doc """
  Convert GPS time to TAI.
  """
  @spec gps_to_tai(GPS.t()) :: TAI.t()
  def gps_to_tai(%GPS{gps_seconds: gps_s}) do
    gps_epoch_tai = GPS.gps_epoch_unix() + 19
    TAI.new(gps_s + gps_epoch_tai - @gps_tai_offset)
  end

  # ============================================================================
  # UTC <-> TT convenience conversions
  # ============================================================================

  @doc """
  Convert UTC directly to TT.
  """
  @spec utc_to_tt(UTC.t()) :: TT.t()
  def utc_to_tt(%UTC{} = utc) do
    utc
    |> utc_to_tai()
    |> tai_to_tt()
  end

  @doc """
  Convert TT directly to UTC.
  """
  @spec tt_to_utc(TT.t()) :: UTC.t()
  def tt_to_utc(%TT{} = tt) do
    tt
    |> tt_to_tai()
    |> tai_to_utc()
  end

  # ============================================================================
  # UTC <-> GPS convenience conversions
  # ============================================================================

  @doc """
  Convert UTC directly to GPS time.
  """
  @spec utc_to_gps(UTC.t()) :: GPS.t()
  def utc_to_gps(%UTC{} = utc) do
    utc
    |> utc_to_tai()
    |> tai_to_gps()
  end

  @doc """
  Convert GPS time directly to UTC.
  """
  @spec gps_to_utc(GPS.t()) :: UTC.t()
  def gps_to_utc(%GPS{} = gps) do
    gps
    |> gps_to_tai()
    |> tai_to_utc()
  end

  # ============================================================================
  # Julian Date conversions
  # ============================================================================

  @doc """
  Convert UTC to Julian Date.
  """
  @spec utc_to_jd(UTC.t()) :: JulianDate.t()
  def utc_to_jd(%UTC{} = utc) do
    JulianDate.new(UTC.to_jd(utc))
  end

  @doc """
  Convert Julian Date to UTC.
  """
  @spec jd_to_utc(JulianDate.t()) :: UTC.t()
  def jd_to_utc(%JulianDate{jd: jd}) do
    UTC.from_jd(jd)
  end

  # Nx-based JD conversions
  defn unix_seconds_to_jd(unix_seconds) do
    unix_seconds / @seconds_per_day + @unix_epoch_jd
  end

  defn jd_to_unix_seconds(jd) do
    (jd - @unix_epoch_jd) * @seconds_per_day
  end

  # ============================================================================
  # GMST calculations
  # ============================================================================

  @doc """
  Convert UTC to the UT1 Julian Date.

  Earth's rotation angle is a function of UT1, so any sidereal time has to be
  formed from UT1 rather than UTC. The offset comes from the interpolated IERS
  table and is bounded by 0.9 s; an epoch with no EOP coverage falls back to
  UTC, which costs up to about 13 arcseconds of rotation.
  """
  @spec utc_to_ut1_jd(UTC.t()) :: float()
  def utc_to_ut1_jd(%UTC{} = utc) do
    jd = UTC.to_jd(utc)

    offset =
      case EOPCache.get(jd - 2_400_000.5) do
        {:ok, %{ut1UTC: ut1_utc}} when is_number(ut1_utc) -> ut1_utc
        _ -> 0.0
      end

    jd + offset / @seconds_per_day
  end

  @doc """
  Calculate GMST from UTC time.

  Uses the IAU 1982 expression, evaluated on UT1.
  """
  @spec utc_to_gmst(UTC.t()) :: GMST.t()
  def utc_to_gmst(%UTC{} = utc) do
    gmst_radians = calculate_gmst(utc_to_ut1_jd(utc))
    GMST.new(gmst_radians) |> GMST.normalize()
  end

  @doc """
  Calculate GMST from a Julian Date.

  The Julian Date must be in UT1. Use `utc_to_gmst/1` to have the UT1 offset
  applied for you.
  """
  @spec jd_to_gmst(JulianDate.t()) :: GMST.t()
  def jd_to_gmst(%JulianDate{jd: jd}) do
    gmst_radians = calculate_gmst(jd)
    GMST.new(gmst_radians) |> GMST.normalize()
  end

  # Private GMST calculation using the IAU 1982 formula.
  #
  # The polynomial is defined at 0h UT1 of the day in question, so the Julian
  # Date has to be floored to midnight before forming T. The elapsed fraction
  # of the day is then added separately, scaled by the sidereal rate. Feeding
  # the polynomial the full Julian Date *and* adding the fractional-day term
  # counts the elapsed day twice, which is worth up to 0.0172 rad - a whole
  # degree of Earth rotation - just before midnight.
  defp calculate_gmst(jd) do
    jd_midnight = Float.floor(jd - 0.5) + 0.5
    t = (jd_midnight - 2_451_545.0) / 36525.0

    {c0, c1, c2, c3} = @gmst_poly

    # GMST at 0h UT1, in seconds
    gmst_0h = c0 + c1 * t + c2 * t * t + c3 * t * t * t

    # Add the rotation for the elapsed fraction of the day, in sidereal seconds
    rotation_seconds = (jd - jd_midnight) * 86400.0 * 1.00273790935

    gmst_seconds = gmst_0h + rotation_seconds

    # Convert to radians (24 hours = 2π radians)
    gmst_seconds / 86400.0 * 2.0 * :math.pi()
  end

  @doc """
  GMST in radians from a batch of UT1 Julian Dates, normalized to [0, 2π).
  """
  defn gmst_from_jd_tensor(jd) do
    # Floor to 0h UT1 before forming T; see calculate_gmst/1 above.
    jd_midnight = Nx.floor(jd - 0.5) + 0.5
    t = (jd_midnight - 2_451_545.0) / 36525.0

    # GMST polynomial (IAU 1982), seconds
    gmst_0h = 24110.54841 + 8_640_184.812866 * t + 0.093104 * t * t - 6.2e-6 * t * t * t

    # Rotation for the elapsed fraction of the day
    rotation_seconds = (jd - jd_midnight) * 86400.0 * 1.00273790935

    gmst_seconds = gmst_0h + rotation_seconds

    # Convert to radians and normalize into [0, 2π)
    two_pi = 2.0 * Nx.Constants.pi()
    gmst_rad = Nx.remainder(gmst_seconds / 86400.0 * two_pi, two_pi)
    Nx.select(gmst_rad < 0.0, gmst_rad + two_pi, gmst_rad)
  end

  # ============================================================================
  # Batch conversions for efficiency
  # ============================================================================

  @doc """
  Convert a batch of UTC times to TAI using Nx.
  Takes a tensor of Unix seconds (UTC) and leap seconds offset.
  """
  defn batch_utc_to_tai(utc_tensor, leap_seconds) do
    utc_tensor + leap_seconds
  end

  @doc """
  Convert a batch of TAI times to UTC using Nx.
  """
  defn batch_tai_to_utc(tai_tensor, leap_seconds) do
    tai_tensor - leap_seconds
  end

  @doc """
  Full conversion pipeline: UT1 unix seconds -> GMST radians.

  Takes UT1, not UTC: an EOP lookup cannot run inside `defn`, so add the
  `UT1 - UTC` offset (see `utc_to_ut1_jd/1`) before calling this. Passing UTC
  costs up to about 13 arcseconds of rotation.
  """
  defn batch_ut1_to_gmst(ut1_unix_seconds) do
    jd = unix_seconds_to_jd(ut1_unix_seconds)
    gmst_from_jd_tensor(jd)
  end
end
