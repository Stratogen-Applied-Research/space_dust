defmodule SpaceDust.State.ReferenceFrame do
  defmodule ECEF do
    @type ecef() :: :ecef
  end

  defmodule ECI_J2000 do
    @type eci_j2000() :: :eci
  end

  defmodule TEME do
    @type teme() :: :teme
  end
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
