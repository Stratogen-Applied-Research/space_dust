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
  Build the precession matrix from precession angles.
  Transforms from Mean of Date (MOD) to J2000.
  """
  defn precession_matrix(zeta, theta, z) do
    # P = Rz(-z) * Ry(theta) * Rz(-zeta)
    rz_neg_zeta = rotation_z(Nx.negate(zeta))
    ry_theta = rotation_y(theta)
    rz_neg_z = rotation_z(Nx.negate(z))

    multiply_matrices(rz_neg_z, multiply_matrices(ry_theta, rz_neg_zeta))
  end

  @doc """
  Build the nutation matrix from nutation angles.
  Transforms from True of Date (TOD) to Mean of Date (MOD).
  """
  defn nutation_matrix(mean_eps, delta_psi, delta_eps) do
    eps = mean_eps + delta_eps

    # N = Rx(mean_eps) * Rz(delta_psi) * Rx(-eps)
    rx_mean_eps = rotation_x(mean_eps)
    rz_delta_psi = rotation_z(delta_psi)
    rx_neg_eps = rotation_x(Nx.negate(eps))

    multiply_matrices(rx_mean_eps, multiply_matrices(rz_delta_psi, rx_neg_eps))
  end

  @doc """
  Build the equation of equinoxes rotation matrix.
  Transforms from TEME to True of Date (TOD).
  """
  defn equinox_matrix(delta_psi, eps) do
    # The equation of equinoxes term: delta_psi * cos(eps)
    eq_eq = delta_psi * Nx.cos(eps)
    rotation_z(Nx.negate(eq_eq))
  end

  @doc """
  Perform the full TEME to ECI J2000 transformation on position/velocity tensors.
  """
  defn teme_to_eci_tensors(pos, vel, zeta, theta, z, mean_eps, delta_psi, delta_eps) do
    eps = mean_eps + delta_eps

    # Build transformation matrices
    eq_mat = equinox_matrix(delta_psi, eps)
    nut_mat = nutation_matrix(mean_eps, delta_psi, delta_eps)
    prec_mat = precession_matrix(zeta, theta, z)

    # Combined transformation: P * N * E
    combined = multiply_matrices(prec_mat, multiply_matrices(nut_mat, eq_mat))

    # Apply to position and velocity
    pos_eci = apply_rotation(combined, pos)
    vel_eci = apply_rotation(combined, vel)

    {pos_eci, vel_eci}
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
    # Get precession and nutation angles from Earth module
    precession = Earth.precessionAngles(epoch)
    nutation = Earth.nutationAngles(epoch)

    # Convert to tensors
    {pos, vel} = TEMEState.to_tensors(teme_state)

    # Build angle tensors
    zeta = Nx.tensor(precession.zeta, type: :f64)
    theta = Nx.tensor(precession.theta, type: :f64)
    z = Nx.tensor(precession.z, type: :f64)
    mean_eps = Nx.tensor(nutation.mEps, type: :f64)
    delta_psi = Nx.tensor(nutation.dPsi, type: :f64)
    delta_eps = Nx.tensor(nutation.dEps, type: :f64)

    # Perform transformation
    {pos_eci, vel_eci} = teme_to_eci_tensors(pos, vel, zeta, theta, z, mean_eps, delta_psi, delta_eps)

    ECIState.from_tensors(epoch, pos_eci, vel_eci)
  end

  # =============================================================================
  # ECI J2000 to TEME Transformation (inverse)
  # =============================================================================

  @doc """
  Perform the full ECI J2000 to TEME transformation on position/velocity tensors.
  """
  defn eci_to_teme_tensors(pos, vel, zeta, theta, z, mean_eps, delta_psi, delta_eps) do
    eps = mean_eps + delta_eps

    # Build transformation matrices (transposed for inverse)
    eq_mat = Nx.transpose(equinox_matrix(delta_psi, eps))
    nut_mat = Nx.transpose(nutation_matrix(mean_eps, delta_psi, delta_eps))
    prec_mat = Nx.transpose(precession_matrix(zeta, theta, z))

    # Combined transformation: E^T * N^T * P^T
    combined = multiply_matrices(eq_mat, multiply_matrices(nut_mat, prec_mat))

    # Apply to position and velocity
    pos_teme = apply_rotation(combined, pos)
    vel_teme = apply_rotation(combined, vel)

    {pos_teme, vel_teme}
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
    # Get precession and nutation angles from Earth module
    precession = Earth.precessionAngles(epoch)
    nutation = Earth.nutationAngles(epoch)

    # Convert to tensors
    {pos, vel} = ECIState.to_tensors(eci_state)

    # Build angle tensors
    zeta = Nx.tensor(precession.zeta, type: :f64)
    theta = Nx.tensor(precession.theta, type: :f64)
    z = Nx.tensor(precession.z, type: :f64)
    mean_eps = Nx.tensor(nutation.mEps, type: :f64)
    delta_psi = Nx.tensor(nutation.dPsi, type: :f64)
    delta_eps = Nx.tensor(nutation.dEps, type: :f64)

    # Perform transformation
    {pos_teme, vel_teme} = eci_to_teme_tensors(pos, vel, zeta, theta, z, mean_eps, delta_psi, delta_eps)

    TEMEState.from_tensors(epoch, pos_teme, vel_teme)
  end

  # =============================================================================
  # ECI to ECEF Transformation
  # =============================================================================

  @doc """
  Perform ECI to ECEF transformation on position/velocity tensors.
  Accounts for Earth rotation and velocity contribution from rotation.
  """
  defn eci_to_ecef_tensors(pos, vel, gast, omega) do
    # Rotation matrix from ECI to ECEF
    rot = rotation_z(gast)

    # Position transformation is straightforward
    pos_ecef = apply_rotation(rot, pos)

    # Velocity needs correction for Earth's rotation
    # v_ecef = R * v_eci - omega x r_ecef
    vel_rotated = apply_rotation(rot, vel)

    # omega cross r_ecef (omega is along z-axis)
    omega_cross_r = Nx.stack([
      Nx.negate(omega) * pos_ecef[1],
      omega * pos_ecef[0],
      Nx.tensor(0.0, type: :f64)
    ])

    vel_ecef = vel_rotated - omega_cross_r

    {pos_ecef, vel_ecef}
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
    # Get GAST (Greenwich Apparent Sidereal Time)
    nutation = Earth.nutationAngles(epoch)
    gast = Nx.tensor(nutation.gast, type: :f64)
    omega = Nx.tensor(@earth_omega, type: :f64)

    # Convert to tensors
    {pos, vel} = ECIState.to_tensors(eci_state)

    # Perform transformation
    {pos_ecef, vel_ecef} = eci_to_ecef_tensors(pos, vel, gast, omega)

    ECEFState.from_tensors(epoch, pos_ecef, vel_ecef)
  end

  # =============================================================================
  # ECEF to ECI Transformation (inverse)
  # =============================================================================

  @doc """
  Perform ECEF to ECI transformation on position/velocity tensors.
  """
  defn ecef_to_eci_tensors(pos, vel, gast, omega) do
    # Inverse rotation matrix (transpose of Rz)
    rot_inv = Nx.transpose(rotation_z(gast))

    # First correct velocity for Earth's rotation
    # v_eci = R^T * (v_ecef + omega x r_ecef)
    omega_cross_r = Nx.stack([
      Nx.negate(omega) * pos[1],
      omega * pos[0],
      Nx.tensor(0.0, type: :f64)
    ])

    vel_corrected = vel + omega_cross_r

    # Apply rotation
    pos_eci = apply_rotation(rot_inv, pos)
    vel_eci = apply_rotation(rot_inv, vel_corrected)

    {pos_eci, vel_eci}
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
    # Get GAST (Greenwich Apparent Sidereal Time)
    nutation = Earth.nutationAngles(epoch)
    gast = Nx.tensor(nutation.gast, type: :f64)
    omega = Nx.tensor(@earth_omega, type: :f64)

    # Convert to tensors
    {pos, vel} = ECEFState.to_tensors(ecef_state)

    # Perform transformation
    {pos_eci, vel_eci} = ecef_to_eci_tensors(pos, vel, gast, omega)

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

  @doc """
  Convert Cartesian state to Keplerian elements using Nx.
  """
  defn cartesian_to_keplerian_tensors(pos, vel, mu) do
    # Position and velocity magnitudes
    r = Nx.sqrt(Nx.sum(pos * pos))
    v = Nx.sqrt(Nx.sum(vel * vel))

    # Specific angular momentum h = r x v
    h = Nx.stack([
      pos[1] * vel[2] - pos[2] * vel[1],
      pos[2] * vel[0] - pos[0] * vel[2],
      pos[0] * vel[1] - pos[1] * vel[0]
    ])
    h_mag = Nx.sqrt(Nx.sum(h * h))

    # Node vector n = k x h (k is z-unit vector)
    n = Nx.stack([Nx.negate(h[1]), h[0], Nx.tensor(0.0, type: :f64)])
    n_mag = Nx.sqrt(Nx.sum(n * n))

    # Eccentricity vector e = ((v^2 - mu/r)*r - (r.v)*v) / mu
    rdotv = Nx.sum(pos * vel)
    e_vec = ((v * v - mu / r) * pos - rdotv * vel) / mu
    e = Nx.sqrt(Nx.sum(e_vec * e_vec))

    # Semi-major axis
    energy = v * v / 2.0 - mu / r
    a = Nx.negate(mu) / (2.0 * energy)

    # Inclination
    i = Nx.acos(h[2] / h_mag)

    # RAAN (Right Ascension of Ascending Node)
    # Handle case when n_mag is near zero (equatorial orbit)
    raan = Nx.select(
      n_mag > 1.0e-10,
      Nx.select(n[1] >= 0, Nx.acos(n[0] / n_mag), 2.0 * Nx.Constants.pi() - Nx.acos(n[0] / n_mag)),
      Nx.tensor(0.0, type: :f64)
    )

    # Argument of perigee
    n_dot_e = Nx.sum(n * e_vec)
    w = Nx.select(
      n_mag > 1.0e-10 and e > 1.0e-10,
      Nx.select(e_vec[2] >= 0, Nx.acos(n_dot_e / (n_mag * e)), 2.0 * Nx.Constants.pi() - Nx.acos(n_dot_e / (n_mag * e))),
      Nx.tensor(0.0, type: :f64)
    )

    # True anomaly
    e_dot_r = Nx.sum(e_vec * pos)
    nu = Nx.select(
      e > 1.0e-10,
      Nx.select(rdotv >= 0, Nx.acos(e_dot_r / (e * r)), 2.0 * Nx.Constants.pi() - Nx.acos(e_dot_r / (e * r))),
      Nx.tensor(0.0, type: :f64)
    )

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
