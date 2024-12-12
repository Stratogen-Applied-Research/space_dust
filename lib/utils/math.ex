defmodule SpaceDust.Utils.Math do
  @moduledoc """
  Math utility functions
  """

  @doc "evaluate a polynomial with coefficients ordered from highest to lowest"
  def polyEval(coefficients, x) do
    Enum.reduce(coefficients, 0, fn(c, acc) -> acc * x + c end)
  end
end
