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
  alias SpaceDust.Data.LeapSecond

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
  Calculate GMST from UTC time.

  Uses the IAU 1982 expression for GMST.
  """
  @spec utc_to_gmst(UTC.t()) :: GMST.t()
  def utc_to_gmst(%UTC{} = utc) do
    jd = UTC.to_jd(utc)
    gmst_radians = calculate_gmst(jd)
    GMST.new(gmst_radians) |> GMST.normalize()
  end

  @doc """
  Calculate GMST from Julian Date.
  """
  @spec jd_to_gmst(JulianDate.t()) :: GMST.t()
  def jd_to_gmst(%JulianDate{jd: jd}) do
    gmst_radians = calculate_gmst(jd)
    GMST.new(gmst_radians) |> GMST.normalize()
  end

  # Private GMST calculation using IAU 1982 formula
  defp calculate_gmst(jd) do
    # Julian centuries from J2000.0
    t = (jd - 2_451_545.0) / 36525.0

    {c0, c1, c2, c3} = @gmst_poly

    # GMST at 0h UT in seconds
    gmst_0h = c0 + c1 * t + c2 * t * t + c3 * t * t * t

    # Add the rotation for the fractional day
    # Earth rotates 360.98564736629 degrees per day (sidereal)
    frac_day = :math.fmod(jd + 0.5, 1.0)
    rotation_seconds = frac_day * 86400.0 * 1.00273790935

    gmst_seconds = gmst_0h + rotation_seconds

    # Convert to radians (24 hours = 2π radians)
    gmst_seconds / 86400.0 * 2.0 * :math.pi()
  end

  # Nx-based GMST calculation
  defn gmst_from_jd_tensor(jd) do
    # Julian centuries from J2000.0
    t = (jd - 2_451_545.0) / 36525.0

    # GMST polynomial (IAU 1982)
    gmst_0h = 24110.54841 + 8_640_184.812866 * t + 0.093104 * t * t - 6.2e-6 * t * t * t

    # Add rotation for fractional day
    frac_day = Nx.remainder(jd + 0.5, 1.0)
    rotation_seconds = frac_day * 86400.0 * 1.00273790935

    gmst_seconds = gmst_0h + rotation_seconds

    # Convert to radians and normalize
    two_pi = 2.0 * Nx.Constants.pi()
    gmst_rad = gmst_seconds / 86400.0 * two_pi
    Nx.remainder(gmst_rad, two_pi)
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
  Full conversion pipeline: UTC unix seconds -> GMST radians.
  """
  defn batch_utc_to_gmst(utc_unix_seconds) do
    jd = unix_seconds_to_jd(utc_unix_seconds)
    gmst_from_jd_tensor(jd)
  end
end
