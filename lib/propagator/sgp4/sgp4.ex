defmodule SpaceDust.Propagator.SGP4.SGP4 do
  require Logger
  alias SpaceDust.Utils.Constants, as: Constants
  alias SpaceDust.Propagator.SGP4.Dpper, as: Dpper

  def sgp4(satrec, tsince, _r, _v) do
    temp4 = 1.5e-12
    x2o3 = 2.0 / 3.0

    vkmpersec = satrec.radiusEarthkm * satrec.xke / 60.0

    # make a copy of the satrec struct
    recCopy =
      Map.from_struct(satrec)
      |> Map.put(:__struct__, Satrec)
      |> struct()
      |> Map.put(:t, tsince)
      |> Map.put(:error, 0)

    xmdf = recCopy.mo + recCopy.mdot * recCopy.t
    argpdf = recCopy.argpo + recCopy.argpdot * recCopy.t
    nodedf = recCopy.nodeo + recCopy.nodedot * recCopy.t

    recCopy =
      Map.put(recCopy, :argpm, argpdf)
      |> Map.put(:mm, xmdf)

    t2 = recCopy.t * recCopy.t
    recCopy = Map.put(recCopy, :nodem, nodedf + recCopy.nodecf * t2)
    tempa = 1.0 - recCopy.cc1 * recCopy.t
    tempe = recCopy.bstar * recCopy.cc4 * recCopy.t
    templ = recCopy.t2cof * t2

    # TODO: cleanup unused variables
    {_delomg, _delmtemp, _delm, _temp, _t3, _t4, _mrt, recCopy, tempa, tempe, templ} =
      if recCopy.isimp != 1 do
        delomg = recCopy.omgcof * recCopy.t
        delmtemp = 1.0 + recCopy.eta * :math.cos(xmdf)
        delm = recCopy.xmcof * (delmtemp * delmtemp * delmtemp - recCopy.delmo)
        temp = delomg + delm

        recCopy =
          Map.put(recCopy, :mm, xmdf + temp)
          |> Map.put(:argpm, argpdf - temp)

        t3 = t2 * recCopy.t
        t4 = t3 * recCopy.t
        tempa = tempa - recCopy.d2 * t2 - recCopy.d3 * t3 - recCopy.d4 * t4
        tempe = tempe + recCopy.bstar * recCopy.cc5 * (:math.sin(recCopy.mm) - recCopy.sinmao)
        templ = templ + recCopy.t3cof * t3 + t4 * (recCopy.t4cof + recCopy.t * recCopy.t5cof)
        {delomg, delmtemp, delm, temp, t3, t4, 0, recCopy, tempa, tempe, templ}
      else
        {0, 0, 0, 0, 0, 0, 0, recCopy, tempa, tempe, templ}
      end

    recCopy = Map.put(recCopy, :am, :math.pow(recCopy.xke / recCopy.nm, x2o3) * tempa * tempa)

    recCopy =
      Map.put(recCopy, :nm, recCopy.xke / :math.pow(recCopy.am, 1.5))
      |> Map.put(:em, recCopy.em - tempe)

    if recCopy.em >= 1.0 or recCopy.em < -0.001 do
      Logger.error("SGP4 Error type 1")
      # TODO: add message & custom error types for SGP4
      throw(Exception)
    end

    em =
      if recCopy.em < 1.0e-6 do
        1.0e-6
      else
        recCopy.em
      end

    recCopy =
      Map.put(recCopy, :em, em)
      |> Map.put(:mm, recCopy.mm + recCopy.no_unkozai * templ)

    xlm = recCopy.mm + recCopy.argpm + recCopy.nodem
    recCopy = Map.put(recCopy, :emsq, recCopy.em * recCopy.em)

    # temp = 1.0 - recCopy.emsq  # is this used?
    xlm = :math.fmod(xlm, Constants.twopi())

    recCopy =
      Map.put(recCopy, :nodem, :math.fmod(recCopy.nodem, Constants.twopi()))
      |> Map.put(:argpm, :math.fmod(recCopy.argpm, Constants.twopi()))
      |> Map.put(:mm, :math.fmod(xlm - recCopy.argpm - recCopy.nodem, Constants.twopi()))
      |> Map.put(:am, recCopy.am)
      |> Map.put(:em, recCopy.em)
      |> Map.put(:im, recCopy.inclm)
      |> Map.put(:Om, recCopy.nodem)
      |> Map.put(:om, recCopy.argpm)
      |> Map.put(:mm, recCopy.mm)
      |> Map.put(:nm, recCopy.nm)
      |> Map.put(:sinim, :math.sin(recCopy.inclm))
      |> Map.put(:cosim, :math.cos(recCopy.inclm))

    recCopy =
      Map.put(recCopy, :ep, recCopy.em)
      |> Map.put(:inclp, recCopy.inclm)
      |> Map.put(:argpp, recCopy.argpm)
      |> Map.put(:nodep, recCopy.nodem)
      |> Map.put(:mp, recCopy.mm)

    xincp = recCopy.inclm
    sinip = recCopy.sinim
    cosip = recCopy.cosip

    # the original uses some spicy context hopping to update the cos/sin vals inside the if
    {recCopy, sinip, cosip, xincp} =
      if recCopy.method == "d" do
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
          "n",
          recCopy,
          recCopy.operationmode
        )

        {xincp, recCopy} =
          if recCopy.inclp < 0.0 do
            xincp = -recCopy.inclp

            recCopy =
              Map.put(recCopy, :nodep, recCopy.nodep + :math.pi())
              |> Map.put(:argpp, recCopy.argpp - :math.pi())

            {xincp, recCopy}
          else
            {recCopy.inclp, recCopy}
          end

        if recCopy.ep < 0.0 or recCopy.ep > 1.0 do
          Logger.error("SGP4 Error type 3")
          throw(Exception)
        end

        sinip = :math.sin(xincp)
        cosip = :math.cos(xincp)

        if abs(cosip + 1.0) > 1.5e-12 do
          Map.put(recCopy, :aycof, -0.5 * recCopy.j3oj2 * sinip)
          |> Map.put(:xlcof, -0.25 * recCopy.j3oj2 * sinip * (3.0 + 5.0 * cosip) / (1.0 + cosip))

          {recCopy, sinip, cosip, xincp}
        else
          recCopy =
            Map.put(recCopy, :aycof, -0.5 * recCopy.j3oj2 * sinip)
            |> Map.put(:xlcof, -0.25 * recCopy.j3oj2 * sinip * (3.0 + 5.0 * cosip) / temp4)

          {recCopy, sinip, cosip, xincp}
        end
      else
        {recCopy, sinip, cosip, xincp}
      end

    axnl = recCopy.ep * :math.cos(recCopy.argpp)
    temp = 1.0 / (recCopy.am * (1.0 - recCopy.ep * recCopy.ep))
    aynl = recCopy.ep * :math.sin(recCopy.argpp) + temp * recCopy.aycof
    xl = recCopy.mp + recCopy.argpp + recCopy.nodep + temp * recCopy.xlcof * axnl

    u = :math.fmod(xl - recCopy.nodep, Constants.twopi())
    eo1 = u
    tem5 = 9999.9
    ktr = 1
    sineo1 = 0
    coseo1 = 0

    # recursion instead of while loop
    {_u, _eo1, _tem5, _ktr, sineo1, coseo1, axnl, aynl} =
      keplerIterator(
        u,
        eo1,
        tem5,
        ktr,
        sineo1,
        coseo1,
        axnl,
        aynl
      )

    ecose = axnl * coseo1 + aynl * sineo1
    esine = axnl * sineo1 - aynl * coseo1
    el2 = axnl * axnl + aynl * aynl
    pl = recCopy.am * (1.0 - el2)

    if pl < 0.0 do
      Logger.error("SGP4 Error type 4")
      throw(Exception)
    end

    rl = recCopy.am * (1.0 - ecose)
    rdotl = :math.sqrt(recCopy.am) * esine / rl
    rvdotl = :math.sqrt(pl) / rl
    betal = :math.sqrt(1.0 - el2)
    temp = esine / (1.0 + betal)
    sinu = recCopy.am / rl * (sineo1 - aynl - axnl * temp)
    cosu = recCopy.am / rl * (coseo1 - axnl + aynl * temp)
    su = :math.atan2(sinu, cosu)
    sin2u = (cosu + cosu) * sinu
    cos2u = 1.0 - 2.0 * sinu * sinu
    temp = 1.0 / pl
    temp1 = 0.5 * recCopy.j2 * temp
    temp2 = temp1 * temp

    recCopy =
      if recCopy.method == "d" do
        cosisq = cosip * cosip

        Map.put(recCopy, :con41, 3.0 * cosisq - 1.0)
        |> Map.put(:x1mth2, 1.0 - cosisq)
        |> Map.put(:x7thm1, 7.0 * cosisq - 1.0)
      else
        recCopy
      end

    mrt = rl * (1.0 - 1.5 * temp2 * betal * recCopy.con41) + 0.5 * temp1 * recCopy.x1mth2 * cos2u
    su = su - 0.25 * temp2 * recCopy.x7thm1 * sin2u
    xnode = recCopy.nodep + 1.5 * temp2 * cosip * sin2u
    xinc = xincp + 1.5 * temp2 * cosip * sinip * cos2u
    mvt = rdotl - recCopy.nm * temp1 * recCopy.x1mth2 * sin2u / recCopy.xke

    rvdot =
      rvdotl + recCopy.nm * temp1 * (recCopy.x1mth2 * cos2u + 1.5 * recCopy.con41) / recCopy.xke

    # orientation vectors
    sinsu = :math.sin(su)
    cossu = :math.cos(su)
    snod = :math.sin(xnode)
    cnod = :math.cos(xnode)
    sini = :math.sin(xinc)
    cosi = :math.cos(xinc)
    xmx = -snod * cosi
    xmy = cnod * cosi
    ux = xmx * sinsu + cnod * cossu
    uy = xmy * sinsu + snod * cossu
    uz = sini * sinsu
    vx = xmx * cossu - cnod * sinsu
    vy = xmy * cossu - snod * sinsu
    vz = sini * cossu

    r0 = mrt * ux * recCopy.radiusearthkm
    r1 = mrt * uy * recCopy.radiusearthkm
    r2 = mrt * uz * recCopy.radiusearthkm
    r = [r0, r1, r2]
    v0 = (mvt * ux + rvdot * vx) * vkmpersec
    v1 = (mvt * uy + rvdot * vy) * vkmpersec
    v2 = (mvt * uz + rvdot * vz) * vkmpersec
    v = [v0, v1, v2]

    if mrt < 1.0 do
      Logger.error("SGP4 error type 6 - satellite decayed")
    end

    {r, v}
  end

  # solve for eccentric anomaly
  defp keplerIterator(u, eo1, tem5, ktr, sineo1, coseo1, axnl, aynl) do
    if abs(tem5) > 1.0e-12 and ktr < 10 do
      sineo1 = :math.sin(eo1)
      coseo1 = :math.cos(eo1)
      tem5 = 1.0 - coseo1 * axnl - sineo1 * aynl
      tem5 = (u - aynl * coseo1 + axnl * sineo1 - eo1) / tem5

      tem5 =
        if abs(tem5) > 0.95 do
          if tem5 > 0 do
            0.95
          else
            -0.95
          end
        end

      keplerIterator(u, eo1 + tem5, tem5, ktr + 1, sineo1, coseo1, axnl, aynl)
    else
      {u, eo1, tem5, ktr, sineo1, coseo1, axnl, aynl}
    end
  end
end
