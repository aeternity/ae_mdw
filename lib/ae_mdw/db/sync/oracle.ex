defmodule AeMdw.Db.Sync.Oracle do
  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Model
  alias AeMdw.Log

  require Model
  require Ex2ms
  require Logger

  import AeMdw.Db.Oracle,
    only: [
      cache_through_read!: 2,
      cache_through_read: 2,
      cache_through_write: 2,
      cache_through_delete: 2,
      cache_through_delete_inactive: 1
    ]

  import AeMdw.Util

  @typep pubkey() :: <<_::256>>
  @typep tx_tuple() :: tuple()
  @typep block_index() :: {pos_integer(), non_neg_integer()}

  ##########

  @spec register(pubkey(), tx_tuple(), pos_integer(), block_index()) :: :ok
  def register(pubkey, tx, txi, {height, _} = bi) do
    delta_ttl = :aeo_utils.ttl_delta(height, :aeo_register_tx.oracle_ttl(tx))
    expire = height + delta_ttl
    previous = ok_nil(cache_through_read(Model.InactiveOracle, pubkey))

    m_oracle =
      Model.oracle(
        index: pubkey,
        active: height,
        expire: expire,
        register: {bi, txi}
      )

    m_exp = Model.expiration(index: {expire, pubkey})
    cache_through_write(Model.ActiveOracle, m_oracle)
    cache_through_write(Model.ActiveOracleExpiration, m_exp)
    cache_through_delete_inactive(previous)
    AeMdw.Ets.inc(:stat_sync_cache, :active_oracles)
    previous && AeMdw.Ets.dec(:stat_sync_cache, :inactive_oracles)
  end

  @spec extend(pubkey(), tx_tuple(), pos_integer(), block_index()) :: boolean()
  def extend(pubkey, tx, txi, bi) do
    case cache_through_read(Model.ActiveOracle, pubkey) do
      {:ok, m_oracle} ->
        {:delta, delta_ttl} = :aeo_extend_tx.oracle_ttl(tx)
        old_expire = Model.oracle(m_oracle, :expire)
        new_expire = old_expire + delta_ttl
        extends = [{bi, txi} | Model.oracle(m_oracle, :extends)]
        m_exp = Model.expiration(index: {new_expire, pubkey})
        cache_through_delete(Model.ActiveOracleExpiration, {old_expire, pubkey})
        cache_through_write(Model.ActiveOracleExpiration, m_exp)
        m_oracle = Model.oracle(m_oracle, expire: new_expire, extends: extends)
        cache_through_write(Model.ActiveOracle, m_oracle)
        true

      _not_found ->
        Log.warn(
          "[#{elem(bi, 0)}] invalid extend for oracle #{Enc.encode(:oracle_pubkey, pubkey)}"
        )

        false
    end
  end

  @spec respond(pubkey(), tx_tuple(), pos_integer(), block_index()) :: :ok
  def respond(pubkey, tx, txi, {height, _} = bi) do
    query_id = :aeo_response_tx.query_id(tx)
    o_tree = AeMdw.Db.Oracle.oracle_tree!(bi)

    try do
      fee =
        pubkey
        |> :aeo_state_tree.get_query(query_id, o_tree)
        |> :aeo_query.fee()

      AeMdw.Db.IntTransfer.write({height, txi}, "reward_oracle", pubkey, txi, fee)
    rescue
      # TreeId = <<OracleId/binary, QId/binary>>,
      # Serialized = aeu_mtrees:get(TreeId, Tree#oracle_tree.otree)
      # raises error on unexisting tree_id
      error -> Log.error(error)
    end

    :ok
  end

  @spec expire(pos_integer()) :: :ok
  def expire(height) do
    oracle_mspec =
      Ex2ms.fun do
        {:expiration, {^height, pubkey}, :_} -> pubkey
      end

    Model.ActiveOracleExpiration
    |> :mnesia.select(oracle_mspec)
    |> Enum.each(&expire_oracle(height, &1))
  end

  #
  # Private functions
  #
  defp expire_oracle(height, pubkey) do
    m_oracle = cache_through_read!(Model.ActiveOracle, pubkey)
    m_exp = Model.expiration(index: {height, pubkey})
    cache_through_write(Model.InactiveOracle, m_oracle)
    cache_through_write(Model.InactiveOracleExpiration, m_exp)
    cache_through_delete(Model.ActiveOracle, pubkey)
    cache_through_delete(Model.ActiveOracleExpiration, {height, pubkey})
    AeMdw.Ets.inc(:stat_sync_cache, :inactive_oracles)
    AeMdw.Ets.dec(:stat_sync_cache, :active_oracles)

    Log.info("[#{height}] expiring oracle #{Enc.encode(:oracle_pubkey, pubkey)}")
  end
end
