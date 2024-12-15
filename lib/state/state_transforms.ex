defmodule SpaceDust.State.StateTransforms do
  @moduledoc """
  State vector transformations
  """

  alias SpaceDust.Math.Vector
  alias SpaceDust.State.StateVector, as: StateVector
  alias SpaceDust.Bodies.Earth, as: Earth

  @doc "convert a state vector from true equator mean equinox (TEME) to ECI J2000"
  def temeToEciJ2000(stateVector, utcEpoch) do
    case stateVector.referenceFrame do
      :teme ->
        precession = Earth.precessionAngles(utcEpoch)
        nutation = Earth.nutationAngles(utcEpoch)
        epsilon = nutation.mEps + nutation.dEps
        dPsiCosEps = nutation.dPsi * :math.cos(epsilon)

        # mean of date
        posMOD =
          stateVector.position
          |> Vector.rotateZ(-dPsiCosEps)
          |> Vector.rotateX(epsilon)
          |> Vector.rotateZ(-nutation.dPsi)
          |> Vector.rotateX(-nutation.mEps)

        velMOD =
          stateVector.velocity
          |> Vector.rotateZ(-dPsiCosEps)
          |> Vector.rotateX(epsilon)
          |> Vector.rotateZ(-nutation.dPsi)
          |> Vector.rotateX(-nutation.mEps)

        posJ2000 =
          posMOD
          |> Vector.rotateZ(precession.z)
          |> Vector.rotateZ(-precession.theta)
          |> Vector.rotateZ(precession.zeta)

        velJ2000 =
          velMOD
          |> Vector.rotateZ(precession.z)
          |> Vector.rotateY(-precession.theta)
          |> Vector.rotateZ(precession.zeta)

        %StateVector{
          position: posJ2000,
          velocity: velJ2000,
          epoch: utcEpoch,
          referenceFrame: SpaceDust.State.ReferenceFrame.eci_j2000()
        }

      :eci_j2000 ->
        stateVector

      _ ->
        raise ArgumentError, message: "Unsupported reference frame"
    end
  end
end
