defmodule SpaceDust.State.ReferenceFrame do
  def eci_j2000, do: :eci_j2000
  def teme, do: :teme
end

defmodule SpaceDust.State.StateVector do
  @enforce_keys [:epoch, :position, :velocity, :referenceFrame]

  defstruct [
    :epoch,
    :position,
    :velocity,
    :referenceFrame
  ]
end
