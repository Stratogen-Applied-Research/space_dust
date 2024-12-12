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

  test "transpose 3x3 matrix" do
    matrix = Matrix.fromNestedList([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
    result = Matrix.transpose(matrix)
    assert result == Matrix.fromNestedList([[1, 4, 7], [2, 5, 8], [3, 6, 9]])
  end

  test "3x3 matrix determinant" do
    matrix = Matrix.fromNestedList([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
    result = Matrix.determinant(matrix)
    assert result == 0
  end

  test "rotation matrix from euler" do
    result = Matrix.rotationMatrixFromEuler(0, 0, 0)
    assert result == Matrix.fromNestedList([[1, 0, 0], [0, 1, 0], [0, 0, 1]])
  end

  test "rotation matrix 90 about z" do
    result = Matrix.rotationMatrixFromEuler(0, 0, :math.pi() / 2)
    expected = Matrix.fromNestedList([[0, -1, 0], [1, 0, 0], [0, 0, 1]])
    assert_in_delta(Matrix.get(result, 1, 1), Matrix.get(expected, 1, 1), 1.0e-9)
    assert_in_delta(Matrix.get(result, 1, 2), Matrix.get(expected, 1, 2), 1.0e-9)
    assert_in_delta(Matrix.get(result, 1, 3), Matrix.get(expected, 1, 3), 1.0e-9)
    assert_in_delta(Matrix.get(result, 2, 1), Matrix.get(expected, 2, 1), 1.0e-9)
    assert_in_delta(Matrix.get(result, 2, 2), Matrix.get(expected, 2, 2), 1.0e-9)
    assert_in_delta(Matrix.get(result, 2, 3), Matrix.get(expected, 2, 3), 1.0e-9)
    assert_in_delta(Matrix.get(result, 3, 1), Matrix.get(expected, 3, 1), 1.0e-9)
    assert_in_delta(Matrix.get(result, 3, 2), Matrix.get(expected, 3, 2), 1.0e-9)
    assert_in_delta(Matrix.get(result, 3, 3), Matrix.get(expected, 3, 3), 1.0e-9)
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

  test "normalize a 3D vector" do
    vector = %Vector3D{x: 1, y: 2, z: 3}
    result = Vector.normalize(vector)

    assert result == %Vector3D{
             x: 0.2672612419124244,
             y: 0.5345224838248488,
             z: 0.8017837257372732
           }
  end

  test "angle between two 3D vectors" do
    a = %Vector3D{x: 0, y: 0, z: 3}
    b = %Vector3D{x: 4, y: 0, z: 0}
    result = Vector.angle(a, b)
    assert result == :math.pi() / 2
  end

  test "rotate vector using matrix" do
    vector = %Vector3D{x: 1, y: 0, z: 0}
    matrix = Matrix.rotationMatrixFromEuler(0, 0, :math.pi() / 2)
    result = Vector.rotate(vector, matrix)
    IO.inspect(result)
    assert_in_delta(result.x, 0, 1.0e-9)
    assert_in_delta(result.y, 1, 1.0e-9)
    assert_in_delta(result.z, 0, 1.0e-9)
  end
end
