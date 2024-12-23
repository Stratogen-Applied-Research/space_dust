defmodule SpaceDust.Propagator.SGP4.Initl do
  alias SpaceDust.Propagator.SGP4.Helpers, as: Helpers

  def initl(epoch, rec) do
    x2o3 = 2.0 / 3.0

    recCopy =
      Map.from_struct(rec)
      |> Map.put(:__struct__, SpaceDust.Propagator.SGP4.Satrec)
      |> struct()
      |> Map.put(:eccsq, rec.ecco * rec.ecco)

    recCopy = Map.put(recCopy, :omeosq, 1.0 - recCopy.eccsq)
    # need :rteosq for the next line
    recCopy =
      Map.put(recCopy, :rteosq, :math.sqrt(recCopy.omeosq))
      |> Map.put(:cosio, :math.cos(recCopy.inclo))
      |> Map.put(:cosio2, recCopy.cosio * recCopy.cosio)

    ak = :math.pow(recCopy.xke / recCopy.no_kozai, x2o3)
    d1 = 0.75 * recCopy.j2 * (3.0 * recCopy.cosio2 - 1.0) / (recCopy.rteosq * recCopy.omeosq)
    del = d1 / (ak * ak)

    adel =
      ak *
        (1.0 - del * del -
           del *
             (1.0 / 3.0 + 134.0 * del * del / 81.0))

    del = d1 / (adel * adel)

    recCopy =
      Map.put(recCopy, :no_unkozai, recCopy.no_kozai / (1.0 + del))
      |> Map.put(:ao, :math.pow(recCopy.xke / recCopy.no_unkozai, x2o3))

    po = recCopy.ao * recCopy.omeosq

    recCopy = Map.put(recCopy, :con42, 1.0 - 5.0 * recCopy.cosio2)
    # need the value of con42 for the next line
    recCopy =
      Map.put(recCopy, :con41, -recCopy.con42 - recCopy.cosio2 - recCopy.cosio2)
      |> Map.put(:ainv, 1.0 / recCopy.ao)
      |> Map.put(:posq, po * po)
      |> Map.put(:rp, recCopy.ao * (1.0 - recCopy.ecco))
      |> Map.put(:method, "n")

    Map.put(recCopy, :gsto, Helpers.gstime(epoch + 2_433_281.5))
  end
end
