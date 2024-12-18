defmodule SpaceDust.Propagator.SGP4.SGP4 do
  @moduledoc """
  Simplified General Perturbations 4 (SGP4) propagator - this is always in the TEME frame
  """

  alias SpaceDust.Propagator.SGP4.Satrec, as: Satrec
  alias SpaceDust.Utils.Constants, as: Constants

  @doc """
  deep-space long-period harmonic contributions
  inputs:
   -
  """
  def dpper(
        e3,
        ee2,
        peo,
        pgho,
        pho,
        pinco,
        plo,
        se2,
        se3,
        sgh2,
        sgh3,
        sgh4,
        sh2,
        sh3,
        si2,
        si3,
        sl2,
        sl3,
        sl4,
        t,
        xgh2,
        xgh3,
        xgh4,
        xh2,
        xh3,
        xi2,
        xi3,
        xl2,
        xl3,
        xl4,
        zmol,
        zmos,
        init,
        rec,
        opsmode
      ) do
    # create a copy of the satrec object to avoid mutation
    recCopy = Map.from_struct(rec) |> Map.put(:__struct__, Satrec) |> struct()

    # the original implementation from Dave/Bob/Felix is great but doesn't play nice with Elixir since it mutates the satrec object

    # Constants
    zns = 1.19459e-5
    zes = 0.01675
    znl = 1.5835218e-4
    zel = 0.05490

    # time-varying periodics
    zm =
      if init == "y" do
        zmos
      else
        zmos + zns * t
      end

    zf = zm + 2.0 * zes * :math.sin(zm)
    sinzf = :math.sin(zf)
    f2 = 0.5 * sinzf * sinzf - 0.25
    f3 = -0.5 * sinzf * :math.cos(zf)
    ses = se2 * f2 + se3 * f3
    sis = si2 * f2 + si3 * f3
    sls = sl2 * f2 + sl3 * f3 + sl4 * sinzf
    sghs = sgh2 * f2 + sgh3 * f3 + sgh4 * sinzf
    shs = sh2 * f2 + sh3 * f3

    zm =
      if init == "y" do
        zmol
      else
        zmol + znl * t
      end

    zf = zm + 2.0 * zel * :math.sin(zm)

    sinzf = :math.sin(zf)
    f2 = 0.5 * sinzf * sinzf - 0.25
    f3 = -0.5 * sinzf * :math.cos(zf)
    sel = ee2 * f2 + e3 * f3
    sil = xi2 * f2 + xi3 * f3
    sll = xl2 * f2 + xl3 * f3 + xl4 * sinzf
    sghl = xgh2 * f2 + xgh3 * f3 + xgh4 * sinzf
    shll = xh2 * f2 + xh3 * f3
    pe = ses + sel
    pinc = sis + sil
    pl = sls + sll
    pgh = sghs + sghl
    ph = shs + shll

    if init == "n" do
      pe = pe - peo
      pinc = pinc - pinco
      pl = pl - plo
      pgh = pgh - pgho
      ph = ph - pho
      recInclpModified = rec.inclp + pinc
      recEpModified = rec.ep + pe
      sinip = :math.sin(recInclpModified)
      cosip = :math.cos(recInclpModified)

      if recInclpModified >= 0.2 do
        ph = ph / sinip
        pgh = pgh - cosip * ph
        recArgpp = rec.argpp + pgh
        recNodep = rec.nodep + ph
        recMp = rec.mp + pl

        # modify the recCopy to include the new values
        Map.put(recCopy, :inclp, recInclpModified)
        |> Map.put(:ep, recEpModified)
        |> Map.put(:argpp, recArgpp)
        |> Map.put(:nodep, recNodep)
        |> Map.put(:mp, recMp)

        # RETURN HERE
      else
        sinop = :math.sin(rec.nodep)
        cosop = :math.cos(rec.nodep)
        alfdp = sinip * sinop
        betdp = sinip * cosop
        dalf = ph * cosop + pinc * cosip * sinop
        dbet = -ph * sinop + pinc * cosip * cosop
        alfdp = alfdp + dalf
        betdp = betdp + dbet
        recNodepInterim = :math.fmod(rec.nodep, Constants.twopi())
        # //  sgp4fix for afspc written intrinsic functions
        # // nodep used without a trigonometric function ahead
        recNodepModified =
          if recNodepInterim < 0.0 and opsmode == "a" do
            recNodepInterim + Constants.twopi()
          else
            recNodepInterim
          end

        xls = rec.mp + rec.argpp + cosip * recNodepModified
        dls = pl + pgh - pinc * recNodepModified * sinip
        xls = xls + dls
        xls = :math.fmod(xls, Constants.twopi())
        xnoh = recNodepModified
        recNodepModified = :math.atan2(alfdp, betdp)
        # //  sgp4fix for afspc written intrinsic functions
        # // nodep used without a trigonometric function ahead
        recNodepModified =
          if recNodepModified < 0.0 and opsmode == "a" do
            recNodepModified + Constants.twopi()
          end

        recNodepFinal =
          if abs(xnoh - recNodepModified) > :math.pi() do
            if recNodepModified < xnoh do
              recNodepModified + Constants.twopi()
            else
              recNodepModified - Constants.twopi()
            end
          end

        recMp = rec.mp + pl
        recArgpp = xls - rec.mp - cosip * recNodepModified

        # modify the recCopy to include the new values
        Map.put(recCopy, :inclp, recInclpModified)
        |> Map.put(:ep, recEpModified)
        |> Map.put(:nodep, recNodepFinal)
        |> Map.put(:argpp, recArgpp)
        |> Map.put(:mp, recMp)

        # RETURN HERE
      end
    else
      # if init == "y" we don't need to modify the recCopy
      recCopy

      # RETURN HERE
    end
  end
end
