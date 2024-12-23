defmodule SpaceDust.Propagator.SGP4.Dsinit do
  alias SpaceDust.Utils.Constants, as: Constants

  def dsinit(tc, xpidot, rec) do
    q22 = 1.7891679e-6
    q31 = 2.1460748e-6
    q33 = 2.2123015e-7
    root22 = 1.7891679e-6
    root44 = 7.3636953e-9
    root54 = 2.1765803e-9
    # // this equates to 7.29211514668855e-5 rad/sec
    rptim = 4.37526908801129966e-3
    root32 = 3.7393792e-7
    root52 = 1.1428639e-7
    x2o3 = 2.0 / 3.0
    znl = 1.5835218e-4
    zns = 1.19459e-5

    recCopy =
      Map.from_struct(rec)
      |> Map.put(:__struct__, Satrec)
      |> struct()

    irez =
      cond do
        recCopy.nm < 0.0052359877 and recCopy.nm > 0.0034906585 -> 1
        recCopy.nm >= 8.26e-3 and recCopy.nm <= 9.24e-3 and recCopy.em >= 0.5 -> 2
        true -> 0
      end

    recCopy = Map.put(recCopy, :irez, irez)

    # solar terms
    ses = recCopy.ss1 * zns * recCopy.ss5
    sis = recCopy.ss2 * zns * (recCopy.sz11 + recCopy.sz13)
    sls = -zns * recCopy.ss3 * (recCopy.sz1 + recCopy.sz3 - 14.0 - 6.0 * recCopy.emsq)
    sghs = recCopy.ss4 * zns * (recCopy.sz31 + recCopy.sz33 - 6.0)
    shs = -zns * recCopy.ss2 * (recCopy.sz21 + recCopy.sz23)

    shs =
      cond do
        recCopy.inclm < 5.2359877e-2 or recCopy.inclm > :math.pi() - 5.2359877e-2 -> 0.0
        recCopy.sinim != 0.0 -> shs / recCopy.sinim
        true -> shs
      end

    sgs = sghs - recCopy.cosim * shs

    # lunar terms
    recCopy =
      Map.put(recCopy, :dedt, ses + recCopy.s1 * znl * recCopy.s5)
      |> Map.put(:didt, sis + recCopy.s2 * znl * (recCopy.z11 + recCopy.z13))
      |> Map.put(
        :dmdt,
        sls - znl * recCopy.s3 * (recCopy.z1 + recCopy.z3 - 14.0 - 6.0 * recCopy.emsq)
      )

    sghl = recCopy.s4 * znl * (recCopy.z31 + recCopy.z33 - 6.0)

    shll =
      if recCopy.inclm < 5.2359877e-2 or recCopy.inclm > :math.pi() - 5.2359877e-2 do
        0.0
      else
        -znl * recCopy.s2 * (recCopy.z21 + recCopy.z23)
      end

    {domdt, dnodt} =
      cond do
        recCopy.sinim != 0.0 ->
          {recCopy.domdt - recCopy.cosim / recCopy.sinim * shll,
           recCopy.dnodt + shll / recCopy.sinim}

        true ->
          {sgs + sghl, shs}
      end

    recCopy =
      Map.put(recCopy, :domdt, domdt)
      |> Map.put(:dnodt, dnodt)

    theta = :math.fmod(recCopy.gsto + tc * rptim, Constants.twopi())

    recCopy =
      Map.put(recCopy, :dndt, 0.0)
      |> Map.put(:em, recCopy.em + recCopy.dedt * recCopy.t)
      |> Map.put(:inclm, recCopy.inclm + recCopy.didt * recCopy.t)
      |> Map.put(:argpm, recCopy.argpm + recCopy.domdt * recCopy.t)
      |> Map.put(:nodem, recCopy.nodem + recCopy.dnodt * recCopy.t)
      |> Map.put(:mm, recCopy.mm + recCopy.dmdt * recCopy.t)

    if recCopy.irez != 0 do
      aonv = :math.pow(recCopy.nm / recCopy.xke, x2o3)

      # geopotential resonance initialization for 12 hour orbits
      recCopy =
        cond do
          recCopy.irez == 2 ->
            cosisq = rec.cosim * rec.cosim
            emo = rec.em
            emsqo = recCopy.emsq

            recCopy =
              Map.put(recCopy, :em, recCopy.ecco)
              |> Map.put(:emsq, recCopy.eccsq)

            eoc = recCopy.em * recCopy.emsq
            g201 = -0.306 - (rec.em - 0.64) * 0.440

            # need g201, g211, g310, g322, g410, g422, g520, g532, g521, g533
            {g211, g310, g322, g410, g422, g520} =
              if recCopy.em <= 0.65 do
                {3.616 - 13.2470 * recCopy.em + 16.2900 * recCopy.emsq,
                 -19.302 + 117.3900 * recCopy.em - 228.4190 * recCopy.emsq + 156.5910 * eoc,
                 -18.9068 + 109.7927 * recCopy.em - 214.6334 * recCopy.emsq + 146.5816 * eoc,
                 -41.122 + 242.6940 * recCopy.em - 471.0940 * recCopy.emsq + 313.9530 * eoc,
                 -146.407 + 841.8800 * recCopy.em - 1629.014 * recCopy.emsq + 1083.4350 * eoc,
                 -532.114 + 3017.977 * recCopy.em - 5740.032 * recCopy.emsq + 3708.2760 * eoc}
              else
                g520 =
                  if recCopy.em > 0.715 do
                    1465.74 - 4664.75 * recCopy.em + 3763.64 * recCopy.emsq
                  else
                    -5149.66 + 29936.92 * recCopy.em - 54087.36 * recCopy.emsq + 31324.56 * eoc
                  end

                {
                  -72.099 + 331.819 * recCopy.em - 508.738 * recCopy.emsq + 266.724 * eoc,
                  -346.844 + 1582.851 * recCopy.em - 2415.925 * recCopy.emsq + 1246.113 * eoc,
                  -342.585 + 1554.908 * recCopy.em - 2366.899 * recCopy.emsq + 1215.972 * eoc,
                  -1052.797 + 4758.686 * recCopy.em - 7193.992 * recCopy.emsq + 3651.957 * eoc,
                  -3581.69 + 16178.11 * recCopy.em - 24462.77 * recCopy.emsq + 12422.52 * eoc,
                  g520
                }
              end

            {g533, g521, g532} =
              if recCopy.em < 0.7 do
                {
                  -919.2277 + 4988.61 * recCopy.em - 9064.77 * recCopy.emsq + 5542.21 * eoc,
                  -822.71072 + 4568.6173 * recCopy.em - 8491.4146 * recCopy.emsq + 5337.524 * eoc,
                  -853.666 + 4690.25 * recCopy.em - 8624.77 * recCopy.emsq + 5341.4 * eoc
                }
              else
                {
                  -37995.78 + 161_616.52 * recCopy.em - 229_838.2 * recCopy.emsq +
                    109_377.94 * eoc,
                  -51752.104 + 218_913.95 * recCopy.em - 309_468.16 * recCopy.emsq +
                    146_349.42 * eoc,
                  -40023.88 + 170_470.89 * recCopy.em - 242_699.48 * recCopy.emsq +
                    115_605.82 * eoc
                }
              end

            sini2 = recCopy.sinim * recCopy.sinim
            f220 = 0.75 * (1.0 + 2.0 * recCopy.cosim + cosisq)
            f221 = 1.5 * sini2
            f321 = 1.875 * recCopy.sinim * (1.0 - 2.0 * recCopy.cosim - 3.0 * cosisq)
            f322 = -1.875 * recCopy.sinim * (1.0 + 2.0 * recCopy.cosim - 3.0 * cosisq)
            f441 = 35.0 * sini2 * f220
            f442 = 39.3750 * sini2 * sini2

            f522 =
              9.84375 * recCopy.sinim *
                (sini2 * (1.0 - 2.0 * recCopy.cosim - 5.0 * cosisq) +
                   0.33333333 * (-2.0 + 4.0 * recCopy.cosim + 6.0 * cosisq))

            f523 =
              recCopy.sinim *
                (4.92187512 * sini2 * (-2.0 - 4.0 * recCopy.cosim + 10.0 * cosisq) +
                   6.56250012 * (1.0 + 2.0 * recCopy.cosim - 3.0 * cosisq))

            f542 =
              29.53125 * recCopy.sinim *
                (2.0 - 8.0 * recCopy.cosim +
                   cosisq * (-12.0 + 8.0 * recCopy.cosim + 10.0 * cosisq))

            f543 =
              29.53125 * recCopy.sinim *
                (-2.0 - 8.0 * recCopy.cosim +
                   cosisq * (12.0 + 8.0 * recCopy.cosim - 10.0 * cosisq))

            xno2 = recCopy.nm * recCopy.nm
            ainv2 = aonv * aonv
            temp1 = 3.0 * xno2 * ainv2
            temp = temp1 * root22

            recCopy =
              Map.put(recCopy, :d2201, temp * f220 * g201)
              |> Map.put(:d2211, temp * f221 * g211)

            temp1 = temp1 * aonv
            temp = temp1 * root32

            recCopy =
              Map.put(recCopy, :d3210, temp * f321 * g310)
              |> Map.put(:d3222, temp * f322 * g322)

            temp1 = temp1 * aonv
            temp = 2.0 * temp1 * root44

            recCopy =
              Map.put(recCopy, :d4410, temp * f441 * g410)
              |> Map.put(:d4422, temp * f442 * g422)

            temp1 = temp1 * aonv
            temp = temp1 * root52

            recCopy =
              Map.put(recCopy, :d5220, temp * f522 * g520)
              |> Map.put(:d5232, temp * f523 * g532)

            temp = 2.0 * temp1 * root54

            Map.put(recCopy, :d5421, temp * f542 * g521)
            |> Map.put(:d5433, temp * f543 * g533)
            |> Map.put(
              :xlamo,
              :math.fmod(
                recCopy.mo + recCopy.nodeo + recCopy.nodeo - theta - theta,
                Constants.twopi()
              )
            )
            |> Map.put(
              :xfact,
              recCopy.mdot + recCopy.dnodt + 2.0 * (recCopy.nodedot - rptim) - recCopy.no_unkozai
            )
            |> Map.put(:em, emo)
            |> Map.put(:emsq, emsqo)

          recCopy.irez == 1 ->
            g200 = 1.0 + recCopy.emsq * (-2.5 + 0.8125 * recCopy.emsq)
            g310 = 1.0 + 2.0 * recCopy.emsq
            g300 = 1.0 + recCopy.emsq * (-6.0 + 6.60937 * recCopy.emsq)
            f220 = 0.75 * (1.0 + recCopy.cosim) * (1.0 + recCopy.cosim)

            f311 =
              0.9375 * recCopy.sinim * recCopy.sinim * (1.0 + 3.0 * recCopy.cosim) -
                0.75 * (1.0 + recCopy.cosim)

            f330 = 1.0 + recCopy.cosim
            f330 = 1.875 * f330 * f330 * f330

            # no pipe operator here because we need to use updated keys
            recCopy = Map.put(recCopy, :del1, 3.0 * recCopy.nm * recCopy.nm * aonv * aonv)
            recCopy = Map.put(recCopy, :del2, 2.0 * recCopy.del1 * f220 * g200 * q22)
            recCopy = Map.put(recCopy, :del3, 3.0 * recCopy.del1 * f330 * g300 * q33 * aonv)

            recCopy =
              Map.put(
                recCopy,
                :del1,
                recCopy.del1 + recCopy.del1 + recCopy.dndt * f311 * g310 * q31 * aonv
              )

            recCopy =
              Map.put(
                recCopy,
                :xlamo,
                :math.fmod(recCopy.mo + recCopy.nodeo + recCopy.argpo - theta, Constants.twopi())
              )

            Map.put(
              recCopy,
              :xfact,
              recCopy.mdot + xpidot - rptim + recCopy.dmdt + recCopy.domdt + recCopy.dnodt -
                recCopy.no_unkozai
            )

          true ->
            recCopy
        end

      Map.put(recCopy, :xli, recCopy.xlamo)
      |> Map.put(:xni, recCopy.no_unkozai)
      |> Map.put(:atime, 0.0)
      |> Map.put(:nm, recCopy.no_unkozai + recCopy.dndt)
    else
      recCopy
    end
  end
end
