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
end
