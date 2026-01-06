defmodule SpaceDust.Observations do
  @moduledoc """
  Functions for computing angular observations from observer and target states.

  Provides transformations between different observation coordinate systems:
  - ECI (Earth-Centered Inertial) ↔ RA/Dec (Right Ascension/Declination)
  - ECI ↔ Az/El (Azimuth/Elevation) for a ground observer
  - RA/Dec ↔ Az/El conversions

  All angular computations account for the observer's location and
  the Earth's rotation at the observation epoch.
  """

  alias SpaceDust.State.{ECIState, GeodeticState}
  alias SpaceDust.State.Transforms
  alias SpaceDust.Observations.{RaDec, AzEl}
  alias SpaceDust.Math.Vector.Vector3D
  alias SpaceDust.Math.Vector

  # =============================================================================
  # RA/Dec Observations
  # =============================================================================

  @doc """
  Compute RA/Dec observation of a target from an observer.

  ## Parameters
    - observer: GeodeticState of the ground observer
    - target: ECIState of the target
    - opts: Optional parameters
      - :include_rates - Compute angular rates (default: false)

  ## Returns
    - RaDec observation struct

  ## Example
      observer = GeodeticState.new(40.0, -105.0, 1.6)
      target = ECIState.new(epoch, {7000.0, 0.0, 0.0}, {0.0, 7.5, 0.0})
      SpaceDust.Observations.compute_ra_dec(observer, target)
  """
  @spec compute_ra_dec(GeodeticState.t(), ECIState.t(), keyword()) :: RaDec.t()
  def compute_ra_dec(%GeodeticState{} = observer, %ECIState{epoch: epoch} = target, opts \\ []) do
    # Get observer position in ECI
    observer_eci = GeodeticState.to_eci(observer, epoch)

    # Compute relative position vector (target - observer)
    {obs_pos, obs_vel} = ECIState.to_tensors(observer_eci)
    {tgt_pos, tgt_vel} = ECIState.to_tensors(target)

    rel_pos = Nx.subtract(tgt_pos, obs_pos)
    rel_vel = Nx.subtract(tgt_vel, obs_vel)

    [dx, dy, dz] = Nx.to_flat_list(rel_pos)
    [dvx, dvy, dvz] = Nx.to_flat_list(rel_vel)

    # Compute range
    range = :math.sqrt(dx * dx + dy * dy + dz * dz)

    # Compute RA and Dec
    # RA = atan2(y, x)
    # Dec = asin(z / r)
    ra = :math.atan2(dy, dx)
    ra = if ra < 0, do: ra + 2.0 * :math.pi(), else: ra

    dec = :math.asin(dz / range)

    base_opts = [range: range]

    # Compute rates if requested
    opts_with_rates =
      if Keyword.get(opts, :include_rates, false) do
        # Range rate: (r · v) / |r|
        range_rate = (dx * dvx + dy * dvy + dz * dvz) / range

        # RA rate: d/dt[atan2(y, x)] = (x*vy - y*vx) / (x^2 + y^2)
        xy_sq = dx * dx + dy * dy
        ra_rate = if xy_sq > 1.0e-10, do: (dx * dvy - dy * dvx) / xy_sq, else: 0.0

        # Dec rate: d/dt[asin(z/r)] = (vz*r - z*dr/dt) / (r^2 * sqrt(1 - (z/r)^2))
        cos_dec = :math.cos(dec)
        dec_rate =
          if cos_dec > 1.0e-10 do
            (dvz * range - dz * range_rate) / (range * range * cos_dec)
          else
            0.0
          end

        base_opts ++
          [range_rate: range_rate, right_ascension_rate: ra_rate, declination_rate: dec_rate]
      else
        base_opts
      end

    RaDec.new(epoch, ra, dec, opts_with_rates)
  end

  @doc """
  Compute RA/Dec of a target directly from ECI position (geocentric).

  This gives the geocentric RA/Dec (as seen from Earth's center),
  not topocentric (as seen from a ground observer).
  """
  @spec geocentric_ra_dec(ECIState.t()) :: RaDec.t()
  def geocentric_ra_dec(%ECIState{epoch: epoch, position: {x, y, z}}) do
    range = :math.sqrt(x * x + y * y + z * z)

    ra = :math.atan2(y, x)
    ra = if ra < 0, do: ra + 2.0 * :math.pi(), else: ra

    dec = :math.asin(z / range)

    RaDec.new(epoch, ra, dec, range: range)
  end

  # =============================================================================
  # Az/El Observations
  # =============================================================================

  @doc """
  Compute Az/El observation of a target from an observer.

  ## Parameters
    - observer: GeodeticState of the ground observer
    - target: ECIState of the target
    - opts: Optional parameters
      - :include_rates - Compute angular rates (default: false)

  ## Returns
    - AzEl observation struct

  ## Example
      observer = GeodeticState.new(40.0, -105.0, 1.6)
      target = ECIState.new(epoch, {7000.0, 0.0, 0.0}, {0.0, 7.5, 0.0})
      SpaceDust.Observations.compute_az_el(observer, target)
  """
  @spec compute_az_el(GeodeticState.t(), ECIState.t(), keyword()) :: AzEl.t()
  def compute_az_el(%GeodeticState{} = observer, %ECIState{epoch: epoch} = target, opts \\ []) do
    # Get observer ECEF position
    observer_ecef = GeodeticState.to_ecef(observer, epoch)

    # Convert target to ECEF
    target_ecef = Transforms.eci_to_ecef(target)

    # Compute relative position in ECEF
    {obs_x, obs_y, obs_z} = observer_ecef.position
    {tgt_x, tgt_y, tgt_z} = target_ecef.position

    rel_ecef = {tgt_x - obs_x, tgt_y - obs_y, tgt_z - obs_z}

    # Transform to SEZ (South-East-Zenith) local coordinates
    {south, east, zenith} = ecef_to_sez(rel_ecef, observer.latitude, observer.longitude)

    # Compute range
    range = :math.sqrt(south * south + east * east + zenith * zenith)

    # Compute Az and El
    # Azimuth is measured clockwise from North
    # In SEZ: North = -South, so Az = atan2(East, -South)
    az = :math.atan2(east, -south)
    az = if az < 0, do: az + 2.0 * :math.pi(), else: az

    # Elevation is angle above horizon
    el = :math.asin(zenith / range)

    base_opts = [range: range]

    # Compute rates if requested
    opts_with_rates =
      if Keyword.get(opts, :include_rates, false) do
        # Need relative velocity in ECEF and transform to SEZ
        {obs_vx, obs_vy, obs_vz} = observer_ecef.velocity
        {tgt_vx, tgt_vy, tgt_vz} = target_ecef.velocity

        rel_vel_ecef = {tgt_vx - obs_vx, tgt_vy - obs_vy, tgt_vz - obs_vz}
        {ds, de, dz_vel} = ecef_to_sez(rel_vel_ecef, observer.latitude, observer.longitude)

        # Range rate
        range_rate = (south * ds + east * de + zenith * dz_vel) / range

        # Azimuth rate: d/dt[atan2(E, -S)] = (-S*dE - E*(-dS)) / (S^2 + E^2)
        horiz_sq = south * south + east * east
        az_rate = if horiz_sq > 1.0e-10, do: (south * de - east * ds) / horiz_sq, else: 0.0

        # Elevation rate: d/dt[asin(Z/r)]
        cos_el = :math.cos(el)
        el_rate =
          if cos_el > 1.0e-10 do
            (dz_vel * range - zenith * range_rate) / (range * range * cos_el)
          else
            0.0
          end

        base_opts ++ [range_rate: range_rate, azimuth_rate: az_rate, elevation_rate: el_rate]
      else
        base_opts
      end

    AzEl.new(epoch, az, el, opts_with_rates)
  end

  # =============================================================================
  # Coordinate Conversions
  # =============================================================================

  @doc """
  Convert RA/Dec to Az/El for a given observer and time.
  """
  @spec ra_dec_to_az_el(RaDec.t(), GeodeticState.t()) :: AzEl.t()
  def ra_dec_to_az_el(%RaDec{epoch: epoch, right_ascension: ra, declination: dec} = ra_dec, %GeodeticState{} = observer) do
    lat_rad = observer.latitude * :math.pi() / 180.0

    # Get local sidereal time
    lst = GeodeticState.local_sidereal_time(observer, epoch)

    # Hour angle = LST - RA
    ha = lst - ra

    # Convert to Az/El
    sin_dec = :math.sin(dec)
    cos_dec = :math.cos(dec)
    sin_lat = :math.sin(lat_rad)
    cos_lat = :math.cos(lat_rad)
    sin_ha = :math.sin(ha)
    cos_ha = :math.cos(ha)

    # Elevation
    sin_el = sin_dec * sin_lat + cos_dec * cos_lat * cos_ha
    el = :math.asin(sin_el)

    # Azimuth
    cos_el = :math.cos(el)

    sin_az = -cos_dec * sin_ha / cos_el
    cos_az = (sin_dec - sin_lat * sin_el) / (cos_lat * cos_el)

    az = :math.atan2(sin_az, cos_az)
    az = if az < 0, do: az + 2.0 * :math.pi(), else: az

    opts = if ra_dec.range, do: [range: ra_dec.range], else: []
    AzEl.new(epoch, az, el, opts)
  end

  @doc """
  Convert Az/El to RA/Dec for a given observer and time.
  """
  @spec az_el_to_ra_dec(AzEl.t(), GeodeticState.t()) :: RaDec.t()
  def az_el_to_ra_dec(%AzEl{epoch: epoch, azimuth: az, elevation: el} = az_el, %GeodeticState{} = observer) do
    lat_rad = observer.latitude * :math.pi() / 180.0

    # Get local sidereal time
    lst = GeodeticState.local_sidereal_time(observer, epoch)

    sin_el = :math.sin(el)
    cos_el = :math.cos(el)
    sin_lat = :math.sin(lat_rad)
    cos_lat = :math.cos(lat_rad)
    sin_az = :math.sin(az)
    cos_az = :math.cos(az)

    # Declination
    sin_dec = sin_el * sin_lat + cos_el * cos_lat * cos_az
    dec = :math.asin(sin_dec)

    # Hour angle
    cos_dec = :math.cos(dec)
    sin_ha = -cos_el * sin_az / cos_dec
    cos_ha = (sin_el - sin_lat * sin_dec) / (cos_lat * cos_dec)
    ha = :math.atan2(sin_ha, cos_ha)

    # RA = LST - HA
    ra = lst - ha
    ra = :math.fmod(ra, 2.0 * :math.pi())
    ra = if ra < 0, do: ra + 2.0 * :math.pi(), else: ra

    opts = if az_el.range, do: [range: az_el.range], else: []
    RaDec.new(epoch, ra, dec, opts)
  end

  # =============================================================================
  # Line of Sight Vectors
  # =============================================================================

  @doc """
  Compute unit vector in ECI frame from RA/Dec.
  """
  @spec ra_dec_to_eci_direction(RaDec.t()) :: Vector.vector()
  def ra_dec_to_eci_direction(%RaDec{right_ascension: ra, declination: dec}) do
    cos_dec = :math.cos(dec)
    %Vector3D{
      x: cos_dec * :math.cos(ra),
      y: cos_dec * :math.sin(ra),
      z: :math.sin(dec)
    }
  end

  @doc """
  Compute unit vector in local SEZ frame from Az/El.
  """
  @spec az_el_to_sez_direction(AzEl.t()) :: Vector.vector()
  def az_el_to_sez_direction(%AzEl{azimuth: az, elevation: el}) do
    cos_el = :math.cos(el)
    # SEZ: South-East-Zenith
    # Az measured from North, clockwise
    %Vector3D{
      x: -cos_el * :math.cos(az),  # South = -North
      y: cos_el * :math.sin(az),   # East
      z: :math.sin(el)              # Zenith
    }
  end

  @doc """
  Compute line of sight unit vector in ECI frame from Az/El observation.
  """
  @spec az_el_to_eci_direction(AzEl.t(), GeodeticState.t()) :: Vector.vector()
  def az_el_to_eci_direction(%AzEl{epoch: epoch} = az_el, %GeodeticState{} = observer) do
    # Get SEZ direction
    sez_dir = az_el_to_sez_direction(az_el)

    # Convert SEZ to ECEF
    ecef_dir = sez_to_ecef({sez_dir.x, sez_dir.y, sez_dir.z}, observer.latitude, observer.longitude)

    # Convert ECEF to ECI
    nutation = SpaceDust.Bodies.Earth.nutationAngles(epoch)
    gast = nutation.gast

    {ex, ey, ez} = ecef_dir
    cos_gast = :math.cos(gast)
    sin_gast = :math.sin(gast)

    # ECEF to ECI rotation (inverse of ECI to ECEF)
    %Vector3D{
      x: ex * cos_gast - ey * sin_gast,
      y: ex * sin_gast + ey * cos_gast,
      z: ez
    }
  end

  # =============================================================================
  # Visibility Checks
  # =============================================================================

  @doc """
  Check if a target is visible from an observer (above horizon).
  
  Options:
    - `:min_elevation` - Minimum elevation angle in degrees (default: 0.0)
  """
  @spec is_visible?(GeodeticState.t(), ECIState.t(), keyword()) :: boolean()
  def is_visible?(observer, target, opts \\ [])

  def is_visible?(%GeodeticState{} = observer, %ECIState{} = target, opts) when is_list(opts) do
    min_el_deg = Keyword.get(opts, :min_elevation, 0.0)
    az_el = compute_az_el(observer, target)
    AzEl.above_elevation?(az_el, min_el_deg)
  end

  def is_visible?(%GeodeticState{} = observer, %ECIState{} = target, min_elevation_deg) when is_number(min_elevation_deg) do
    az_el = compute_az_el(observer, target)
    AzEl.above_elevation?(az_el, min_elevation_deg)
  end

  @doc """
  Compute the look angles and range from observer to target.
  Returns {az_deg, el_deg, range_km}.
  """
  @spec look_angles(GeodeticState.t(), ECIState.t()) :: {float(), float(), float()}
  def look_angles(%GeodeticState{} = observer, %ECIState{} = target) do
    az_el = compute_az_el(observer, target)
    {az_deg, el_deg} = AzEl.to_degrees(az_el)
    {az_deg, el_deg, az_el.range}
  end

  # =============================================================================
  # Internal Helper Functions
  # =============================================================================

  # Transform ECEF vector to SEZ (South-East-Zenith) local frame
  defp ecef_to_sez({x, y, z}, lat_deg, lon_deg) do
    lat_rad = lat_deg * :math.pi() / 180.0
    lon_rad = lon_deg * :math.pi() / 180.0

    sin_lat = :math.sin(lat_rad)
    cos_lat = :math.cos(lat_rad)
    sin_lon = :math.sin(lon_rad)
    cos_lon = :math.cos(lon_rad)

    # Rotation matrix ECEF -> SEZ
    # S = sin(lat)*cos(lon)*x + sin(lat)*sin(lon)*y - cos(lat)*z
    # E = -sin(lon)*x + cos(lon)*y
    # Z = cos(lat)*cos(lon)*x + cos(lat)*sin(lon)*y + sin(lat)*z

    south = sin_lat * cos_lon * x + sin_lat * sin_lon * y - cos_lat * z
    east = -sin_lon * x + cos_lon * y
    zenith = cos_lat * cos_lon * x + cos_lat * sin_lon * y + sin_lat * z

    {south, east, zenith}
  end

  # Transform SEZ vector to ECEF
  defp sez_to_ecef({south, east, zenith}, lat_deg, lon_deg) do
    lat_rad = lat_deg * :math.pi() / 180.0
    lon_rad = lon_deg * :math.pi() / 180.0

    sin_lat = :math.sin(lat_rad)
    cos_lat = :math.cos(lat_rad)
    sin_lon = :math.sin(lon_rad)
    cos_lon = :math.cos(lon_rad)

    # Inverse rotation matrix SEZ -> ECEF
    x = sin_lat * cos_lon * south - sin_lon * east + cos_lat * cos_lon * zenith
    y = sin_lat * sin_lon * south + cos_lon * east + cos_lat * sin_lon * zenith
    z = -cos_lat * south + sin_lat * zenith

    {x, y, z}
  end
end
