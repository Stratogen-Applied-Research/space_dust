defmodule SpaceDust.State.KeplerianElements do
  @moduledoc """
  Classical Keplerian orbital elements.

  Represents an orbit using the six classical orbital elements:
  - Semi-major axis (a): Size of the orbit
  - Eccentricity (e): Shape of the orbit (0 = circular, 0-1 = elliptical)
  - Inclination (i): Tilt relative to the equatorial plane
  - RAAN (Ω): Right Ascension of the Ascending Node
  - Argument of perigee (ω): Orientation of the orbit in its plane
  - True anomaly (ν): Position along the orbit

  All angles are in radians. Semi-major axis is in kilometers.
  """

  @enforce_keys [:semi_major_axis, :eccentricity, :inclination, :raan, :arg_perigee, :true_anomaly]
  defstruct [:epoch, :semi_major_axis, :eccentricity, :inclination, :raan, :arg_perigee, :true_anomaly, :mu]

  @type t :: %__MODULE__{
          epoch: DateTime.t() | nil,
          semi_major_axis: float(),
          eccentricity: float(),
          inclination: float(),
          raan: float(),
          arg_perigee: float(),
          true_anomaly: float(),
          mu: float() | nil
        }

  # Earth's gravitational parameter in km^3/s^2
  @earth_mu 398600.4418

  @doc """
  Create new Keplerian elements.

  ## Parameters
    - semi_major_axis: Semi-major axis in kilometers
    - eccentricity: Orbital eccentricity (0 to < 1 for elliptical)
    - inclination: Inclination in radians
    - raan: Right Ascension of Ascending Node in radians
    - arg_perigee: Argument of perigee in radians
    - true_anomaly: True anomaly in radians
    - opts: Optional parameters
      - :epoch - DateTime for the elements
      - :mu - Gravitational parameter (defaults to Earth)
  """
  @spec new(float(), float(), float(), float(), float(), float(), keyword()) :: t()
  def new(semi_major_axis, eccentricity, inclination, raan, arg_perigee, true_anomaly, opts \\ []) do
    %__MODULE__{
      epoch: Keyword.get(opts, :epoch),
      semi_major_axis: semi_major_axis,
      eccentricity: eccentricity,
      inclination: inclination,
      raan: raan,
      arg_perigee: arg_perigee,
      true_anomaly: true_anomaly,
      mu: Keyword.get(opts, :mu, @earth_mu)
    }
  end

  @doc """
  Calculate orbital period in seconds.
  """
  @spec period(t()) :: float()
  def period(%__MODULE__{semi_major_axis: a, mu: mu}) do
    mu = mu || @earth_mu
    2.0 * :math.pi() * :math.sqrt(a * a * a / mu)
  end

  @doc """
  Calculate mean motion in radians per second.
  """
  @spec mean_motion(t()) :: float()
  def mean_motion(%__MODULE__{} = elements) do
    2.0 * :math.pi() / period(elements)
  end

  @doc """
  Calculate apoapsis radius in kilometers.
  """
  @spec apoapsis(t()) :: float()
  def apoapsis(%__MODULE__{semi_major_axis: a, eccentricity: e}) do
    a * (1.0 + e)
  end

  @doc """
  Calculate periapsis radius in kilometers.
  """
  @spec periapsis(t()) :: float()
  def periapsis(%__MODULE__{semi_major_axis: a, eccentricity: e}) do
    a * (1.0 - e)
  end

  @doc """
  Calculate specific orbital energy in km^2/s^2.
  """
  @spec specific_energy(t()) :: float()
  def specific_energy(%__MODULE__{semi_major_axis: a, mu: mu}) do
    mu = mu || @earth_mu
    -mu / (2.0 * a)
  end

  @doc """
  Calculate specific angular momentum magnitude in km^2/s.
  """
  @spec angular_momentum(t()) :: float()
  def angular_momentum(%__MODULE__{semi_major_axis: a, eccentricity: e, mu: mu}) do
    mu = mu || @earth_mu
    :math.sqrt(mu * a * (1.0 - e * e))
  end

  @doc """
  Convert true anomaly to eccentric anomaly.
  """
  @spec true_to_eccentric_anomaly(t()) :: float()
  def true_to_eccentric_anomaly(%__MODULE__{eccentricity: e, true_anomaly: nu}) do
    :math.atan2(
      :math.sqrt(1.0 - e * e) * :math.sin(nu),
      e + :math.cos(nu)
    )
  end

  @doc """
  Convert true anomaly to mean anomaly.
  """
  @spec true_to_mean_anomaly(t()) :: float()
  def true_to_mean_anomaly(%__MODULE__{eccentricity: e} = elements) do
    ea = true_to_eccentric_anomaly(elements)
    ea - e * :math.sin(ea)
  end

  @doc """
  Convert Keplerian elements to Nx tensor representation.
  Returns tensor of shape {6}: [a, e, i, Ω, ω, ν]
  """
  @spec to_tensor(t()) :: Nx.Tensor.t()
  def to_tensor(%__MODULE__{
        semi_major_axis: a,
        eccentricity: e,
        inclination: i,
        raan: raan,
        arg_perigee: w,
        true_anomaly: nu
      }) do
    Nx.tensor([a, e, i, raan, w, nu], type: :f64)
  end

  @doc """
  Create Keplerian elements from Nx tensor.
  """
  @spec from_tensor(Nx.Tensor.t(), keyword()) :: t()
  def from_tensor(tensor, opts \\ []) do
    [a, e, i, raan, w, nu] = Nx.to_flat_list(tensor)
    new(a, e, i, raan, w, nu, opts)
  end
end
