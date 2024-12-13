defmodule SpaceDust.Math.Functions do
  @moduledoc """
  Math utility functions
  """

  @spec polyEval([number], number) :: number
  @doc "evaluate a polynomial with coefficients ordered from highest to lowest"
  def polyEval(coefficients, x) do
    Enum.reduce(coefficients, 0, fn c, acc -> acc * x + c end)
  end

  @spec linearInterpolate(number, number, number, number, number) :: number
  @doc "linearly interpolate between two points"
  def linearInterpolate(x1, y1, x2, y2, x) do
    y1 + (y2 - y1) * (x - x1) / (x2 - x1)
  end

  @spec linearInterpolate(number, number, number) :: number
  @doc "linearly interpolate between two points"
  def linearInterpolate(y1, y2, fraction) do
    y1 + (y2 - y1) * fraction
  end
end
