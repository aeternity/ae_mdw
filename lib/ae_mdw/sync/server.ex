defmodule AeMdw.Sync.Server do
  @moduledoc """
  Subscribes to chain events for dealing with new blocks and block
  invalidations.

  Internally keeps track of the generations that have been synced.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.Block
  alias AeMdw.Db.Sync.Invalidate
  alias AeMdw.Log

  require Model

  use GenServer

  defstruct [:sync_pid, :fork_height, :current_height]

  @unsynced_gens 1
  @max_blocks_sync 600

  @spec start_link(GenServer.options()) :: GenServer.on_start()
  def start_link(_opts),
    do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @spec start_sync() :: :ok
  def start_sync, do: GenServer.cast(__MODULE__, :start_sync)

  @impl true
  def init([]) do
    current_height = Block.synced_height()

    {:ok, %__MODULE__{current_height: current_height}}
  end

  @impl true
  def handle_cast(:start_sync, state) do
    :aec_events.subscribe(:chain)
    :aec_events.subscribe(:top_changed)

    {:noreply, process_state(state)}
  end

  def handle_cast({:done, height}, state) do
    new_state = process_state(%__MODULE__{state | current_height: height, sync_pid: nil})

    {:noreply, new_state}
  end

  @impl true
  def handle_info(
        {:gproc_ps_event, :top_changed, %{info: %{block_type: :key, height: height}}},
        %__MODULE__{fork_height: old_fork_height} = s
      ) do
    header_candidates =
      height
      |> :aec_db.find_headers_at_height()
      |> Enum.filter(&(:aec_headers.type(&1) == :key))

    new_state =
      if length(header_candidates) > 1 do
        # FORK!
        main_header =
          Enum.find_value(header_candidates, fn header ->
            {:ok, header_hash} = :aec_headers.hash_header(header)

            # COSTLY!
            :aec_chain_state.hash_is_in_main_chain(header_hash) && header
          end)

        new_fork_height = :aec_headers.height(main_header)

        fork_height =
          (old_fork_height && min(old_fork_height, new_fork_height)) || new_fork_height

        %__MODULE__{s | fork_height: fork_height}
      else
        s
      end

    {:noreply, process_state(new_state)}
  end

  def handle_info({:gproc_ps_event, :top_changed, %{info: %{block_type: :micro}}}, s),
    do: {:noreply, s}

  defp process_state(
         %__MODULE__{current_height: current_height, sync_pid: nil, fork_height: fork_height} = s
       ) do
    top_height = height() - @unsynced_gens

    sync_pid =
      cond do
        not is_nil(fork_height) and fork_height <= current_height ->
          spawn_invalidate(fork_height)

        current_height < top_height ->
          spawn_sync(current_height + 1, min(current_height + @max_blocks_sync, top_height))


        true ->
          nil
      end

    %__MODULE__{s | sync_pid: sync_pid, fork_height: nil}
  end

  defp process_state(s), do: s

  defp spawn_sync(from_height, to_height) do
    spawn_link(fn ->
      Block.sync(from_height, to_height)

      GenServer.cast(__MODULE__, {:done, to_height})
    end)
  end

  defp spawn_invalidate(height) do
    spawn_link(fn ->
      Log.info("invalidation #{height}")
      Invalidate.invalidate(height)

      GenServer.cast(__MODULE__, {:done, height - 1})
    end)
  end

  defp height, do: :aec_headers.height(:aec_chain.top_header())
end
