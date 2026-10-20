defmodule AeMdw.MinerStats.Folder do
  @moduledoc """
  Folds the finalized generations into the mining stats in the background, so the first
  run is also the backfill of the whole chain and it never blocks the sync.

  Each chunk is written in a single transaction together with the height it reaches,
  so a generation is always folded exactly once, even after a crash or a restart.
  """

  use GenServer

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.TxnDbStore
  alias AeMdw.Log
  alias AeMdw.MinerStats.Facts
  alias AeMdw.MinerStats.Fold
  alias AeMdw.Sync.Hyperchain

  require Model

  @chunk_size 50
  @busy_delay 20
  @idle_delay :timer.seconds(30)
  @height_key :miner_stats_height

  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_args), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @spec folded_height(State.t()) :: non_neg_integer()
  def folded_height(state) do
    case State.get(state, Model.Stat, @height_key) do
      {:ok, Model.stat(payload: height)} -> height
      :not_found -> 0
    end
  end

  @doc """
  Folds the next generations of the database that weren't folded yet.
  """
  @spec fold_chunk(State.t(), pos_integer()) :: :more | :caught_up
  def fold_chunk(db_state, chunk_size \\ @chunk_size) do
    folded_height = folded_height(db_state)
    last_height = min(folded_height + chunk_size, State.height(db_state))

    if last_height > folded_height do
      generations = Enum.map((folded_height + 1)..last_height, &fetch_facts!(db_state, &1))

      TxnDbStore.transaction(fn store ->
        generations
        |> Enum.reduce(State.new(store), &Fold.fold(&2, &1))
        |> State.put(Model.Stat, Model.stat(index: @height_key, payload: last_height))
      end)

      if last_height < State.height(db_state), do: :more, else: :caught_up
    else
      :caught_up
    end
  end

  @impl GenServer
  def init(:ok) do
    schedule(@idle_delay)

    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:fold, state) do
    schedule(next_delay())

    {:noreply, state}
  end

  defp next_delay do
    if Hyperchain.hyperchain?() do
      :infinity
    else
      case fold_chunk(State.new()) do
        :more -> @busy_delay
        :caught_up -> @idle_delay
      end
    end
  rescue
    exception ->
      Log.warn("[miner_stats] fold failed: #{Exception.message(exception)}")
      @idle_delay
  end

  defp schedule(:infinity), do: :ok
  defp schedule(delay), do: Process.send_after(self(), :fold, delay)

  defp fetch_facts!(state, height) do
    case Facts.fetch(state, height) do
      {:ok, facts} -> facts
      {:error, reason} -> raise "no key block at #{height}: #{inspect(reason)}"
    end
  end
end
