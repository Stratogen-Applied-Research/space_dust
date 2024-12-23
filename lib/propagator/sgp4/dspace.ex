defmodule SpaceDust.Propagator.SGP4.Dspace do
  alias SpaceDust.Propagator.SGP4.Satrec, as: Satrec
  alias SpaceDust.Utils.Constants, as: Constants

  @doc """
  dspace - calculate deep space resonance effects
  """
  def dspace(tc, rec) do
    # copy the rec object to avoid mutation
    recCopy = Map.from_struct(rec) |> Map.put(:__struct__, Satrec) |> struct()

    # Constants
    fasx2 = 0.13130908
    fasx4 = 2.8843198
    fasx6 = 0.37448087
    g22 = 5.7686396
    g32 = 0.95240898
    g44 = 1.8014998
    g52 = 1.0508330
    g54 = 4.4108898
    # this equates to 7.29211514668855e-5 rad/sec
    rptim = 4.37526908801129966e-3
    stepp = 720.0
    stepn = -720.0
    step2 = 259_200.0

    # deep space resonance effects
    theta = :math.fmod(recCopy.gsto + tc * rptim, Constants.twopi())

    recCopy =
      Map.put(recCopy, :dndt, 0.0)
      |> Map.put(:em, recCopy.em + recCopy.dedt * recCopy.t)
      |> Map.put(:inclm, recCopy.inclm + recCopy.didt * recCopy.t)
      |> Map.put(:argpm, recCopy.argpm + recCopy.domdt * recCopy.t)
      |> Map.put(:nodem, recCopy.nodem + recCopy.dnodt * recCopy.t)
      |> Map.put(:mm, recCopy.mm + recCopy.dmdt * recCopy.t)
  end
end
