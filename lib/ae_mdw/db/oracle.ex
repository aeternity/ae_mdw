defmodule AeMdw.Db.Oracle do
  @moduledoc """
  Cache through operations for active and inactive oracles.
  """
  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.OracleResponseMutation
  alias AeMdw.Db.State
  alias AeMdw.Log
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Ex2ms
  require Model
  require Logger

  import AeMdw.Util

  @typep pubkey :: Db.pubkey()
  @typep cache_key :: pubkey() | {pos_integer(), pubkey()}
  @typep state :: State.t()

  @spec source(atom(), :expiration) ::
          Model.ActiveOracleExpiration | Model.InactiveOracleExpiration
  def source(Model.ActiveName, :expiration), do: Model.ActiveOracleExpiration
  def source(Model.InactiveName, :expiration), do: Model.InactiveOracleExpiration

  @spec locate(state(), pubkey()) ::
          {Model.oracle(), Model.ActiveOracle | Model.InactiveOracle} | nil
  def locate(state, pubkey) do
    map_ok_nil(cache_through_read(state, Model.ActiveOracle, pubkey), &{&1, Model.ActiveOracle}) ||
      map_ok_nil(
        cache_through_read(state, Model.InactiveOracle, pubkey),
        &{&1, Model.InactiveOracle}
      )
  end

  @spec cache_through_read(state(), atom(), cache_key()) :: {:ok, Model.oracle()} | nil
  def cache_through_read(state, table, key) do
    case State.cache_get(state, table, key) do
      {:ok, record} ->
        {:ok, record}

      :not_found ->
        case State.get(state, table, key) do
          {:ok, record} -> {:ok, record}
          :not_found -> nil
        end
    end
  end

  @spec cache_through_prev(atom(), cache_key()) :: term()
  def cache_through_prev(table, key),
    do: cache_through_prev(table, key, &(elem(key, 0) == elem(&1, 0)))

  @spec cache_through_prev(atom(), cache_key(), fun()) :: term()
  def cache_through_prev(table, key, key_checker) do
    lookup = fn k, unwrap, eot, chk_fail ->
      case k do
        :"$end_of_table" ->
          eot.()

        prev_key ->
          prev_key = unwrap.(prev_key)
          (key_checker.(prev_key) && {:ok, prev_key}) || chk_fail.()
      end
    end

    nf = fn -> :not_found end

    mns_lookup = fn ->
      case Database.prev_key(table, key) do
        {:ok, prev_key} -> lookup.(prev_key, & &1, nf, nf)
        :none -> :not_found
      end
    end

    lookup.(:ets.prev(:oracle_sync_cache, {table, key}), &elem(&1, 1), mns_lookup, mns_lookup)
  end

  @spec cache_through_write(state(), atom(), tuple()) :: state()
  def cache_through_write(state, table, record) do
    state
    |> State.cache_put(:oracle_sync_cache, {table, elem(record, 1)}, record)
    |> State.put(table, record)
  end

  @spec cache_through_delete(state(), atom(), cache_key()) :: state()
  def cache_through_delete(state, table, key) do
    state
    |> State.cache_delete(:oracle_sync_cache, {table, key})
    |> State.delete(table, key)
  end

  @spec cache_through_delete_inactive(state(), nil | Model.oracle()) :: state()
  def cache_through_delete_inactive(state, nil), do: state

  def cache_through_delete_inactive(state, m_oracle) do
    pubkey = Model.oracle(m_oracle, :index)
    expire = Model.oracle(m_oracle, :expire)

    state
    |> cache_through_delete(Model.InactiveOracle, pubkey)
    |> cache_through_delete(Model.InactiveOracleExpiration, {expire, pubkey})
  end

  @spec oracle_tree!(Blocks.block_hash()) :: tuple()
  def oracle_tree!(block_hash) do
    block_hash
    |> :aec_db.get_block_state()
    |> :aec_trees.oracles()
  end

  @spec expire_oracle(state(), Blocks.height(), pubkey()) :: state()
  def expire_oracle(state, height, pubkey) do
    oracle_id = Enc.encode(:oracle_pubkey, pubkey)
    state2 = cache_through_delete(state, Model.ActiveOracleExpiration, {height, pubkey})

    case cache_through_read(state2, Model.ActiveOracle, pubkey) do
      {:ok, m_oracle} ->
        if height == Model.oracle(m_oracle, :expire) do
          m_exp = Model.expiration(index: {height, pubkey})

          Log.info("[#{height}] inactivated oracle #{oracle_id}")

          state2
          |> cache_through_write(Model.InactiveOracle, m_oracle)
          |> cache_through_write(Model.InactiveOracleExpiration, m_exp)
          |> cache_through_delete(Model.ActiveOracle, pubkey)
          |> State.inc_stat(:oracles_expired)
        else
          Log.warn("[#{height}] ignored old oracle expiration for #{oracle_id}")
          state2
        end

      nil ->
        Log.warn("[#{height}] ignored oracle expiration for #{oracle_id}")
        state2
    end
  end

  @spec response_mutation(Node.tx(), Blocks.block_index(), Blocks.block_hash(), Txs.txi()) ::
          OracleResponseMutation.t()
  def response_mutation(tx, block_index, block_hash, txi) do
    oracle_pk = :aeo_response_tx.oracle_pubkey(tx)
    query_id = :aeo_response_tx.query_id(tx)
    o_tree = Oracle.oracle_tree!(block_hash)

    try do
      fee =
        oracle_pk
        |> :aeo_state_tree.get_query(query_id, o_tree)
        |> :aeo_query.fee()

      OracleResponseMutation.new(block_index, txi, oracle_pk, fee)
    rescue
      # TreeId = <<OracleId/binary, QId/binary>>,
      # Serialized = aeu_mtrees:get(TreeId, Tree#oracle_tree.otree)
      # raises error on unexisting tree_id
      error ->
        Log.error(error)
        []
    end
  end

  @doc """
  Returns stream of oracle pubkey() that expired at a certain height.
  """
  @spec list_expired_at(State.t(), Blocks.height()) :: Enumerable.t()
  def list_expired_at(state, height) do
    state
    |> Collection.stream(
      Model.InactiveOracleExpiration,
      :forward,
      {{height, <<>>}, {height + 1, <<>>}},
      nil
    )
    |> Stream.map(fn {_height, pubkey} -> pubkey end)
    |> Stream.uniq()
  end
end
