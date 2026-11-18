defmodule AeMdw.Db.Sync.ObjectKeys do
  @moduledoc """
  Counts active and inactive names and oracles, and contracts.

  Writes to the name and oracle tables go through put/3 and delete/3, which keep
  each table's count in Model.Stat. The counts are recounted at startup when the
  last synced generation didn't record them.
  """

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Log
  alias AeMdw.Node.Db
  alias AeMdw.Sync.SyncingQueue
  alias AeMdw.Txs

  import AeMdw.Util, only: [max_256bit_bin: 0, max_int: 0]

  require Model

  @type table() ::
          Model.ActiveName | Model.InactiveName | Model.ActiveOracle | Model.InactiveOracle

  @count_keys %{
    Model.ActiveName => :active_names_count,
    Model.InactiveName => :inactive_names_count,
    Model.ActiveOracle => :active_oracles_count,
    Model.InactiveOracle => :inactive_oracles_count
  }

  @counted_at_key :object_counts_at

  @spec load() :: :ok
  def load do
    SyncingQueue.push(fn ->
      _state = recount_if_stale(State.new())
      :ok
    end)
  end

  @doc """
  Recounts the tables unless the last synced generation recorded the counts.
  Runs before syncing starts.
  """
  @spec recount_if_stale(State.t()) :: State.t()
  def recount_if_stale(state) do
    counted_at = synced_at(state)

    case State.get(state, Model.Stat, @counted_at_key) do
      {:ok, Model.stat(payload: ^counted_at)} ->
        state

      _stale_or_not_found ->
        {time, state} =
          :timer.tc(fn ->
            Enum.reduce(@count_keys, state, fn {table, count_key}, state ->
              State.put(
                state,
                Model.Stat,
                Model.stat(index: count_key, payload: State.count_keys(state, table))
              )
            end)
          end)

        Log.info("[object_keys] recounted names and oracles in #{div(time, 1_000)}ms")

        State.put(state, Model.Stat, Model.stat(index: @counted_at_key, payload: counted_at))
    end
  end

  @doc """
  Records that the counts are up to date at the end of this generation.
  """
  @spec put_counted_at(State.t(), Blocks.height(), Txs.txi()) :: State.t()
  def put_counted_at(state, height, next_txi),
    do:
      State.put(
        state,
        Model.Stat,
        Model.stat(index: @counted_at_key, payload: {height, next_txi})
      )

  @spec put(State.t(), table(), Model.name() | Model.oracle()) :: State.t()
  def put(state, table, record) do
    if State.exists?(state, table, elem(record, 1)) do
      State.put(state, table, record)
    else
      state
      |> update_count(table, 1)
      |> State.put(table, record)
    end
  end

  @spec delete(State.t(), table(), Db.pubkey() | String.t()) :: State.t()
  def delete(state, table, key) do
    if State.exists?(state, table, key) do
      state
      |> update_count(table, -1)
      |> State.delete(table, key)
    else
      State.delete(state, table, key)
    end
  end

  @spec count(State.t(), table()) :: non_neg_integer()
  def count(state, table) do
    case State.get(state, Model.Stat, Map.fetch!(@count_keys, table)) do
      {:ok, Model.stat(payload: count)} -> count
      :not_found -> 0
    end
  end

  @spec count_contracts(State.t()) :: non_neg_integer()
  def count_contracts(state) do
    memory_only_keys =
      if State.has_memory_store?(state) do
        state
        |> State.without_fallback()
        |> stream_origin_pubkeys()
        |> Enum.count()
      else
        0
      end

    memory_only_keys + db_contracts_count()
  end

  defp update_count(state, table, delta) do
    count_key = Map.fetch!(@count_keys, table)

    State.update(
      state,
      Model.Stat,
      count_key,
      fn Model.stat(payload: count) = stat -> Model.stat(stat, payload: count + delta) end,
      Model.stat(index: count_key, payload: 0)
    )
  end

  defp synced_at(state) do
    next_txi =
      case State.prev(state, Model.Tx, nil) do
        {:ok, txi} -> txi + 1
        :none -> 0
      end

    {State.height(state), next_txi}
  end

  defp db_contracts_count() do
    db_state = State.new()

    case State.prev(db_state, Model.TotalStat, nil) do
      {:ok, last_gen} ->
        m_total_stat = State.fetch!(db_state, Model.TotalStat, last_gen)

        Model.total_stat(m_total_stat, :contracts)

      :none ->
        0
    end
  end

  defp stream_origin_pubkeys(state) do
    [:contract_create_tx, :contract_call_tx, :ga_attach_tx]
    |> Enum.map(fn tx_type ->
      key_boundary = {{tx_type, <<>>, 0}, {tx_type, max_256bit_bin(), max_int()}}
      Collection.stream(state, Model.Origin, :forward, key_boundary, nil)
    end)
    |> Collection.merge(:forward)
    |> Stream.map(fn {_type, pubkey, _txi} -> pubkey end)
  end
end
