defmodule SpaceDust.Propagator.SGP4.SGP4init do
  alias SpaceDust.Propagator.SGP4.Satrec, as: Satrec
  alias SpaceDust.Propagator.SGP4.Helpers, as: Helpers
  alias SpaceDust.Propagator.SGP4.Initl, as: Initl
  alias SpaceDust.Propagator.SGP4.Dscom, as: Dscom
  alias SpaceDust.Propagator.SGP4.Dpper, as: Dpper
  alias SpaceDust.Propagator.SGP4.Dsinit, as: Dsinit
  alias SpaceDust.Propagator.SGP4.SGP4, as: SGP4

  def sgp4init(opsmode, satrec) do
    epoch = satrec.jdsatepoch + satrec.jdsatepochF - 2_433_281.5

    temp4 = 1.5e-12

    recCopy =
      Map.from_struct(satrec)
      |> Map.put(:__struct__, Satrec)
      |> struct()
      # initialize near earth variables to 0
      |> Map.put(:isimp, 0)
      |> Map.put(:method, "n")
      |> Map.put(:aycof, 0.0)
      |> Map.put(:con41, 0.0)
      |> Map.put(:cc1, 0.0)
      |> Map.put(:cc4, 0.0)
      |> Map.put(:cc5, 0.0)
      |> Map.put(:d2, 0.0)
      |> Map.put(:d3, 0.0)
      |> Map.put(:d4, 0.0)
      |> Map.put(:delmo, 0.0)
      |> Map.put(:eta, 0.0)
      |> Map.put(:argpdot, 0.0)
      |> Map.put(:omgcof, 0.0)
      |> Map.put(:sinmao, 0.0)
      |> Map.put(:t, 0.0)
      |> Map.put(:t2cof, 0.0)
      |> Map.put(:t3cof, 0.0)
      |> Map.put(:t4cof, 0.0)
      |> Map.put(:t5cof, 0.0)
      |> Map.put(:x1mth2, 0.0)
      |> Map.put(:x7thm1, 0.0)
      |> Map.put(:mdot, 0.0)
      |> Map.put(:nodedot, 0.0)
      |> Map.put(:xlcof, 0.0)
      |> Map.put(:xmcof, 0.0)
      |> Map.put(:nodecf, 0.0)
      # initialize deep space variables
      |> Map.put(:irez, 0)
      |> Map.put(:d2201, 0.0)
      |> Map.put(:d2211, 0.0)
      |> Map.put(:d3210, 0.0)
      |> Map.put(:d3222, 0.0)
      |> Map.put(:d4410, 0.0)
      |> Map.put(:d4422, 0.0)
      |> Map.put(:d5220, 0.0)
      |> Map.put(:d5232, 0.0)
      |> Map.put(:d5421, 0.0)
      |> Map.put(:d5433, 0.0)
      |> Map.put(:dedt, 0.0)
      |> Map.put(:del1, 0.0)
      |> Map.put(:del2, 0.0)
      |> Map.put(:del3, 0.0)
      |> Map.put(:didt, 0.0)
      |> Map.put(:dmdt, 0.0)
      |> Map.put(:dnodt, 0.0)
      |> Map.put(:domdt, 0.0)
      |> Map.put(:e3, 0.0)
      |> Map.put(:ee2, 0.0)
      |> Map.put(:peo, 0.0)
      |> Map.put(:pgho, 0.0)
      |> Map.put(:pho, 0.0)
      |> Map.put(:pinco, 0.0)
      |> Map.put(:plo, 0.0)
      |> Map.put(:se2, 0.0)
      |> Map.put(:se3, 0.0)
      |> Map.put(:sgh2, 0.0)
      |> Map.put(:sgh3, 0.0)
      |> Map.put(:sgh4, 0.0)
      |> Map.put(:sh2, 0.0)
      |> Map.put(:sh3, 0.0)
      |> Map.put(:si2, 0.0)
      |> Map.put(:si3, 0.0)
      |> Map.put(:sl2, 0.0)
      |> Map.put(:sl3, 0.0)
      |> Map.put(:sl4, 0.0)
      |> Map.put(:gsto, 0.0)
      |> Map.put(:xfact, 0.0)
      |> Map.put(:xgh2, 0.0)
      |> Map.put(:xgh3, 0.0)
      |> Map.put(:xgh4, 0.0)
      |> Map.put(:xh2, 0.0)
      |> Map.put(:xh3, 0.0)
      |> Map.put(:xi2, 0.0)
      |> Map.put(:xi3, 0.0)
      |> Map.put(:xl2, 0.0)
      |> Map.put(:xl3, 0.0)
      |> Map.put(:xl4, 0.0)
      |> Map.put(:xlamo, 0.0)
      |> Map.put(:zmol, 0.0)
      |> Map.put(:zmos, 0.0)
      |> Map.put(:atime, 0.0)
      |> Map.put(:xli, 0.0)
      |> Map.put(:xni, 0.0)
      |> Helpers.getgravconst(satrec.whichconst)
      |> Map.put(:error, 0)
      |> Map.put(:operationmode, opsmode)
      |> Map.put(:am, 0.0)
      |> Map.put(:em, 0.0)
      |> Map.put(:im, 0.0)
      |> Map.put(:Om, 0.0)
      |> Map.put(:mm, 0.0)
      |> Map.put(:nm, 0.0)

    ss = 78.0 / recCopy.earthradiuskm + 1.0
    qzms2ttemp = (120.0 - 78.0) / recCopy.radiusearthkm
    qzms2t = qzms2ttemp * qzms2ttemp * qzms2ttemp * qzms2ttemp
    x2o3 = 2.0 / 3.0

    recCopy =
      Map.put(recCopy, :init, "y")
      |> Map.put(:t, 0.0)

    recCopy = Initl.initl(recCopy, epoch)

    # we want the values from initl present beyond here
    recCopy = Map.put(recCopy, :a, :math.pow(recCopy.no_unkozai * recCopy.tumin, -2.0 / 3.0))

    recCopy =
      Map.put(recCopy, :alta, recCopy.a * (1.0 + recCopy.ecco) - 1.0)
      |> Map.put(:altp, recCopy.a * (1.0 - recCopy.ecco) - 1.0)
      |> Map.put(:error, 0.0)

    recCopy =
      if recCopy.omeosq >= 0.0 or recCopy.no_unkozai >= 0.0 do
        isimp =
          if recCopy.rp < 220.0 / recCopy.radiusearthkm + 1.0 do
            1
          else
            0
          end

        recCopy = Map.put(recCopy, :isimp, isimp)
        perigee = (recCopy.rp - 1.0) * recCopy.radiusearthkm

        {sfour, qzms24} =
          cond do
            perigee < 156.0 ->
              qzms24temp = (120.0 - ss) / satrec.radiusearthkm
              qzms24 = qzms24temp * qzms24temp * qzms24temp * qzms24temp
              {perigee - 78.0, qzms24}

            perigee < 98.0 ->
              qzms24temp = (120.0 - ss) / satrec.radiusearthkm
              qzms24 = qzms24temp * qzms24temp * qzms24temp * qzms24temp
              {20.0, qzms24}

            true ->
              {ss, qzms2t}
          end

        pinvsq = 1.0 / recCopy.posq
        tsi = 1.0 / (recCopy.ao - sfour)
        recCopy = Map.put(recCopy, :eta, recCopy.ao * recCopy.ecco * tsi)
        etasq = recCopy.eta * recCopy.eta
        eeta = recCopy.ecco * recCopy.eta
        psisq = abs(1.0 - etasq)
        coef = qzms24 * :math.pow(tsi, 4.0)
        coef1 = coef / :math.pow(psisq, 3.5)

        cc2 =
          coef1 * recCopy.no_unkozai *
            (recCopy.ao *
               (1.0 + 1.5 * etasq +
                  eeta *
                    (4.0 + etasq)) +
               0.375 * recCopy.j2 * tsi / psisq * recCopy.con41 *
                 (8.0 + 3.0 * etasq * (8.0 + etasq)))

        recCopy = Map.put(recCopy, :cc1, recCopy.bstar * cc2)

        cc3 =
          if recCopy.ecco > 1.0e-4 do
            -2.0 * coef * tsi * recCopy.j3oj2 * recCopy.no_unkozai * recCopy.sinio / recCopy.ecco
          else
            0.0
          end

        recCopy = Map.put(recCopy, :x1mth2, 1.0 - recCopy.cosio2)

        recCopy =
          Map.put(
            recCopy,
            :cc4,
            2.0 * recCopy.no_unkozai * coef1 * recCopy.ao * recCopy.omeosq *
              (recCopy.eta * (2.0 + 0.5 * etasq) +
                 recCopy.ecco *
                   (0.5 + 2.0 * etasq) -
                 satrec.j2 * tsi / (recCopy.ao * psisq) *
                   (-3.0 * recCopy.con41 *
                      (1.0 - 2.0 * eeta +
                         etasq *
                           (1.5 - 0.5 * eeta)) +
                      0.75 * recCopy.x1mth2 *
                        (2.0 * etasq - eeta * (1.0 + etasq)) * :math.cos(2.0 * recCopy.argpo)))
          )
          |> Map.put(
            :cc5,
            2.0 * coef1 * recCopy.ao * recCopy.omeosq *
              (1.0 +
                 2.75 *
                   (etasq + eeta) + eeta * etasq)
          )

        cosio4 = recCopy.cosio2 * recCopy.cosio2
        temp1 = 1.5 * recCopy.j2 * pinvsq * recCopy.no_unkozai
        temp2 = 0.5 * temp1 * recCopy.j2 * pinvsq
        temp3 = -0.46875 * recCopy.j4 * pinvsq * pinvsq * recCopy.no_unkozai

        recCopy =
          Map.put(
            recCopy,
            :mdot,
            recCopy.no_unkozai + 0.5 * temp1 * recCopy.rteosq * recCopy.con41 +
              0.0625 *
                temp2 * recCopy.rteosq * (13.0 - 78.0 * recCopy.cosio2 + 137.0 * cosio4)
          )
          |> Map.put(
            :argpdot,
            -0.5 * temp1 * recCopy.con42 +
              0.0625 * temp2 *
                (7.0 - 114.0 * recCopy.cosio2 + 395.0 * cosio4) +
              temp3 * (3.0 - 36.0 * recCopy.cosio2 + 49.0 * cosio4)
          )

        xhdot1 = -temp1 * recCopy.cosio

        recCopy =
          Map.put(
            recCopy,
            :nodedot,
            xhdot1 +
              (0.5 * temp2 * (4.0 - 19.0 * recCopy.cosio2) +
                 2.0 * temp3 * (3.0 - 7.0 * recCopy.cosio2)) * recCopy.cosio
          )

        xpidot = recCopy.argpdot + recCopy.nodedot

        recCopy = Map.put(recCopy, :omgcof, recCopy.bstar * cc3 * :math.cos(recCopy.argpo))

        xmcof =
          if recCopy.ecco > 1.0e-4 do
            -x2o3 * coef * recCopy.bstar / eeta
          else
            0.0
          end

        recCopy =
          Map.put(recCopy, :xmcof, xmcof)
          |> Map.put(:nodecf, 3.5 * recCopy.omeosq * xhdot1 * recCopy.cc1)
          |> Map.put(:t2cof, 1.5 * recCopy.cc1)

        xlcof =
          if abs(recCopy.cosio + 1.0) > 1.5e-12 do
            -0.25 * recCopy.j3oj2 * recCopy.sinio * (3.0 + 5.0 * recCopy.cosio) /
              (1.0 + recCopy.cosio)
          else
            -0.25 * recCopy.j3oj2 * recCopy.sinio * (3.0 + 5.0 * recCopy.cosio) / temp4
          end

        recCopy =
          Map.put(recCopy, :xlcof, xlcof)
          |> Map.put(:aycof, -0.5 * recCopy.j3oj2 * recCopy.sinio)

        delmotemp = 1.0 + recCopy.eta * :math.cos(recCopy.mo)

        recCopy =
          Map.put(recCopy, :delmo, delmotemp * delmotemp * delmotemp)
          |> Map.put(:sinmao, :math.sin(recCopy.mo))
          |> Map.put(:x7thm1, 7.0 * recCopy.cosio2 - 1.0)

        recCopy =
          if 2 * :math.pi() / recCopy.no_unkozai >= 225.0 do
            # deep space initialization
            recCopy =
              Map.put(recCopy, :method, "d")
              |> Map.put(:isimp, 1)
              |> Map.put(:inclm, recCopy.inclo)

            tc = 0.0

            recCopy =
              Dscom.dscom(
                epoch,
                recCopy.ep,
                recCopy.argpo,
                tc,
                recCopy.inclo,
                recCopy.nodeo,
                recCopy.no_unkozai,
                recCopy
              )

            recCopy =
              Map.put(recCopy, :ep, recCopy.ecco)
              |> Map.put(:inclp, recCopy.inclo)
              |> Map.put(:nodep, recCopy.nodeo)
              |> Map.put(:argpp, recCopy.argpo)
              |> Map.put(:mp, recCopy.mo)

            recCopy =
              Dpper.dpper(
                recCopy.e3,
                recCopy.ee2,
                recCopy.peo,
                recCopy.pgho,
                recCopy.pho,
                recCopy.pinco,
                recCopy.plo,
                recCopy.se2,
                recCopy.se3,
                recCopy.sgh2,
                recCopy.sgh3,
                recCopy.sgh4,
                recCopy.sh2,
                recCopy.sh3,
                recCopy.si2,
                recCopy.si3,
                recCopy.sl2,
                recCopy.sl3,
                recCopy.sl4,
                recCopy.t,
                recCopy.xgh2,
                recCopy.xgh3,
                recCopy.xgh4,
                recCopy.xh2,
                recCopy.xh3,
                recCopy.xi2,
                recCopy.xi3,
                recCopy.xl2,
                recCopy.xl3,
                recCopy.xl4,
                recCopy.zmol,
                recCopy.zmos,
                recCopy.init,
                recCopy,
                recCopy.operationmode
              )

            recCopy =
              Map.put(recCopy, :ecco, recCopy.ep)
              |> Map.put(:inclo, recCopy.inclp)
              |> Map.put(:nodeo, recCopy.nodep)
              |> Map.put(:argpo, recCopy.argpp)
              |> Map.put(:mo, recCopy.mp)
              |> Map.put(:argpm, 0.0)
              |> Map.put(:nodem, 0.0)
              |> Map.put(:mm, 0.0)

            Dsinit.dsinit(tc, xpidot, recCopy)
          else
            recCopy
          end

        # set variables if not deep space
        if recCopy.isimp != 1 do
          cc1sq = recCopy.cc1 * recCopy.cc1
          recCopy = Map.put(recCopy, :d2, 4.0 * recCopy.ao * tsi * cc1sq)
          temp = recCopy.d2 * tsi * recCopy.cc1 / 3.0

          recCopy =
            Map.put(recCopy, :d3, temp * (17.0 * recCopy.ao + sfour))
            |> Map.put(
              :d4,
              0.5 * temp * recCopy.ao * tsi * (221.0 * recCopy.ao + 31.0 * sfour) * recCopy.cc1
            )
            |> Map.put(:t3cof, recCopy.d2 + 2.0 * cc1sq)

          Map.put(
            recCopy,
            :t4cof,
            0.25 * (3.0 * recCopy.d3 + recCopy.cc1 * (12.0 * recCopy.d2 + 10.0 * cc1sq))
          )
          |> Map.put(
            :t5cof,
            0.2 *
              (3.0 * recCopy.d4 +
                 12.0 * recCopy.cc1 * recCopy.d3 +
                 6.0 * recCopy.d2 * recCopy.d2 +
                 15.0 * cc1sq * (2.0 * recCopy.d2 + cc1sq))
          )
        else
          recCopy
        end
      else
        recCopy
      end

    r = [0.0, 0.0, 0.0]
    v = [0.0, 0.0, 0.0]

    recCopy =
      SGP4.sgp4(recCopy, 0.0, r, v)
      |> Map.put(:init, "n")

    {:ok, recCopy}
  end
end
