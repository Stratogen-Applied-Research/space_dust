defmodule MathTest do
  use ExUnit.Case

  alias SpaceDust.Math.Functions, as: Functions
  alias SpaceDust.Math.Matrix, as: Matrix
  alias SpaceDust.Math.Matrix.Matrix3x3, as: Matrix3x3
  alias SpaceDust.Math.Vector, as: Vector
  alias SpaceDust.Math.Vector.Vector3D, as: Vector3D

  # function tests
  test "evaluate a polynomial" do
    coefficients = [1, 2, 3]
    x = 2
    result = Functions.polyEval(coefficients, x)
    assert result == 11
  end

  # matrix tests
  test "create matrix from nested list" do
    matrix = Matrix.fromNestedList([[1, 2, 3], [4, 5, 6], [7, 8, 9]])

    assert matrix == %Matrix3x3{
             m11: 1,
             m12: 2,
             m13: 3,
             m21: 4,
             m22: 5,
             m23: 6,
             m31: 7,
             m32: 8,
             m33: 9
           }
  end

  test "multiply two 3x3 matrices" do
    a = Matrix.fromNestedList([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
    b = Matrix.fromNestedList([[9, 8, 7], [6, 5, 4], [3, 2, 1]])
    result = Matrix.multiply(a, b)
    assert result == Matrix.fromNestedList([[30, 24, 18], [84, 69, 54], [138, 114, 90]])
  end

  # vector tests
  test "create vector from list" do
    vector = Vector.fromList([1, 2, 3])
    assert vector == %Vector3D{x: 1, y: 2, z: 3}
  end

  test "add two 3D vectors" do
    a = %Vector3D{x: 1, y: 2, z: 3}
    b = %Vector3D{x: 4, y: 5, z: 6}
    result = Vector.add(a, b)
    assert result == %Vector3D{x: 5, y: 7, z: 9}
  end

  test "subtract two 3D vectors" do
    a = %Vector3D{x: 1, y: 2, z: 3}
    b = %Vector3D{x: 4, y: 5, z: 6}
    result = Vector.subtract(a, b)
    assert result == %Vector3D{x: -3, y: -3, z: -3}
  end

  test "dot product of two 3D vectors" do
    a = %Vector3D{x: 1, y: 2, z: 3}
    b = %Vector3D{x: 4, y: 5, z: 6}
    result = Vector.dot(a, b)
    assert result == 32
  end

  test "cross product of two 3D vectors" do
    a = %Vector3D{x: 1, y: 2, z: 3}
    b = %Vector3D{x: 4, y: 5, z: 6}
    result = Vector.cross(a, b)
    assert result == %Vector3D{x: -3, y: 6, z: -3}
  end

  test "magnitude of a 3D vector" do
    vector = %Vector3D{x: 1, y: 2, z: 3}
    result = Vector.magnitude(vector)
    assert result == 3.7416573867739413
  end
end
