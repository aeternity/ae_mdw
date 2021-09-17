defmodule AeMdw.Db.Sync.Oracle do
  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Log

  require Record
  require Model
  require Ex2ms

  import AeMdw.Db.Oracle,
    only: [
      cache_through_read!: 2,
      cache_through_read: 2,
      cache_through_write: 2,
      cache_through_delete: 2,
      cache_through_delete_inactive: 1
    ]

  import AeMdw.Util
  import AeMdw.Db.Util

  ##########

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
  end

  def respond(pubkey, tx, txi, {height, _} = bi) do
    query_id = :aeo_response_tx.query_id(tx)
    o_tree = AeMdw.Db.Oracle.oracle_tree!(bi)

    fee =
      pubkey
      |> :aeo_state_tree.get_query(query_id, o_tree)
      |> :aeo_query.fee()

    AeMdw.Db.IntTransfer.write({height, txi}, "reward_oracle", pubkey, txi, fee)
  end

  ##########

  def expire(height) do
    oracle_mspec =
      Ex2ms.fun do
        {:expiration, {^height, pubkey}, :_} -> pubkey
      end

    :mnesia.select(Model.ActiveOracleExpiration, oracle_mspec)
    |> Enum.each(&expire_oracle(height, &1))
  end

  def expire_oracle(height, pubkey) do
    m_oracle = cache_through_read!(Model.ActiveOracle, pubkey)
    m_exp = Model.expiration(index: {height, pubkey})
    cache_through_write(Model.InactiveOracle, m_oracle)
    cache_through_write(Model.InactiveOracleExpiration, m_exp)
    cache_through_delete(Model.ActiveOracle, pubkey)
    cache_through_delete(Model.ActiveOracleExpiration, {height, pubkey})
    AeMdw.Ets.inc(:stat_sync_cache, :inactive_oracles)
    AeMdw.Ets.dec(:stat_sync_cache, :active_oracles)
    log_expired_oracle(height, pubkey)
  end

  ##########

  def log_expired_oracle(height, pubkey),
    do: Log.info("[#{height}] expiring oracle #{Enc.encode(:oracle_pubkey, pubkey)}")

  ################################################################################
  #
  #
  #

  def invalidate(new_height) do
    inactives = expirations(Model.InactiveOracleExpiration, new_height)
    actives = expirations(Model.ActiveOracleExpiration, new_height)

    pubkeys = MapSet.union(inactives, actives)

    {all_dels_nested, all_writes_nested} =
      Enum.reduce(pubkeys, {%{}, %{}}, fn pubkey, {all_dels, all_writes} ->
        inactive = ok_nil(cache_through_read(Model.InactiveOracle, pubkey))
        active = ok_nil(cache_through_read(Model.ActiveOracle, pubkey))

        {dels, writes} = invalidate(pubkey, inactive, active, new_height)

        {merge_maps([all_dels, dels], &cons_merger/3),
         merge_maps([all_writes, writes], &cons_merger/3)}
      end)

    {flatten_map_values(all_dels_nested), flatten_map_values(all_writes_nested)}
  end

  def expirations(table, new_height),
    do:
      collect_keys(table, MapSet.new(), {new_height, ""}, &next/2, fn {_, name}, acc ->
        {:cont, MapSet.put(acc, name)}
      end)

  def invalidate(_pubkey, inactive_m_oracle, nil, new_height)
      when not is_nil(inactive_m_oracle),
      do: diff(invalidate1(:inactive, inactive_m_oracle, new_height))

  def invalidate(_pubkey, nil, active_m_oracle, new_height)
      when not is_nil(active_m_oracle),
      do: diff(invalidate1(:active, active_m_oracle, new_height))

  ##########

  def invalidate1(lfcycle, obj, new_height),
    do: {dels(lfcycle, obj), writes(oracle_for_epoch(obj, new_height))}

  defp cons_merger(_k, v1, v2), do: v1 ++ v2

  def diff({dels, writes}) do
    {Enum.flat_map(
       dels,
       fn {tab, del_ks} ->
         ws = Map.get(writes, tab, nil)
         finder = fn k -> Enum.find(ws, &(elem(&1, 1) == k)) end
         rem_ks = ws && Enum.reject(del_ks, &finder.(&1))
         rem_nil = is_nil(rem_ks) || rem_ks == []
         (rem_nil && []) || [{tab, rem_ks}]
       end
     )
     |> Enum.into(%{}), writes}
  end

  def dels(lfcycle, m_oracle) do
    pubkey = Model.oracle(m_oracle, :index)
    expire = Model.oracle(m_oracle, :expire)
    map_tabs(lfcycle, fn -> [{expire, pubkey}] end, fn -> [pubkey] end)
  end

  def writes(nil), do: %{}

  def writes({inact, m_oracle, expire}) when inact in [:inactive, :active],
    do:
      map_tabs(
        inact,
        fn -> [m_exp(expire, Model.oracle(m_oracle, :index))] end,
        fn -> [m_oracle] end
      )

  def oracle_for_epoch(nil, _new_height),
    do: nil

  def oracle_for_epoch(m_oracle, new_height) when Record.is_record(m_oracle, :oracle) do
    index = Model.oracle(m_oracle, :index)
    active = Model.oracle(m_oracle, :active)
    {{_, _}, register_txi} = register = Model.oracle(m_oracle, :register)

    cond do
      new_height >= active ->
        expire = Model.oracle(m_oracle, :expire)
        lfcycle = (new_height < expire && :active) || :inactive
        extends = drop_bi_txi(Model.oracle(m_oracle, :extends), new_height)
        new_expire = new_expire(register_txi, extends)

        m_oracle =
          Model.oracle(
            index: index,
            active: active,
            expire: new_expire,
            register: register,
            extends: extends,
            previous: Model.oracle(m_oracle, :previous)
          )

        {lfcycle, m_oracle, new_expire}

      new_height < active ->
        oracle_for_epoch(Model.oracle(m_oracle, :previous), new_height)
    end
  end

  def map_tabs(:inactive, exp_f, name_f),
    do: %{Model.InactiveOracleExpiration => exp_f.(), Model.InactiveOracle => name_f.()}

  def map_tabs(:active, exp_f, name_f),
    do: %{Model.ActiveOracleExpiration => exp_f.(), Model.ActiveOracle => name_f.()}

  def m_exp(height, pubkey),
    do: Model.expiration(index: {height, pubkey})

  # def new_expire(register_txi, [] = _new_extends) do
  #   %{block_height: height,
  #     tx: %{oracle_ttl: {:delta, rel_ttl},
  #           type: :oracle_register_tx}} = read_raw_tx!(register_txi)
  #   height + rel_ttl
  # end

  def new_expire(register_txi, new_extends) do
    %{block_height: height, tx: %{oracle_ttl: {:delta, rel_ttl}, type: :oracle_register_tx}} =
      read_raw_tx!(register_txi)

    for {{_, _}, txi} <- new_extends, reduce: height + rel_ttl do
      acc ->
        %{tx: %{oracle_ttl: {:delta, rel_ttl}, type: :oracle_extend_tx}} = read_raw_tx!(txi)
        acc + rel_ttl
    end
  end

  def drop_bi_txi(bi_txis, new_height),
    do: Enum.drop_while(bi_txis, fn {{kbi, _mbi}, _txi} -> kbi >= new_height end)

  def read_raw_tx!(txi),
    do: Format.to_raw_map(read_tx!(txi))

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
