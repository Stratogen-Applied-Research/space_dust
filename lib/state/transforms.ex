defmodule SpaceDust.State.Transforms do
  @moduledoc """
  High-performance state vector transformations using Nx.

  Provides coordinate frame transformations between:
  - TEME (True Equator Mean Equinox) - SGP4 output frame
  - ECI J2000 (Earth-Centered Inertial) - Standard inertial frame
  - ECEF (Earth-Centered Earth-Fixed) - Rotating with Earth

  Also provides conversions between:
  - Cartesian state vectors and Keplerian elements
  """

  import Nx.Defn

  alias SpaceDust.State.TEMEState
  alias SpaceDust.State.ECIState
  alias SpaceDust.State.ECEFState
  alias SpaceDust.State.KeplerianElements
  alias SpaceDust.Bodies.Earth

  # Earth's gravitational parameter in km^3/s^2
  @earth_mu 398600.4418

  # Earth's rotation rate in rad/s
  @earth_omega 7.292115e-5

  # =============================================================================
  # Rotation Matrix Builders (Nx.defn for GPU/TPU acceleration)
  # =============================================================================

  @doc """
  Build a rotation matrix about the X-axis.
  """
  defn rotation_x(angle) do
    c = Nx.cos(angle)
    s = Nx.sin(angle)
    zero = Nx.tensor(0.0, type: :f64)
    one = Nx.tensor(1.0, type: :f64)

    Nx.stack([
      Nx.stack([one, zero, zero]),
      Nx.stack([zero, c, s]),
      Nx.stack([zero, Nx.negate(s), c])
    ])
  end

  @doc """
  Build a rotation matrix about the Y-axis.
  """
  defn rotation_y(angle) do
    c = Nx.cos(angle)
    s = Nx.sin(angle)
    zero = Nx.tensor(0.0, type: :f64)
    one = Nx.tensor(1.0, type: :f64)

    Nx.stack([
      Nx.stack([c, zero, Nx.negate(s)]),
      Nx.stack([zero, one, zero]),
      Nx.stack([s, zero, c])
    ])
  end

  @doc """
  Build a rotation matrix about the Z-axis.
  """
  defn rotation_z(angle) do
    c = Nx.cos(angle)
    s = Nx.sin(angle)
    zero = Nx.tensor(0.0, type: :f64)
    one = Nx.tensor(1.0, type: :f64)

    Nx.stack([
      Nx.stack([c, s, zero]),
      Nx.stack([Nx.negate(s), c, zero]),
      Nx.stack([zero, zero, one])
    ])
  end

  @doc """
  Apply a rotation matrix to a vector.
  """
  defn apply_rotation(matrix, vector) do
    Nx.dot(matrix, vector)
  end

  @doc """
  Multiply two 3x3 rotation matrices.
  """
  defn multiply_matrices(a, b) do
    Nx.dot(a, b)
  end

  # =============================================================================
  # TEME to ECI J2000 Transformation
  # =============================================================================

  @doc """
  Build the IAU 1976 precession matrix.

  Transforms **from J2000 to Mean of Date (MOD)**. Transpose it for the other
  direction. `rotation_x/y/z` here are passive (frame) rotations, so this is
  Vallado's `ROT3(-z) ROT2(theta) ROT3(-zeta)`.
  """
  defn precession_matrix(zeta, theta, z) do
    multiply_matrices(
      rotation_z(Nx.negate(z)),
      multiply_matrices(rotation_y(theta), rotation_z(Nx.negate(zeta)))
    )
  end

  @doc """
  Build the IAU 1980 nutation matrix.

  Transforms **from Mean of Date (MOD) to True of Date (TOD)**, as
  `ROT1(-eps_true) ROT3(-delta_psi) ROT1(eps_mean)`. Transpose it for TOD to MOD.
  """
  defn nutation_matrix(mean_eps, delta_psi, delta_eps) do
    eps = mean_eps + delta_eps

    multiply_matrices(
      rotation_x(Nx.negate(eps)),
      multiply_matrices(rotation_z(Nx.negate(delta_psi)), rotation_x(mean_eps))
    )
  end

  @doc """
  Build the nutation matrix in SGP4's TEME convention.

  Transforms **from Mean of Date (MOD) to TEME**. TEME is not true-of-date: it
  uses the *mean* obliquity on both sides of the nutation rotation and carries
  no separate equation-of-equinoxes step. That is SGP4's own convention and it
  has to be matched exactly, or a TLE-derived state lands kilometers off.
  """
  defn teme_nutation_matrix(mean_eps, delta_psi) do
    multiply_matrices(
      rotation_x(Nx.negate(mean_eps)),
      multiply_matrices(rotation_z(Nx.negate(delta_psi)), rotation_x(mean_eps))
    )
  end

  @doc """
  Build the polar motion matrix from the IERS pole offsets, in radians.

  Transforms **from the pseudo-earth-fixed frame (PEF) to ECEF**, as
  `ROT2(xp) ROT1(yp)`.
  """
  defn polar_motion_matrix(xp, yp) do
    multiply_matrices(rotation_y(xp), rotation_x(yp))
  end

  @doc """
  Build the equation of equinoxes rotation, from TEME to True of Date.

  Retained for callers working in TOD. It is deliberately **not** part of the
  TEME transform below, which uses `teme_nutation_matrix/2` instead.
  """
  defn equinox_matrix(delta_psi, eps) do
    eq_eq = delta_psi * Nx.cos(eps)
    rotation_z(Nx.negate(eq_eq))
  end

  @doc """
  Perform the full TEME to ECI J2000 transformation on position/velocity tensors.

  `r_teme = N_teme * P * r_j2000`, so the inverse applied here is
  `P^T * N_teme^T`.
  """
  defn teme_to_eci_tensors(pos, vel, zeta, theta, z, mean_eps, delta_psi) do
    combined =
      multiply_matrices(
        Nx.transpose(precession_matrix(zeta, theta, z)),
        Nx.transpose(teme_nutation_matrix(mean_eps, delta_psi))
      )

    {apply_rotation(combined, pos), apply_rotation(combined, vel)}
  end

  @doc """
  Convert a TEME state to ECI J2000.

  ## Parameters
    - teme_state: TEMEState struct with position/velocity in TEME frame

  ## Returns
    - ECIState struct with position/velocity in ECI J2000 frame
  """
  @spec teme_to_eci(TEMEState.t()) :: ECIState.t()
  def teme_to_eci(%TEMEState{epoch: epoch} = teme_state) do
    precession = Earth.precessionAngles(epoch)
    nutation = Earth.nutationAngles(epoch)

    {pos, vel} = TEMEState.to_tensors(teme_state)

    zeta = Nx.tensor(precession.zeta, type: :f64)
    theta = Nx.tensor(precession.theta, type: :f64)
    z = Nx.tensor(precession.z, type: :f64)
    mean_eps = Nx.tensor(nutation.mEps, type: :f64)
    delta_psi = Nx.tensor(nutation.dPsi, type: :f64)

    {pos_eci, vel_eci} = teme_to_eci_tensors(pos, vel, zeta, theta, z, mean_eps, delta_psi)

    ECIState.from_tensors(epoch, pos_eci, vel_eci)
  end

  # =============================================================================
  # ECI J2000 to TEME Transformation (inverse)
  # =============================================================================

  @doc """
  Perform the full ECI J2000 to TEME transformation on position/velocity tensors.

  `r_teme = N_teme * P * r_j2000`.
  """
  defn eci_to_teme_tensors(pos, vel, zeta, theta, z, mean_eps, delta_psi) do
    combined =
      multiply_matrices(
        teme_nutation_matrix(mean_eps, delta_psi),
        precession_matrix(zeta, theta, z)
      )

    {apply_rotation(combined, pos), apply_rotation(combined, vel)}
  end

  @doc """
  Convert an ECI J2000 state to TEME.

  ## Parameters
    - eci_state: ECIState struct with position/velocity in ECI J2000 frame

  ## Returns
    - TEMEState struct with position/velocity in TEME frame
  """
  @spec eci_to_teme(ECIState.t()) :: TEMEState.t()
  def eci_to_teme(%ECIState{epoch: epoch} = eci_state) do
    precession = Earth.precessionAngles(epoch)
    nutation = Earth.nutationAngles(epoch)

    {pos, vel} = ECIState.to_tensors(eci_state)

    zeta = Nx.tensor(precession.zeta, type: :f64)
    theta = Nx.tensor(precession.theta, type: :f64)
    z = Nx.tensor(precession.z, type: :f64)
    mean_eps = Nx.tensor(nutation.mEps, type: :f64)
    delta_psi = Nx.tensor(nutation.dPsi, type: :f64)

    {pos_teme, vel_teme} = eci_to_teme_tensors(pos, vel, zeta, theta, z, mean_eps, delta_psi)

    TEMEState.from_tensors(epoch, pos_teme, vel_teme)
  end

  # =============================================================================
  # ECI to ECEF Transformation
  # =============================================================================

  @doc """
  Build the full `W * R * N * P` rotation taking an ECI J2000 vector to ECEF.

  Four rotations, in this order applied to a J2000 vector:

    * `P` - precession, J2000 to mean of date
    * `N` - nutation, mean of date to true of date
    * `R` - Earth rotation through the Greenwich apparent sidereal time
    * `W` - polar motion, pseudo-earth-fixed to ECEF

  Skipping `N` and `P` and applying `R` alone to a J2000 vector leaves the
  result short by the accumulated precession - roughly 0.4 degrees, or 645 km
  at geostationary radius.
  """
  defn eci_to_ecef_matrix(zeta, theta, z, mean_eps, delta_psi, delta_eps, gast, xp, yp) do
    multiply_matrices(
      multiply_matrices(polar_motion_matrix(xp, yp), rotation_z(gast)),
      multiply_matrices(
        nutation_matrix(mean_eps, delta_psi, delta_eps),
        precession_matrix(zeta, theta, z)
      )
    )
  end

  @doc """
  Perform ECI to ECEF transformation on position/velocity tensors.
  Accounts for Earth rotation and velocity contribution from rotation.
  """
  defn eci_to_ecef_tensors(pos, vel, rot, omega) do
    pos_ecef = apply_rotation(rot, pos)

    # v_ecef = M * v_eci - omega x r_ecef, with omega along the ECEF z-axis.
    # The time derivatives of W, N and P are neglected: they are eleven orders
    # of magnitude below Earth's rotation rate.
    omega_cross_r =
      Nx.stack([
        Nx.negate(omega) * pos_ecef[1],
        omega * pos_ecef[0],
        Nx.tensor(0.0, type: :f64)
      ])

    {pos_ecef, apply_rotation(rot, vel) - omega_cross_r}
  end

  @doc """
  Convert an ECI J2000 state to ECEF.

  ## Parameters
    - eci_state: ECIState struct with position/velocity in ECI J2000 frame

  ## Returns
    - ECEFState struct with position/velocity in ECEF frame
  """
  @spec eci_to_ecef(ECIState.t()) :: ECEFState.t()
  def eci_to_ecef(%ECIState{epoch: epoch} = eci_state) do
    rot = eci_to_ecef_matrix_at(epoch)
    omega = Nx.tensor(@earth_omega, type: :f64)

    {pos, vel} = ECIState.to_tensors(eci_state)
    {pos_ecef, vel_ecef} = eci_to_ecef_tensors(pos, vel, rot, omega)

    ECEFState.from_tensors(epoch, pos_ecef, vel_ecef)
  end

  @doc """
  The `W * R * N * P` ECI J2000 to ECEF rotation matrix at an epoch, as a tensor.

  Exposed for callers that need to rotate a bare direction, where the
  `omega x r` velocity coupling in `eci_to_ecef/1` would be meaningless.
  """
  @spec eci_to_ecef_matrix_at(DateTime.t()) :: Nx.Tensor.t()
  def eci_to_ecef_matrix_at(epoch) do
    precession = Earth.precessionAngles(epoch)
    nutation = Earth.nutationAngles(epoch)
    {xp, yp} = Earth.polarMotion(epoch)

    eci_to_ecef_matrix(
      Nx.tensor(precession.zeta, type: :f64),
      Nx.tensor(precession.theta, type: :f64),
      Nx.tensor(precession.z, type: :f64),
      Nx.tensor(nutation.mEps, type: :f64),
      Nx.tensor(nutation.dPsi, type: :f64),
      Nx.tensor(nutation.dEps, type: :f64),
      Nx.tensor(nutation.gast, type: :f64),
      Nx.tensor(xp, type: :f64),
      Nx.tensor(yp, type: :f64)
    )
  end

  # =============================================================================
  # ECEF to ECI Transformation (inverse)
  # =============================================================================

  @doc """
  Perform ECEF to ECI transformation on position/velocity tensors.
  """
  defn ecef_to_eci_tensors(pos, vel, rot, omega) do
    rot_inv = Nx.transpose(rot)

    # v_eci = M^T * (v_ecef + omega x r_ecef)
    omega_cross_r =
      Nx.stack([
        Nx.negate(omega) * pos[1],
        omega * pos[0],
        Nx.tensor(0.0, type: :f64)
      ])

    {apply_rotation(rot_inv, pos), apply_rotation(rot_inv, vel + omega_cross_r)}
  end

  @doc """
  Convert an ECEF state to ECI J2000.

  ## Parameters
    - ecef_state: ECEFState struct with position/velocity in ECEF frame

  ## Returns
    - ECIState struct with position/velocity in ECI J2000 frame
  """
  @spec ecef_to_eci(ECEFState.t()) :: ECIState.t()
  def ecef_to_eci(%ECEFState{epoch: epoch} = ecef_state) do
    rot = eci_to_ecef_matrix_at(epoch)
    omega = Nx.tensor(@earth_omega, type: :f64)

    {pos, vel} = ECEFState.to_tensors(ecef_state)
    {pos_eci, vel_eci} = ecef_to_eci_tensors(pos, vel, rot, omega)

    ECIState.from_tensors(epoch, pos_eci, vel_eci)
  end

  # =============================================================================
  # TEME to ECEF (via ECI)
  # =============================================================================

  @doc """
  Convert a TEME state to ECEF.

  ## Parameters
    - teme_state: TEMEState struct with position/velocity in TEME frame

  ## Returns
    - ECEFState struct with position/velocity in ECEF frame
  """
  @spec teme_to_ecef(TEMEState.t()) :: ECEFState.t()
  def teme_to_ecef(%TEMEState{} = teme_state) do
    teme_state
    |> teme_to_eci()
    |> eci_to_ecef()
  end

  @doc """
  Convert an ECEF state to TEME.

  ## Parameters
    - ecef_state: ECEFState struct with position/velocity in ECEF frame

  ## Returns
    - TEMEState struct with position/velocity in TEME frame
  """
  @spec ecef_to_teme(ECEFState.t()) :: TEMEState.t()
  def ecef_to_teme(%ECEFState{} = ecef_state) do
    ecef_state
    |> ecef_to_eci()
    |> eci_to_teme()
  end

  # =============================================================================
  # Cartesian to Keplerian Elements Conversion
  # =============================================================================

  # Cross product of two 3-vectors.
  defnp cross3(a, b) do
    Nx.stack([
      a[1] * b[2] - a[2] * b[1],
      a[2] * b[0] - a[0] * b[2],
      a[0] * b[1] - a[1] * b[0]
    ])
  end

  # Normalize, guarding against a zero-length input so the result is finite even
  # when the caller is about to discard it via Nx.select.
  defnp safe_normalize(v) do
    v / Nx.max(Nx.sqrt(Nx.sum(v * v)), 1.0e-300)
  end

  # Signed angle from `from` to `to`, measured right-handed about `axis`, in
  # [0, 2*pi). All three must be unit vectors.
  #
  # This is atan2-based on purpose. The acos form needs its argument clamped or
  # it raises on a rounding excursion past +/-1, which happens routinely for
  # near-degenerate geometry.
  defnp angle_about(from, to, axis) do
    angle = Nx.atan2(Nx.sum(axis * cross3(from, to)), Nx.sum(from * to))
    Nx.select(angle < 0.0, angle + 2.0 * Nx.Constants.pi(), angle)
  end

  @doc """
  Convert Cartesian state to Keplerian elements using Nx.

  Degenerate geometry is handled by falling back to a reference direction that
  is still defined, rather than by reporting zero and losing the information:

    * equatorial - the ascending node is undefined, so the argument of perigee
      is measured from the vernal equinox and the RAAN reported as zero
    * circular - perigee is undefined, so the true anomaly is measured from
      whatever the argument of perigee was measured from

  Both keep the round trip through `keplerian_to_eci/1` exact. Reporting zero
  for all three angles instead, as an equatorial orbit would otherwise get,
  puts the reconstructed position a full orbit radius away.
  """
  defn cartesian_to_keplerian_tensors(pos, vel, mu) do
    r = Nx.sqrt(Nx.sum(pos * pos))
    v_sq = Nx.sum(vel * vel)
    rdotv = Nx.sum(pos * vel)

    # Specific angular momentum h = r x v
    h = cross3(pos, vel)
    h_mag = Nx.sqrt(Nx.sum(h * h))

    # Node vector n = k x h, pointing at the ascending node
    n = Nx.stack([Nx.negate(h[1]), h[0], Nx.tensor(0.0, type: :f64)])
    n_mag = Nx.sqrt(Nx.sum(n * n))

    # Eccentricity vector e = ((v^2 - mu/r)*r - (r.v)*v) / mu
    e_vec = ((v_sq - mu / r) * pos - rdotv * vel) / mu
    e = Nx.sqrt(Nx.sum(e_vec * e_vec))

    energy = v_sq / 2.0 - mu / r
    a = Nx.negate(mu) / (2.0 * energy)

    i = Nx.acos(Nx.clip(h[2] / h_mag, -1.0, 1.0))

    # The node threshold is relative to |h| because n is a component of it.
    node_defined = n_mag > 1.0e-12 * h_mag
    perigee_defined = e > 1.0e-12

    x_hat = Nx.tensor([1.0, 0.0, 0.0], type: :f64)
    z_hat = Nx.tensor([0.0, 0.0, 1.0], type: :f64)
    orbit_normal = safe_normalize(h)
    n_hat = safe_normalize(n)
    e_hat = safe_normalize(e_vec)

    raan = Nx.select(node_defined, angle_about(x_hat, n_hat, z_hat), 0.0)

    # Whatever the argument of perigee is measured from - the node when there
    # is one, the vernal equinox when there is not. That choice is exactly what
    # raan reported above, so the two stay consistent.
    perigee_ref = Nx.select(node_defined, n_hat, x_hat)

    w = Nx.select(perigee_defined, angle_about(perigee_ref, e_hat, orbit_normal), 0.0)

    anomaly_ref = Nx.select(perigee_defined, e_hat, perigee_ref)
    nu = angle_about(anomaly_ref, safe_normalize(pos), orbit_normal)

    Nx.stack([a, e, i, raan, w, nu])
  end

  @doc """
  Convert a Cartesian state (ECI) to Keplerian elements.

  ## Parameters
    - state: ECIState, TEMEState, or ECEFState struct
    - opts: Options including :mu for gravitational parameter

  ## Returns
    - KeplerianElements struct
  """
  @spec to_keplerian(ECIState.t() | TEMEState.t(), keyword()) :: KeplerianElements.t()
  def to_keplerian(state, opts \\ [])

  def to_keplerian(%ECIState{epoch: epoch} = state, opts) do
    mu = Keyword.get(opts, :mu, @earth_mu)
    {pos, vel} = ECIState.to_tensors(state)
    mu_tensor = Nx.tensor(mu, type: :f64)

    elements_tensor = cartesian_to_keplerian_tensors(pos, vel, mu_tensor)
    KeplerianElements.from_tensor(elements_tensor, epoch: epoch, mu: mu)
  end

  def to_keplerian(%TEMEState{} = state, opts) do
    state
    |> teme_to_eci()
    |> to_keplerian(opts)
  end

  # =============================================================================
  # Keplerian Elements to Cartesian Conversion
  # =============================================================================

  @doc """
  Convert Keplerian elements to Cartesian state using Nx.
  """
  defn keplerian_to_cartesian_tensors(elements, mu) do
    a = elements[0]
    e = elements[1]
    i = elements[2]
    raan = elements[3]
    w = elements[4]
    nu = elements[5]

    # Semi-latus rectum
    p = a * (1.0 - e * e)

    # Position and velocity in perifocal frame
    cos_nu = Nx.cos(nu)
    sin_nu = Nx.sin(nu)

    r_mag = p / (1.0 + e * cos_nu)

    # Position in perifocal frame
    r_pf = Nx.stack([r_mag * cos_nu, r_mag * sin_nu, Nx.tensor(0.0, type: :f64)])

    # Velocity in perifocal frame
    sqrt_mu_p = Nx.sqrt(mu / p)
    v_pf = Nx.stack([
      Nx.negate(sqrt_mu_p) * sin_nu,
      sqrt_mu_p * (e + cos_nu),
      Nx.tensor(0.0, type: :f64)
    ])

    # Rotation matrices
    cos_raan = Nx.cos(raan)
    sin_raan = Nx.sin(raan)
    cos_w = Nx.cos(w)
    sin_w = Nx.sin(w)
    cos_i = Nx.cos(i)
    sin_i = Nx.sin(i)

    # Combined rotation matrix from perifocal to inertial
    # R = Rz(-RAAN) * Rx(-i) * Rz(-w)
    r11 = cos_raan * cos_w - sin_raan * sin_w * cos_i
    r12 = Nx.negate(cos_raan * sin_w) - sin_raan * cos_w * cos_i
    r13 = sin_raan * sin_i
    r21 = sin_raan * cos_w + cos_raan * sin_w * cos_i
    r22 = Nx.negate(sin_raan * sin_w) + cos_raan * cos_w * cos_i
    r23 = Nx.negate(cos_raan) * sin_i
    r31 = sin_w * sin_i
    r32 = cos_w * sin_i
    r33 = cos_i

    # Apply rotation to position
    pos = Nx.stack([
      r11 * r_pf[0] + r12 * r_pf[1] + r13 * r_pf[2],
      r21 * r_pf[0] + r22 * r_pf[1] + r23 * r_pf[2],
      r31 * r_pf[0] + r32 * r_pf[1] + r33 * r_pf[2]
    ])

    # Apply rotation to velocity
    vel = Nx.stack([
      r11 * v_pf[0] + r12 * v_pf[1] + r13 * v_pf[2],
      r21 * v_pf[0] + r22 * v_pf[1] + r23 * v_pf[2],
      r31 * v_pf[0] + r32 * v_pf[1] + r33 * v_pf[2]
    ])

    {pos, vel}
  end

  @doc """
  Convert Keplerian elements to an ECI state.

  ## Parameters
    - elements: KeplerianElements struct

  ## Returns
    - ECIState struct with position/velocity in ECI J2000 frame
  """
  @spec keplerian_to_eci(KeplerianElements.t()) :: ECIState.t()
  def keplerian_to_eci(%KeplerianElements{epoch: epoch, mu: mu} = elements) do
    mu = mu || @earth_mu
    elements_tensor = KeplerianElements.to_tensor(elements)
    mu_tensor = Nx.tensor(mu, type: :f64)

    {pos, vel} = keplerian_to_cartesian_tensors(elements_tensor, mu_tensor)

    ECIState.from_tensors(epoch || DateTime.utc_now(), pos, vel)
  end

  @doc """
  Convert Keplerian elements to a TEME state.

  ## Parameters
    - elements: KeplerianElements struct

  ## Returns
    - TEMEState struct with position/velocity in TEME frame
  """
  @spec keplerian_to_teme(KeplerianElements.t()) :: TEMEState.t()
  def keplerian_to_teme(%KeplerianElements{} = elements) do
    elements
    |> keplerian_to_eci()
    |> eci_to_teme()
  end
end
