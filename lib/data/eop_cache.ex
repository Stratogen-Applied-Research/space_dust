defmodule SpaceDust.Data.EOPCache do
  @moduledoc """
  ETS-based cache for Earth Orientation Parameters (EOP) data.

  This cache loads and parses EOP data once, then provides fast lookups
  with interpolation for any requested MJD (Modified Julian Date).

  The cache uses binary search for O(log n) lookups instead of linear search,
  and keeps the parsed data in ETS to avoid repeated file I/O and parsing.

  The cache initializes lazily on first access - no supervisor required.
  """

  require Logger

  alias SpaceDust.Data.EarthOrientationParameters
  alias SpaceDust.Data.EOP
  alias SpaceDust.Math.Functions

  # Data path - same as EOP module
  @eop_data_path Path.expand("../../data/finals_iau1980.txt", __DIR__)

  @table_name :eop_cache
  @data_key :eop_data
  @meta_key :eop_meta

  # Client API

  @doc """
  Get EOP data at a given MJD with interpolation.
  Uses cached data for fast lookups. Initializes cache on first call.
  """
  @spec get(float()) :: {:ok, EarthOrientationParameters.t()} | {:error, term()}
  def get(mjd) do
    ensure_initialized()
    lookup_eop(mjd)
  end

  @doc """
  Force reload of EOP data from source.
  """
  def reload do
    ensure_initialized()
    load_eop_data(force_pull: true)
    :ok
  end

  @doc """
  Get cache statistics.
  """
  def stats do
    ensure_initialized()

    case :ets.lookup(@table_name, @meta_key) do
      [{@meta_key, meta}] ->
        %{
          data_points: meta.data_count,
          min_mjd: meta.min_mjd,
          max_mjd: meta.max_mjd,
          loaded_at: meta.loaded_at
        }

      [] ->
        %{data_points: 0, min_mjd: nil, max_mjd: nil, loaded_at: nil}
    end
  end

  @doc """
  Check if the cache is initialized.
  """
  def initialized? do
    case :ets.whereis(@table_name) do
      :undefined -> false
      _tid -> :ets.member(@table_name, @data_key)
    end
  end

  # Ensure the cache is initialized (thread-safe)
  defp ensure_initialized do
    case :ets.whereis(@table_name) do
      :undefined ->
        # Create ETS table - use try/catch for race condition
        try do
          :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
          load_eop_data()
        catch
          :error, :badarg ->
            # Table already exists (race condition), that's fine
            # But make sure data is loaded
            unless :ets.member(@table_name, @data_key) do
              load_eop_data()
            end
        end

      _tid ->
        # Table exists, check if data is loaded
        unless :ets.member(@table_name, @data_key) do
          load_eop_data()
        end
    end

    :ok
  end

  # Load EOP data into the ETS cache
  defp load_eop_data(opts \\ []) do
    force_pull = Keyword.get(opts, :force_pull, false)

    raw_data =
      if force_pull do
        case EOP.pullEOPData() do
          {:ok, lines} ->
            EOP.saveEopData(lines)
            lines

          {:error, _reason} ->
            read_from_file()
        end
      else
        read_from_file()
      end

    case EOP.parseEopData(raw_data) do
      {:ok, eop_list} ->
        # Sort by MJD for binary search
        sorted = Enum.sort_by(eop_list, & &1.modifiedJulianDate)

        # Convert to tuple array for faster indexed access
        data_array = List.to_tuple(sorted)

        # Store in ETS
        :ets.insert(@table_name, {@data_key, data_array})

        # Store metadata
        meta = %{
          data_count: tuple_size(data_array),
          min_mjd: hd(sorted).modifiedJulianDate,
          max_mjd: List.last(sorted).modifiedJulianDate,
          loaded_at: DateTime.utc_now()
        }

        :ets.insert(@table_name, {@meta_key, meta})
        :ok

      {:error, reason} ->
        Logger.error("Failed to load EOP data: #{inspect(reason)}")
        :ets.insert(@table_name, {@data_key, {}})
        :ets.insert(@table_name, {@meta_key, %{data_count: 0, min_mjd: nil, max_mjd: nil, loaded_at: DateTime.utc_now()}})
        {:error, reason}
    end
  end

  defp read_from_file do
    case File.read(@eop_data_path) do
      {:ok, data} ->
        String.split(data, "\n")

      {:error, :enoent} ->
        Logger.warning("EOP data file not found at #{@eop_data_path}, downloading...")
        case EOP.pullEOPData() do
          {:ok, lines} ->
            EOP.saveEopData(lines)
            lines

          {:error, _reason} ->
            []
        end

      {:error, _reason} ->
        []
    end
  end

  defp lookup_eop(mjd) do
    [{@data_key, data_array}] = :ets.lookup(@table_name, @data_key)
    [{@meta_key, meta}] = :ets.lookup(@table_name, @meta_key)

    cond do
      tuple_size(data_array) == 0 ->
        {:error, "No EOP data loaded"}

      mjd > meta.max_mjd ->
        Logger.warning("MJD #{mjd} is after the last EOP data point")
        {:ok, elem(data_array, tuple_size(data_array) - 1)}

      mjd < meta.min_mjd ->
        Logger.warning("MJD #{mjd} is before the first EOP data point")
        {:ok, elem(data_array, 0)}

      true ->
        # Binary search for the bracket
        {prior, future} = binary_search_bracket(data_array, mjd, 0, tuple_size(data_array) - 1)
        {:ok, interpolate_between(prior, future, mjd)}
    end
  end

  # Binary search to find the two EOP entries that bracket the given MJD
  defp binary_search_bracket(data_array, mjd, low, high) when low < high do
    mid = div(low + high, 2)
    mid_eop = elem(data_array, mid)

    cond do
      mid_eop.modifiedJulianDate == mjd ->
        # Exact match
        {mid_eop, mid_eop}

      mid_eop.modifiedJulianDate < mjd ->
        if mid + 1 <= high do
          next_eop = elem(data_array, mid + 1)

          if next_eop.modifiedJulianDate >= mjd do
            # Found bracket
            {mid_eop, next_eop}
          else
            # Search right half
            binary_search_bracket(data_array, mjd, mid + 1, high)
          end
        else
          # At end, use last two
          {elem(data_array, high - 1), elem(data_array, high)}
        end

      true ->
        # mid_eop.modifiedJulianDate > mjd
        if mid > low do
          prev_eop = elem(data_array, mid - 1)

          if prev_eop.modifiedJulianDate <= mjd do
            # Found bracket
            {prev_eop, mid_eop}
          else
            # Search left half
            binary_search_bracket(data_array, mjd, low, mid - 1)
          end
        else
          # At start, use first two
          {elem(data_array, 0), elem(data_array, 1)}
        end
    end
  end

  defp binary_search_bracket(data_array, _mjd, low, high) when low >= high do
    # Edge case: return adjacent entries
    idx = max(0, min(low, tuple_size(data_array) - 2))
    {elem(data_array, idx), elem(data_array, idx + 1)}
  end

  defp interpolate_between(prior, future, _mjd) when prior == future do
    prior
  end

  defp interpolate_between(prior, future, mjd) do
    fraction =
      (mjd - prior.modifiedJulianDate) /
        (future.modifiedJulianDate - prior.modifiedJulianDate)

    %EarthOrientationParameters{
      modifiedJulianDate: mjd,
      polarMotionX: Functions.linearInterpolate(prior.polarMotionX, future.polarMotionX, fraction),
      polarMotionY: Functions.linearInterpolate(prior.polarMotionY, future.polarMotionY, fraction),
      ut1UTC: Functions.linearInterpolate(prior.ut1UTC, future.ut1UTC, fraction),
      dPsi: Functions.linearInterpolate(prior.dPsi, future.dPsi, fraction),
      dEps: Functions.linearInterpolate(prior.dEps, future.dEps, fraction),
      lod: Functions.linearInterpolate(prior.lod, future.lod, fraction)
    }
  end
end
