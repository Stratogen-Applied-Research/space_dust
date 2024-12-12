defmodule SpaceDust.State.StateVector do
  @enforce_keys [:epoch, :position, :velocity]

  defstruct [
    :epoch,
    :position,
    :velocity
  ]
end
