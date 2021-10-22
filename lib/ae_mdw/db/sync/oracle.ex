defmodule AeMdw.Db.Sync.Oracle do
  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Model
  alias AeMdw.Log

  require Model
  require Ex2ms
  require AeMdw.Log

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

  @spec extend(pubkey(), tx_tuple(), pos_integer(), block_index()) :: :ok
  def extend(pubkey, tx, txi, bi) do
    {:delta, delta_ttl} = :aeo_extend_tx.oracle_ttl(tx)
    m_oracle = cache_through_read!(Model.ActiveOracle, pubkey)
    old_expire = Model.oracle(m_oracle, :expire)
    new_expire = old_expire + delta_ttl
    extends = [{bi, txi} | Model.oracle(m_oracle, :extends)]
    m_exp = Model.expiration(index: {new_expire, pubkey})
    cache_through_delete(Model.ActiveOracleExpiration, {old_expire, pubkey})
    cache_through_write(Model.ActiveOracleExpiration, m_exp)
    m_oracle = Model.oracle(m_oracle, expire: new_expire, extends: extends)
    cache_through_write(Model.ActiveOracle, m_oracle)
    :ok
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
      error -> Log.warn(error)
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
    log_expired_oracle(height, pubkey)
    :ok
  end

  defp log_expired_oracle(height, pubkey),
    do: Log.info("[#{height}] expiring oracle #{Enc.encode(:oracle_pubkey, pubkey)}")

  ################################################################################
  # for development only

  # def quick_sync() do
  #   alias AeMdw.Node, as: AE
  #   alias AeMdw.Db.Stream, as: DBS
  #   import AeMdw.Db.Util

  #   nil = Process.whereis(AeMdw.Db.Sync.Supervisor)
  #   range = {1, last_gen() - 1}
  #   raw_txs =
  #     DBS.map(:forward, :raw, type: :oracle_register, type: :oracle_extend)
  #     |> Enum.to_list

  #   run_range(range, raw_txs,
  #     fn h -> :mnesia.transaction(fn -> expire(h) end) end,
  #     fn %{block_height: kbi, micro_index: mbi, hash: hash, tx_index: txi,
  #           tx: %{oracle_id: oracle_id}} ->
  #       {_block_hash, type, _signed_tx, tx_rec} = AE.Db.get_tx_data(hash)
  #       pk = AeMdw.Validate.id!(oracle_id)
  #       bi = {kbi, mbi}
  #       call = case type do
  #                :oracle_register_tx -> &register/4
  #                :oracle_extend_tx -> &extend/4
  #              end
  #       :mnesia.transaction(fn -> call.(pk, tx_rec, txi, bi) end)
  #     end)
  # end

  # def run_range({from, to}, _txs, _int_fn, _tx_fn) when from > to,
  #   do: :done

  # def run_range({from, to}, [%{block_height: from} = tx | rem_txs], int_fn, tx_fn) do
  #   int_fn.(from)
  #   tx_fn.(tx)
  #   run_range({from + 1, to}, rem_txs, int_fn, tx_fn)
  # end

  # def run_range({from, to}, [%{block_height: h} = tx | rem_txs], int_fn, tx_fn) when h < from do
  #   tx_fn.(tx)
  #   run_range({from, to}, rem_txs, int_fn, tx_fn)
  # end

  # def run_range({from, to}, txs, int_fn, tx_fn) do
  #   int_fn.(from)
  #   run_range({from + 1, to}, txs, int_fn, tx_fn)
  # end

  def reset_db() do
    [
      Model.ActiveOracle,
      Model.InactiveOracle,
      Model.ActiveOracleExpiration,
      Model.InactiveOracleExpiration
    ]
    |> Enum.each(&:mnesia.clear_table/1)
  end
end
