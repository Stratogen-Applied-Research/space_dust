defmodule SpaceDust.Data.LeapSecond do
  @julianDateLeapSeconds [
    {2_441_317.5, 10},
    {2_441_499.5, 11},
    {2_441_683.5, 12},
    {2_442_048.5, 13},
    {2_442_413.5, 14},
    {2_442_778.5, 15},
    {2_443_144.5, 16},
    {2_443_509.5, 17},
    {2_443_874.5, 18},
    {2_444_239.5, 19},
    {2_444_786.5, 20},
    {2_445_151.5, 21},
    {2_445_516.5, 22},
    {2_446_247.5, 23},
    {2_447_161.5, 24},
    {2_447_892.5, 25},
    {2_448_257.5, 26},
    {2_448_804.5, 27},
    {2_449_169.5, 28},
    {2_449_534.5, 29},
    {2_450_083.5, 30},
    {2_450_630.5, 31},
    {2_451_179.5, 32},
    {2_453_736.5, 33},
    {2_454_832.5, 34},
    {2_456_109.5, 35},
    {2_457_204.5, 36},
    {2_457_754.5, 37}
  ]

  @spec julianDateToLeapSeconds(Float) :: Integer
  def julianDateToLeapSeconds(julianDate) do
    # find the value at the first key that us less than the julian date
    leapSecondIndex =
      Enum.find_index(@julianDateLeapSeconds, fn {key, _} -> key > julianDate end) - 1

    leapSeconds = Enum.at(@julianDateLeapSeconds, leapSecondIndex)

    case leapSeconds do
      nil ->
        IO.warn("No leap second data for julian date #{julianDate}! Returning default of 37")
        37

      {_, value} ->
        value
    end
  end
end
