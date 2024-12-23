defmodule SpaceDust.Propagator.SGP4.Dspace do
  alias SpaceDust.Propagator.SGP4.Satrec, as: Satrec
  alias SpaceDust.Utils.Constants, as: Constants

  defp dspaceLoop(rec, ft, xndt, xldot, iretn) do
    # Constants
    fasx2 = 0.13130908
    fasx4 = 2.8843198
    fasx6 = 0.37448087
    g22 = 5.7686396
    g32 = 0.95240898
    g44 = 1.8014998
    g52 = 1.0508330
    g54 = 4.4108898
    step2 = 259_200.0
    stepp = 720.0
    stepn = -720.0

    recCopy =
      Map.from_struct(rec)
      |> Map.put(:__struct__, Satrec)
      |> struct()

    if iretn == 381 do
      delt =
        if recCopy.t > 0.0 do
          stepp
        else
          stepn
        end

      {xndt, xldot, xnddt} =
        if recCopy.irez != 2 do
          # near-synchronous resonance terms
          xndt =
            recCopy.del1 * :math.sin(recCopy.xli - fasx2) +
              recCopy.del2 * :math.sin(2.0 * (recCopy.xli - fasx4)) +
              recCopy.del3 * :math.sin(3.0 * (recCopy.xli - fasx6))

          xldot = recCopy.xni + recCopy.xfact

          xnddt =
            recCopy.del1 * :math.cos(recCopy.xli - fasx2) +
              2.0 * recCopy.del2 * :math.cos(2.0 * (recCopy.xli - fasx4)) +
              3.0 * recCopy.del3 * :math.cos(3.0 * (recCopy.xli - fasx6))

          {xndt, xldot, xnddt * xldot}
        else
          # near-half-day resonance terms
          xomi = recCopy.argpo + recCopy.argpdot * recCopy.atime
          x2omi = xomi + xomi
          x2li = recCopy.xli + recCopy.xli

          xndt =
            recCopy.d2201 * :math.sin(x2omi + recCopy.xli - g22) +
              recCopy.d2211 * :math.sin(recCopy.xli - g22) +
              recCopy.d3210 * :math.sin(xomi + recCopy.xli - g32) +
              recCopy.d3222 * :math.sin(-xomi + recCopy.xli - g32) +
              recCopy.d4410 * :math.sin(x2omi + x2li - g44) +
              recCopy.d4422 * :math.sin(x2li - g44) +
              recCopy.d5220 * :math.sin(xomi + recCopy.xli - g52) +
              recCopy.d5232 * :math.sin(-xomi + recCopy.xli - g52) +
              recCopy.d5421 * :math.sin(xomi + x2li - g54) +
              recCopy.d433 * :math.sin(-xomi + x2li - g54)

          xldot = recCopy.xni + recCopy.xfact

          xnddt =
            recCopy.d2201 * :math.cos(x2omi + recCopy.xli - g22) +
              recCopy.d2211 * :math.cos(recCopy.xli - g22) +
              recCopy.d3210 * :math.cos(xomi + recCopy.xli - g32) +
              recCopy.d3222 * :math.cos(-xomi + recCopy.xli - g32) +
              recCopy.d5220 * :math.cos(xomi + recCopy.xli - g52) +
              recCopy.d5232 * :math.cos(-xomi + recCopy.xli - g52) +
              2.0 *
                (recCopy.d4410 * :math.cos(x2omi + x2li - g44) +
                   recCopy.d4422 * :math.cos(x2li - g44) +
                   recCopy.d5421 * :math.cos(xomi + x2li - g54) +
                   recCopy.d5433 * :math.cos(-xomi + x2li - g54))

          {xndt, xldot, xnddt * xldot}
        end

      {iretnUpdated, ft} =
        if abs(recCopy.t - recCopy.atime) >= stepp do
          {381, 0}
        else
          {0, recCopy.t - recCopy.atime}
        end

      if iretnUpdated == 381 do
        Map.put(recCopy, :xli, recCopy.xli + xldot * delt + xndt * step2)
        |> Map.put(:xni, recCopy.xni + xndt * delt + xnddt * step2)
        |> Map.put(:atime, recCopy.atime + delt)

        # recursion to mimic the while loop of the original
        dspaceLoop(recCopy, ft, xndt, xldot, iretnUpdated)
      else
        # return recCopy, ft, xndt, & xldot at end of loop
        {recCopy, ft, xndt, xldot}
      end
    else
      {recCopy, ft, xndt, xldot}
    end
  end

  @doc """
  dspace - calculate deep space resonance effects
  """
  def dspace(tc, rec) do
    # copy the rec object to avoid mutation
    recCopy = Map.from_struct(rec) |> Map.put(:__struct__, Satrec) |> struct()

    # this equates to 7.29211514668855e-5 rad/sec
    rptim = 4.37526908801129966e-3

    # deep space resonance effects
    theta = :math.fmod(recCopy.gsto + tc * rptim, Constants.twopi())

    recCopy =
      Map.put(recCopy, :dndt, 0.0)
      |> Map.put(:em, recCopy.em + recCopy.dedt * recCopy.t)
      |> Map.put(:inclm, recCopy.inclm + recCopy.didt * recCopy.t)
      |> Map.put(:argpm, recCopy.argpm + recCopy.domdt * recCopy.t)
      |> Map.put(:nodem, recCopy.nodem + recCopy.dnodt * recCopy.t)
      |> Map.put(:mm, recCopy.mm + recCopy.dmdt * recCopy.t)

    if recCopy.irez != 0 do
      recCopy =
        if recCopy.atime == 0.0 or recCopy.t * recCopy.atime <= 0.0 or
             abs(recCopy.t) < abs(recCopy.atime) do
          Map.put(recCopy, :atime, 0.0)
          |> Map.put(:xni, recCopy.no_unkozai)
          |> Map.put(:xli, recCopy.xlamo)
        else
          recCopy
        end

      # initialize while loop with dummy 0 values for ft, xndt, & xldot
      {recCopy, ft, xndt, xldot} = dspaceLoop(recCopy, 0, 0, 0, 381)
      recCopy = Map.put(recCopy, :nm, recCopy.xni + xndt)
      xl = recCopy.xli + xldot * ft + xndt * ft * ft * 0.5

      recCopy =
        if recCopy.irez != 1 do
          Map.put(recCopy, :mm, xl - 2 * recCopy.nodem + 2 * theta)
          |> Map.put(:dndt, recCopy.nm - recCopy.no_unkozai)
        else
          Map.put(recCopy, :mm, xl - recCopy.nodem - recCopy.argpm + theta)
          |> Map.put(:nm, rec.no_unkozai)
        end

      # return updated satrec
      Map.put(recCopy, :nm, rec.no_unkozai + rec.dndt)
    else
      recCopy
    end
  end
end
