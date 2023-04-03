defmodule AeMdw.Db.Sync.Oracle do
  @moduledoc """
  Synchronize mdw database with oracle chain state.
  """

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.OracleExtendMutation
  alias AeMdw.Db.OracleQueryMutation
  alias AeMdw.Db.OracleRegisterMutation
  alias AeMdw.Db.OracleResponseMutation
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Origin
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Validate

  require Model

  @typep height() :: Blocks.height()
  @typep txi_idx() :: Txs.txi_idx()
  @typep pubkey :: Db.pubkey()
  @typep cache_key :: pubkey() | {pos_integer(), pubkey()}
  @typep state :: State.t()

  @spec register_mutations(Node.tx(), Txs.tx_hash(), Blocks.block_index(), Txs.txi_idx()) :: [
          Mutation.t()
        ]
  def register_mutations(tx, tx_hash, {height, _mbi} = block_index, {txi, _idx} = txi_idx) do
    oracle_pk = :aeo_register_tx.account_pubkey(tx)
    delta_ttl = :aeo_utils.ttl_delta(height, :aeo_register_tx.oracle_ttl(tx))
    expire = height + delta_ttl

    [
      Origin.origin_mutations(:oracle_register_tx, nil, oracle_pk, txi, tx_hash),
      OracleRegisterMutation.new(oracle_pk, block_index, expire, txi_idx)
    ]
  end

  @spec query_mutation(Node.tx(), height(), txi_idx()) :: OracleQueryMutation.t()
  def query_mutation(tx, height, txi_idx) do
    oracle_pk = Validate.id!(:aeo_query_tx.oracle_id(tx))
    query_id = :aeo_query_tx.query_id(tx)

    expiration_height =
      case :aeo_query_tx.query_ttl(tx) do
        {:delta, ttl} -> height + ttl
        {:block, height} -> height
      end

    OracleQueryMutation.new(oracle_pk, query_id, txi_idx, expiration_height)
  end

  @spec response_mutation(Node.tx(), Blocks.block_index(), Txs.txi_idx()) ::
          OracleResponseMutation.t()
  def response_mutation(tx, block_index, txi_idx) do
    oracle_pk = :aeo_response_tx.oracle_pubkey(tx)
    query_id = :aeo_response_tx.query_id(tx)

    OracleResponseMutation.new(block_index, txi_idx, oracle_pk, query_id)
  end

  @spec extend_mutation(Node.tx(), Blocks.block_index(), Txs.txi_idx()) ::
          OracleExtendMutation.t()
  def extend_mutation(tx, block_index, txi_idx) do
    oracle_pk = :aeo_extend_tx.oracle_pubkey(tx)
    {:delta, delta_ttl} = :aeo_extend_tx.oracle_ttl(tx)

    OracleExtendMutation.new(block_index, txi_idx, oracle_pk, delta_ttl)
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

  @spec cache_through_delete_inactive(state(), Model.oracle()) :: state()
  def cache_through_delete_inactive(state, m_oracle) do
    pubkey = Model.oracle(m_oracle, :index)
    expire = Model.oracle(m_oracle, :expire)

    state
    |> cache_through_delete(Model.InactiveOracle, pubkey)
    |> cache_through_delete(Model.InactiveOracleExpiration, {expire, pubkey})
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
