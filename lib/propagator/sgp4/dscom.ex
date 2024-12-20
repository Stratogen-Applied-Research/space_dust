defmodule SpaceDust.Propagator.SGP4.Dscom do
  @moduledoc """
  provides deep space common items used by both the secular and periodics code
  """

  alias SpaceDust.Propagator.SGP4.Satrec, as: Satrec
  alias SpaceDust.Utils.Constants, as: Constants

  # elixir doesn't have for loops so we need to use recursion
  defp dscomloop(
         lsflg,
         zcosg,
         zcosh,
         zsing,
         zcosi,
         zsinh,
         zsini,
         cc,
         betasq,
         xnoi,
         rec
       ) do
    recCopy =
      Map.from_struct(rec)
      |> Map.put(:__struct__, Satrec)
      |> struct()

    a1 = zcosg * zcosh + zsing * zcosi * zsinh
    a3 = -zsing * zcosh + zcosg * zcosi * zsinh
    a7 = -zcosg * zsinh + zsing * zcosi * zcosh
    a8 = zsing * zsini
    a9 = zsing * zsinh + zcosg * zcosi * zcosh
    a10 = zcosg * zsini
    a2 = rec.cosim * a7 + rec.sinim * a8
    a4 = rec.cosim * a9 + rec.sinim * a10
    a5 = -rec.sinim * a7 + rec.cosim * a8
    a6 = -rec.sinim * a9 + rec.cosim * a10

    x1 = a1 * rec.cosomm + a2 * rec.sinomm
    x2 = a3 * rec.cosomm + a4 * rec.sinomm
    x3 = -a1 * rec.sinomm + a2 * rec.cosomm
    x4 = -a3 * rec.sinomm + a4 * rec.cosomm
    x5 = a5 * rec.sinomm
    x6 = a6 * rec.sinomm
    x7 = a5 * rec.cosomm
    x8 = a6 * rec.cosomm

    recCopy = Map.put(recCopy, :z31, 12.0 * x1 * x1 - 3.0 * x3 * x3)
    recCopy = Map.put(recCopy, :z32, 24.0 * x1 * x2 - 6.0 * x3 * x4)
    recCopy = Map.put(recCopy, :z33, 12.0 * x2 * x2 - 3.0 * x4 * x4)
    recCopy = Map.put(recCopy, :z1, 3.0 * (a1 * a1 + a2 * a2) + recCopy.z31 * recCopy.emsq)
    recCopy = Map.put(recCopy, :z2, 6.0 * (a1 * a3 + a2 * a4) + recCopy.z32 * recCopy.emsq)
    recCopy = Map.put(recCopy, :z3, 3.0 * (a3 * a3 + a4 * a4) + recCopy.z33 * recCopy.emsq)

    recCopy =
      Map.put(recCopy, :z11, -6.0 * a1 * a5 + recCopy.emsq * (-24.0 * x1 * x7 - 6.0 * x3 * x5))

    recCopy =
      Map.put(
        recCopy,
        :z12,
        -6.0 * (a1 * a6 + a3 * a5) +
          rec.emsq *
            (-24.0 * (x2 * x7 + x1 * x8) - 6.0 * (x3 * x6 + x4 * x5))
      )

    recCopy =
      Map.put(recCopy, :z13, -6.0 * a3 * a6 + rec.emsq * (-24.0 * x2 * x8 - 6.0 * x4 * x6))

    recCopy = Map.put(recCopy, :z21, 6.0 * a2 * a5 + rec.emsq * (24.0 * x1 * x5 - 6.0 * x3 * x7))

    recCopy =
      Map.put(
        recCopy,
        :z22,
        6.0 * (a4 * a5 + a2 * a6) +
          rec.emsq *
            (24.0 * (x2 * x5 + x1 * x6) - 6.0 * (x4 * x7 + x3 * x8))
      )

    recCopy = Map.put(recCopy, :z23, 6.0 * a4 * a6 + rec.emsq * (24.0 * x2 * x6 - 6.0 * x4 * x8))
    recCopy = Map.put(recCopy, :z1, rec.z1 + rec.z1 + betasq * rec.z31)
    recCopy = Map.put(recCopy, :z2, rec.z2 + rec.z2 + betasq * rec.z32)
    recCopy = Map.put(recCopy, :z3, rec.z3 + rec.z3 + betasq * rec.z33)
    recCopy = Map.put(recCopy, :s3, cc * xnoi)
    recCopy = Map.put(recCopy, :s2, -0.5 * rec.s3 / rec.rtemsq)
    recCopy = Map.put(recCopy, :s4, rec.s3 * rec.rtemsq)
    recCopy = Map.put(recCopy, :s1, -15.0 * rec.em * rec.s4)
    recCopy = Map.put(recCopy, :s5, x1 * x3 + x2 * x4)
    recCopy = Map.put(recCopy, :s6, x2 * x3 + x1 * x4)
    recCopy = Map.put(recCopy, :s7, x2 * x4 - x1 * x3)

    # /* ----------------------- do lunar terms ------------------- */
    if lsflg == 1 do
      recCopy = Map.put(recCopy, :ss1, recCopy.s1)
      recCopy = Map.put(recCopy, :ss2, recCopy.s2)
      recCopy = Map.put(recCopy, :ss3, recCopy.s3)
      recCopy = Map.put(recCopy, :ss4, recCopy.s4)
      recCopy = Map.put(recCopy, :ss5, recCopy.s5)
      recCopy = Map.put(recCopy, :ss6, recCopy.s6)
      recCopy = Map.put(recCopy, :ss7, recCopy.s7)
      recCopy = Map.put(recCopy, :sz1, recCopy.z1)
      recCopy = Map.put(recCopy, :sz2, recCopy.z2)
      recCopy = Map.put(recCopy, :sz3, recCopy.z3)
      recCopy = Map.put(recCopy, :sz11, recCopy.z11)
      recCopy = Map.put(recCopy, :sz12, recCopy.z12)
      recCopy = Map.put(recCopy, :sz13, recCopy.z13)
      recCopy = Map.put(recCopy, :sz21, recCopy.z21)
      recCopy = Map.put(recCopy, :sz22, recCopy.z22)
      recCopy = Map.put(recCopy, :sz23, recCopy.z23)
      recCopy = Map.put(recCopy, :sz31, recCopy.z31)
      recCopy = Map.put(recCopy, :sz32, recCopy.z32)
      recCopy = Map.put(recCopy, :sz33, recCopy.z33)

      recCopy
    else
      recCopy
    end
  end

  @doc """
  deep space common items
  inputs:
   -
  """
  def dscom(epoch, ep, argpp, tc, inclp, nodep, np, rec) do
    # constants
    zes = 0.01675
    zel = 0.05490
    c1ss = 2.9864797e-6
    c1l = 4.7968065e-7
    zsinis = 0.39785416
    zcosis = 0.91744867
    zcosgs = 0.1945905
    zsings = -0.98088458

    # copy the satrec object to avoid mutation
    recCopy =
      Map.from_struct(rec)
      |> Map.put(:__struct__, Satrec)
      |> struct()
      |> Map.put(:nm, np)
      |> Map.put(:em, ep)
      |> Map.put(:snodm, :math.sin(nodep))
      |> Map.put(:cnodm, :math.cos(nodep))
      |> Map.put(:sinomm, :math.sin(argpp))
      |> Map.put(:cosomm, :math.cos(argpp))
      |> Map.put(:sinim, :math.sin(inclp))
      |> Map.put(:cosim, :math.cos(inclp))
      |> Map.put(:emsq, ep * ep)

    betasq = 1.0 - recCopy.emsq

    recCopy =
      Map.put(recCopy, :rtemsq, :math.sqrt(betasq))
      |> Map.put(:peo, 0.0)
      |> Map.put(:pinco, 0.0)
      |> Map.put(:plo, 0.0)
      |> Map.put(:pgho, 0.0)
      |> Map.put(:pho, 0.0)
      |> Map.put(:day, epoch + 18261.5 + tc / 1440.0)

    # lunar terms
    xnodce = :math.fmod(4.5236020 - 9.2422029e-4 * recCopy.day, Constants.twopi())
    stem = :math.sin(xnodce)
    ctem = :math.cos(xnodce)
    zcosil = 0.91375164 - 0.03568096 * ctem
    zsinil = :math.sqrt(1.0 - zcosil * zcosil)
    zsinhl = 0.089683511 * stem / zsinil
    zcoshl = :math.sqrt(1.0 - zsinhl * zsinhl)
    gam = 5.8351514 + 0.0019443680 * recCopy.day
    zx = 0.39785416 * stem / zsinil
    zy = zcoshl * ctem + 0.91744867 * zsinhl * stem
    zx = :math.atan2(zx, zy)
    zx = gam + zx - xnodce
    zcosgl = :math.cos(zx)
    zsingl = :math.sin(zx)
    # insert gamma to rec struct
    recCopy = Map.put(recCopy, :gam, gam)

    # solar terms
    zcosg = zcosgs
    zsing = zsings
    zcosi = zcosis
    zsini = zsinis
    zcosh = recCopy.cnodm
    zsinh = recCopy.snodm
    cc = c1ss
    xnoi = 1.0 / recCopy.nm

    # this loop only runs twice in the original (range 1..3 start inclusive end exclusive) - we'll just call it twice
    lsflg = 1

    recCopy =
      dscomloop(
        lsflg,
        zcosg,
        zcosh,
        zsing,
        zcosi,
        zsinh,
        zsini,
        cc,
        betasq,
        xnoi,
        recCopy
      )

    zcosg = zcosgl
    zsing = zsingl
    zcosi = zcosil
    zsini = zsinil
    zcosh = zcoshl * rec.cnodm + zsinhl * rec.snodm
    zsinh = rec.snodm * zcoshl - rec.cnodm * zsinhl
    cc = c1l

    lsflg = 2

    recCopy =
      dscomloop(
        lsflg,
        zcosg,
        zcosh,
        zsing,
        zcosi,
        zsinh,
        zsini,
        cc,
        betasq,
        xnoi,
        recCopy
      )

    recCopy =
      Map.put(
        recCopy,
        :zmol,
        :math.fmod(4.7199672 + 0.22997150 * recCopy.day - recCopy.gam, Constants.twopi())
      )

    recCopy =
      Map.put(
        recCopy,
        :zmos,
        :math.fmod(6.2565837 + 0.017201977 * recCopy.day, Constants.twopi())
      )

    # /* ------------------------ do solar terms ---------------------- */
    recCopy = Map.put(recCopy, :se2, 2.0 * recCopy.ss1 * recCopy.ss6)
    recCopy = Map.put(recCopy, :se3, 2.0 * recCopy.ss1 * recCopy.ss7)
    recCopy = Map.put(recCopy, :si2, 2.0 * recCopy.ss2 * recCopy.sz12)
    recCopy = Map.put(recCopy, :si3, 2.0 * recCopy.ss2 * (recCopy.sz13 - recCopy.sz11))
    recCopy = Map.put(recCopy, :sl2, -2.0 * recCopy.ss3 * recCopy.sz2)
    recCopy = Map.put(recCopy, :sl3, -2.0 * recCopy.ss3 * (recCopy.sz3 - recCopy.sz1))
    recCopy = Map.put(recCopy, :sl4, -2.0 * recCopy.ss3 * (-21.0 - 9.0 * recCopy.emsq) * zes)
    recCopy = Map.put(recCopy, :sgh2, 2.0 * recCopy.ss4 * recCopy.sz32)
    recCopy = Map.put(recCopy, :sgh3, 2.0 * recCopy.ss4 * (recCopy.sz33 - recCopy.sz31))
    recCopy = Map.put(recCopy, :sgh4, -18.0 * recCopy.ss4 * zes)
    recCopy = Map.put(recCopy, :sh2, -2.0 * recCopy.ss2 * recCopy.sz22)
    recCopy = Map.put(recCopy, :sh3, -2.0 * recCopy.ss2 * (recCopy.sz23 - recCopy.sz21))

    # /* ------------------------ do lunar terms ---------------------- */
    recCopy = Map.put(recCopy, :ee2, 2.0 * recCopy.s1 * recCopy.s6)
    recCopy = Map.put(recCopy, :e3, 2.0 * recCopy.s1 * recCopy.s7)
    recCopy = Map.put(recCopy, :xi2, 2.0 * recCopy.s2 * recCopy.z12)
    recCopy = Map.put(recCopy, :xi3, 2.0 * recCopy.s2 * (recCopy.z13 - recCopy.z11))
    recCopy = Map.put(recCopy, :xl2, -2.0 * recCopy.s3 * recCopy.z2)
    recCopy = Map.put(recCopy, :xl3, -2.0 * recCopy.s3 * (recCopy.z3 - recCopy.z1))
    recCopy = Map.put(recCopy, :xl4, -2.0 * recCopy.s3 * (-21.0 - 9.0 * recCopy.emsq) * zel)
    recCopy = Map.put(recCopy, :xgh2, 2.0 * recCopy.s4 * recCopy.z32)
    recCopy = Map.put(recCopy, :xgh3, 2.0 * recCopy.s4 * (recCopy.z33 - recCopy.z31))
    recCopy = Map.put(recCopy, :xgh4, -18.0 * recCopy.s4 * zel)
    recCopy = Map.put(recCopy, :xh2, -2.0 * recCopy.s2 * recCopy.z22)
    recCopy = Map.put(recCopy, :xh3, -2.0 * recCopy.s2 * (recCopy.z23 - recCopy.z21))

    # return the satrec map
    recCopy
  end
end
