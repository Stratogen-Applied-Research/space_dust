defmodule SpaceDust.Propagator.SGP4.Dsinit do
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
  end
end
