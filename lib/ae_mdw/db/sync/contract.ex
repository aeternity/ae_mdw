defmodule AeMdw.Db.Sync.Contract do
  alias AeMdw.Contract
  alias AeMdw.Db
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util, as: DBU

  require Model

  @migrate_contract_pk <<84, 180, 196, 235, 185, 254, 235, 68, 37, 168, 101, 128, 127, 111, 97,
                         136, 141, 11, 134, 251, 228, 200, 73, 71, 175, 98, 22, 115, 172, 159,
                         234, 177>>

  ##########

  def create(contract_pk, owner_pk, txi, _bi) do
    case Contract.get_info(contract_pk) do
      {:ok, contract_info} ->

        with true <- Contract.is_aex9?(contract_info) do
          contract_pk
          |> Contract.aex9_meta_info
          |> DBContract.aex9_creation_write(contract_pk, owner_pk, txi)
        end

      _ ->
        :invalid_contract
    end
  end

  def call(contract_pk, tx, txi, bi) do
    block_hash = Model.block(DBU.read_block!(bi), :hash)

    create_txi = get_txi(contract_pk)

    {fun_arg_res, call_rec} =
      Contract.call_tx_info(tx, contract_pk, block_hash, &Contract.to_map/1)

    DBContract.call_write(create_txi, txi, fun_arg_res)
    DBContract.logs_write(create_txi, txi, call_rec)
  end

  # def events(events, hash_txis) do
  #   for {{:internal_call_tx, fname}, %{info: tx, tx_hash: tx_hash}} <- events do
  #   end
  # end


  def aex9_derive_account_presence!({kbi, mbi}) do
    next_hash =
      DBU.next_bi!({kbi, mbi})
      |> DBU.read_block!
      |> Model.block(:hash)

    ct_create? = fn
      {{_ct_pk, _txi, -1}, <<_::binary>>, -1} -> true;
      {{_ct_pk, _txi, _}, {<<_::binary>>, <<_::binary>>}, _} -> false
    end

    :ets.tab2list(:aex9_sync_cache)
    |> Enum.group_by(fn {{ct_pk, _, _}, _, _} -> ct_pk end)
    |> Enum.filter(fn {_ct_pk, [first_entry | _]} -> ct_create?.(first_entry) end)
    |> Enum.map(fn {ct_pk, [{{ct_pk, create_txi, -1}, <<_::binary>>, -1} | transfers]} ->
         {balances, _} = AeMdw.Node.Db.aex9_balances(ct_pk, {nil, kbi, next_hash})
         all_pks =
           Map.keys(balances)
           |> Enum.map(fn {:address, pk} -> pk end)
           |> Enum.into(MapSet.new())

         pks = for {_, {_, to_pk}, _} <- transfers, reduce: all_pks,
           do: (pks -> MapSet.delete(pks, to_pk))

         Enum.each(pks, &DBContract.aex9_write_presence(ct_pk, create_txi, &1))
       end)

    :ets.delete_all_objects(:aex9_sync_cache)
  end


  def events(raw_events, txi, ct_create_txi) do

  end


  def get_txi(@migrate_contract_pk), do: -1
  def get_txi(contract_pk) do
    case :ets.lookup(:ct_create_sync_cache, contract_pk) do
      [{_, txi}] -> txi
      [] -> Db.Origin.tx_index({:contract, contract_pk})
    end
  end

  def migrate_contract_pk(),
    do: @migrate_contract_pk
end
