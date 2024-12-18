defmodule SpaceDust.Propagator.SGP4.Satrec do
  defstruct [
    :epoch,
    :xndt2o,
    :xndd6o,
    :bstar,
    :xincl,
    :xnodeo,
    :eo,
    :omegao,
    :xmo,
    :xno,
    :atime,
    :del1,
    :del2,
    :del3,
    :t,
    :xli,
    :xni,
    :x1m5th,
    :xhdot1,
    :xpdot,
    :xnodcf,
    :xnode,
    :em,
    :inclm,
    :mm,
    :nm,
    :nodem,
    :irez,
    :d2201,
    :d2211,
    :d3210,
    :d3222,
    :d4410,
    :d4422,
    :d5220,
    :d5232,
    :d5421,
    :d5433,
    :dedt,
    :didt,
    :dmdt,
    :dnodt,
    :domdt,
    :e3,
    :ee2,
    :peo,
    :pgho,
    :pho,
    :pinco,
    :plo,
    :se2,
    :se3,
    :sgh2,
    :sgh3,
    :sgh4,
    :sh2,
    :sh3,
    :si2,
    :si3,
    :sl2,
    :sl3,
    :sl4,
    :gsto,
    :xfact,
    :xgh2,
    :xgh3
  ]

  @moduledoc """
  SGP4 satellite record
  """

  @type t() :: %SpaceDust.Propagator.SGP4.Satrec{
          epoch: number,
          xndt2o: number,
          xndd6o: number,
          bstar: number,
          xincl: number,
          xnodeo: number,
          eo: number,
          omegao: number,
          xmo: number,
          xno: number,
          xfact: number,
          xli: number,
          xni: number,
          atime: number,
          del1: number,
          del2: number,
          del3: number,
          t: number,
          xli: number,
          xni: number,
          x1m5th: number,
          xhdot1: number,
          xpdot: number,
          xnodcf: number,
          xnode: number,
          em: number,
          inclm: number,
          mm: number,
          nm: number,
          nodem: number,
          irez: number,
          d2201: number,
          d2211: number,
          d3210: number,
          d3222: number,
          d4410: number,
          d4422: number,
          d5220: number,
          d5232: number,
          d5421: number,
          d5433: number,
          dedt: number,
          del1: number,
          del2: number,
          del3: number,
          didt: number,
          dmdt: number,
          dnodt: number,
          domdt: number,
          e3: number,
          ee2: number,
          peo: number,
          pgho: number,
          pho: number,
          pinco: number,
          plo: number,
          se2: number,
          se3: number,
          sgh2: number,
          sgh3: number,
          sgh4: number,
          sh2: number,
          sh3: number,
          si2: number,
          si3: number,
          sl2: number,
          sl3: number,
          sl4: number,
          gsto: number,
          xfact: number,
          xgh2: number,
          xgh3: number
        }
end