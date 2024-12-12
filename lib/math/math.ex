defmodule SpaceDust.Math.Functions do
  @moduledoc """
  Math utility functions
  """

  @spec polyEval([number], number) :: number
  @doc "evaluate a polynomial with coefficients ordered from highest to lowest"
  def polyEval(coefficients, x) do
    Enum.reduce(coefficients, 0, fn c, acc -> acc * x + c end)
  end
end
