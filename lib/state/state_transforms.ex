defmodule SpaceDust.State.StateTransforms do
  @moduledoc """
  State vector transformations
  """

  @doc "convert a state vector from true equator mean equinox (TEME) to ECI J2000"
  def temeToEciJ2000(_stateVector, _utcEpoch) do
    throw(:not_implemented)
  end
end
