defmodule AeMdw.Sync.AsyncTasks.DeriveAex9Presence do
  @moduledoc """
  Async work to derive AEX9 presence from balance dry-running
  from a create contract.
  """
  @behaviour AeMdw.Sync.AsyncTasks.Work

  alias AeMdw.Node.Db, as: DBN

  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Log

  require Model
  require Logger

  @microsecs 1_000_000

  @typep pubkey() :: DBContract.pubkey()

  @spec process(args :: list()) :: :ok
  def process([contract_pk, kbi, mbi, create_txi]) do
    next_hash =
      {kbi, mbi}
      |> Util.next_bi!()
      |> Util.read_block!()
      |> Model.block(:hash)

    Log.info("[:derive_aex9_presence] #{inspect(contract_pk)} ...")

    {time_delta, {balances, _last_block_tuple}} =
      :timer.tc(fn -> DBN.aex9_balances!(contract_pk, {nil, kbi, next_hash}) end)

    Log.info("[:derive_aex9_presence] #{inspect(contract_pk)} after #{time_delta / @microsecs}s")

    all_pks =
      balances
      |> Map.keys()
      |> Enum.map(fn {:address, pk} -> pk end)
      |> Enum.into(MapSet.new())

    recipients = get_aex9_recipients(contract_pk, kbi, mbi)

    pks =
      Enum.reduce(recipients, all_pks, fn to_pk, pks ->
        MapSet.delete(pks, to_pk)
      end)

    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        Enum.each(pks, &DBContract.aex9_write_presence(contract_pk, create_txi, &1))
      end)

    :ets.delete(:derive_aex9_presence_cache, contract_pk)

    :ok
  end

  @spec cache_recipients(pubkey(), list()) :: :ok
  def cache_recipients(_contract_pk, []), do: :ok

  def cache_recipients(contract_pk, recipients) do
    Enum.each(recipients, fn <<to_pk::binary>> ->
      :ets.insert(:derive_aex9_presence_cache, {contract_pk, to_pk})
    end)
  end

  #
  # Private functions
  #
  defp get_aex9_recipients(contract_pk, kbi, mbi) do
    case :ets.lookup(:derive_aex9_presence_cache, contract_pk) do
      [] ->
        contract_pk
        |> read_aex9_transfers_from_mb(kbi, mbi)
        |> Enum.map(fn [_from_pk, to_pk, <<_amount::256>>] -> to_pk end)

      recipients ->
        recipients
    end
  end

  defp read_aex9_transfers_from_mb(contract_pk, kbi, mbi) do
    mblock =
      kbi
      |> DBN.get_micro_blocks()
      |> Enum.with_index()
      |> Enum.find_value(fn {mblock, index} -> if index == mbi, do: mblock end)

    if mblock do
      mblock
      |> :aec_blocks.txs()
      |> Enum.filter(fn signed_tx ->
        {mod, tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
        mod.type() == :contract_call_tx and :aect_call_tx.contract_pubkey(tx) == contract_pk
      end)
      |> Enum.map(fn signed_tx ->
        {_mod, tx} = :aetx.specialize_callback(:aetx_sign.tx(signed_tx))
        block_hash = {kbi, mbi} |> Util.read_block!() |> Model.block(:hash)

        {_fun_arg_res, call_rec} =
          Contract.call_tx_info(tx, contract_pk, block_hash, &Contract.to_map/1)

        get_aex9_transfers_from_call(call_rec)
      end)
    end
  end

  defp get_aex9_transfers_from_call(call_rec) do
    contract_pk = :aect_call.contract_pubkey(call_rec)

    call_rec
    |> :aect_call.log()
    |> Enum.map(fn {addr, [evt_hash | args], _data} ->
      aex9_contract_pk = DBContract.which_aex9_contract_pubkey(contract_pk, addr)

      if DBContract.is_aex9_transfer?(evt_hash, aex9_contract_pk) do
        [_from_pk, _to_pk, <<_amount::256>>] = args
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
