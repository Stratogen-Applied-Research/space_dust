defmodule SpaceDust.Math.Vector.Vector3D do
  @moduledoc """
  A 3D vector
  """

  defstruct [
    :x,
    :y,
    :z
  ]
end

defmodule SpaceDust.Math.Vector do
  @moduledoc """
  Vector operations
  """

  alias SpaceDust.Math.Vector.Vector3D, as: Vector3D
  alias SpaceDust.Math.Matrix, as: Matrix

  @type vector() :: %Vector3D{
          x: number,
          y: number,
          z: number
        }

  @doc "create a 3D vector from a list"
  @spec fromList([number]) :: vector()
  def fromList([x, y, z]) do
    %Vector3D{
      x: x,
      y: y,
      z: z
    }
  end

  @spec add(vector(), vector()) :: vector()
  @doc "add two 3D vectors"
  def add(a, b) do
    %Vector3D{
      x: a.x + b.x,
      y: a.y + b.y,
      z: a.z + b.z
    }
  end

  @spec subtract(vector(), vector()) :: vector()
  @doc "subtract two 3D vectors"
  def subtract(a, b) do
    %Vector3D{
      x: a.x - b.x,
      y: a.y - b.y,
      z: a.z - b.z
    }
  end

  @spec dot(vector(), vector()) :: number
  @doc "dot product of two 3D vectors"
  def dot(a, b) do
    a.x * b.x + a.y * b.y + a.z * b.z
  end

  @spec cross(vector(), vector()) :: vector()
  @doc "cross product of two 3D vectors"
  def cross(a, b) do
    %Vector3D{
      x: a.y * b.z - a.z * b.y,
      y: a.z * b.x - a.x * b.z,
      z: a.x * b.y - a.y * b.x
    }
  end

  @spec magnitude(vector()) :: number
  @doc "magnitude of a 3D vector"
  def magnitude(a) do
    :math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
  end

  @spec normalize(vector()) :: vector()
  @doc "normalize a 3D vector"
  def normalize(a) do
    m = magnitude(a)

    %Vector3D{
      x: a.x / m,
      y: a.y / m,
      z: a.z / m
    }
  end

  @spec scale(vector(), number()) :: vector()
  @doc "scale a 3D vector"
  def scale(a, s) do
    %Vector3D{
      x: a.x * s,
      y: a.y * s,
      z: a.z * s
    }
  end

  @spec angle(vector(), vector()) :: number
  @doc "angle between two 3D vectors"
  def angle(a, b) do
    :math.acos(dot(a, b))
  end

  @spec rotate(vector(), Matrix.matrix()) :: vector()
  @doc "rotate a 3D vector by a 3x3 matrix"
  def rotate(a, m) do
    %Vector3D{
      x: a.x * m.m11 + a.y * m.m12 + a.z * m.m13,
      y: a.x * m.m21 + a.y * m.m22 + a.z * m.m23,
      z: a.x * m.m31 + a.y * m.m32 + a.z * m.m33
    }
  end

  @spec rotateAroundAxis(vector(), vector(), number) :: vector()
  @doc "rotate a 3D vector around an axis by an angle"
  def rotateAroundAxis(a, axis, angle) do
    c = :math.cos(angle)
    s = :math.sin(angle)
    t = 1 - c

    %Vector3D{
      x:
        (t * axis.x * axis.x + c) * a.x + (t * axis.x * axis.y - s * axis.z) * a.y +
          (t * axis.x * axis.z + s * axis.y) * a.z,
      y:
        (t * axis.x * axis.y + s * axis.z) * a.x + (t * axis.y * axis.y + c) * a.y +
          (t * axis.y * axis.z - s * axis.x) * a.z,
      z:
        (t * axis.x * axis.z - s * axis.y) * a.x + (t * axis.y * axis.z + s * axis.x) * a.y +
          (t * axis.z * axis.z + c) * a.z
    }
  end

  @spec rotateZ(vector(), number) :: vector()
  @doc "rotate a 3D vector about the z-axis"
  def rotateZ(a, angle) do
    rotateAroundAxis(a, fromList([0, 0, 1]), angle)
  end

  @spec rotateY(vector(), number) :: vector()
  @doc "rotate a 3D vector about the y-axis"
  def rotateY(a, angle) do
    rotateAroundAxis(a, fromList([0, 1, 0]), angle)
  end

  @spec rotateX(vector(), number) :: vector()
  @doc "rotate a 3D vector about the x-axis"
  def rotateX(a, angle) do
    rotateAroundAxis(a, fromList([1, 0, 0]), angle)
  end
end
