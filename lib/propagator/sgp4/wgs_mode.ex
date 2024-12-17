defmodule SpaceDust.Propagator.SGP4.WGSmode do
  @moduledoc """
  WGS mode for SGP4 propagator
  """

  # use atoms instead of integers for readability
  def wgs72old, do: :wgs72old

  def wgs72, do: :wgs72

  def wgs84, do: :wgs84
end
