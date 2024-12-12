defmodule SpaceDust.Math.Matrix.Matrix3x3 do
  @moduledoc """
  A 3x3 matrix
  """

  defstruct [
    :m11,
    :m12,
    :m13,
    :m21,
    :m22,
    :m23,
    :m31,
    :m32,
    :m33
  ]
end

defmodule SpaceDust.Math.Matrix do
  @moduledoc """
  Matrix operations
  """
  alias SpaceDust.Math.Matrix.Matrix3x3, as: Matrix3x3

  @type matrix() :: %Matrix3x3{
          m11: number,
          m12: number,
          m13: number,
          m21: number,
          m22: number,
          m23: number,
          m31: number,
          m32: number,
          m33: number
        }

  @doc "create a 3x3 matrix from a nested list"
  @spec fromNestedList([[number]]) :: matrix()
  def fromNestedList([[m11, m12, m13], [m21, m22, m23], [m31, m32, m33]]) do
    %Matrix3x3{
      m11: m11,
      m12: m12,
      m13: m13,
      m21: m21,
      m22: m22,
      m23: m23,
      m31: m31,
      m32: m32,
      m33: m33
    }
  end

  @spec multiply(matrix(), matrix()) :: matrix()
  @doc "multiply two 3x3 matrices"
  def multiply(a, b) do
    %Matrix3x3{
      m11: a.m11 * b.m11 + a.m12 * b.m21 + a.m13 * b.m31,
      m12: a.m11 * b.m12 + a.m12 * b.m22 + a.m13 * b.m32,
      m13: a.m11 * b.m13 + a.m12 * b.m23 + a.m13 * b.m33,
      m21: a.m21 * b.m11 + a.m22 * b.m21 + a.m23 * b.m31,
      m22: a.m21 * b.m12 + a.m22 * b.m22 + a.m23 * b.m32,
      m23: a.m21 * b.m13 + a.m22 * b.m23 + a.m23 * b.m33,
      m31: a.m31 * b.m11 + a.m32 * b.m21 + a.m33 * b.m31,
      m32: a.m31 * b.m12 + a.m32 * b.m22 + a.m33 * b.m32,
      m33: a.m31 * b.m13 + a.m32 * b.m23 + a.m33 * b.m33
    }
  end
end
