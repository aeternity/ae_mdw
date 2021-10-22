defmodule AeMdw.Db.Sync.OracleInvalidation do
  # credo:disable-for-this-file

  alias AeMdw.Db.Format
  alias AeMdw.Db.Model

  require Model
  require Record

  import AeMdw.Db.Oracle,
    only: [
      cache_through_read: 2
    ]

  import AeMdw.Util
  import AeMdw.Db.Util

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
end
