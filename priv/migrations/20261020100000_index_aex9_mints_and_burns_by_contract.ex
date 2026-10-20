defmodule AeMdw.Migrations.IndexAex9MintsAndBurnsByContract do
  @moduledoc """
  Indexes AEX-9 mints and burns by contract, reading them back from
  AexnTransfer: a mint is sent by the contract, a burn goes to nobody (or to the
  contract, for WAE withdrawals backfilled by an earlier migration).

  Writes are idempotent and skip State.commit_db, which would clear the
  in-memory state, so it can run in the background while syncing.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()} | {:async, [fun()]}
  def run(state, true = _from_start?) do
    {:async, [fn -> do_run(state) end]}
  end

  def run(state, _from_start?) do
    {:ok, do_run(state)}
  end

  defp do_run(state) do
    0..255
    |> Task.async_stream(&index_sender_range(state, &1), timeout: :infinity, ordered: false)
    |> Enum.reduce(0, fn {:ok, count}, acc -> acc + count end)
  end

  defp index_sender_range(state, first_byte) do
    key_boundary =
      {{:aex9, <<first_byte>>, 0, 0, nil, 0},
       {:aex9, <<first_byte, -1::248>>, nil, nil, nil, nil}}

    Model.AexnTransfer
    |> RocksDbCF.stream(key_boundary: key_boundary)
    |> Stream.transform(%{}, fn
      Model.aexn_transfer(
        index: {:aex9, from_pk, txi, log_idx, to_pk, value},
        contract_pk: contract_pk
      ),
      create_txis
      when is_nil(to_pk) or from_pk == contract_pk or to_pk == contract_pk ->
        {create_txi, create_txis} = create_txi(state, contract_pk, create_txis)

        {contract_transfers(create_txi, from_pk, txi, log_idx, to_pk, value), create_txis}

      _transfer, create_txis ->
        {[], create_txis}
    end)
    |> Enum.reduce(0, fn {table, record}, count ->
      _state = State.put(state, table, record)

      count + 1
    end)
  end

  defp create_txi(state, contract_pk, create_txis) do
    case Map.fetch(create_txis, contract_pk) do
      {:ok, create_txi} ->
        {create_txi, create_txis}

      :error ->
        create_txi =
          case Origin.tx_index(state, {:contract, contract_pk}) do
            {:ok, create_txi} -> create_txi
            :not_found -> nil
          end

        {create_txi, Map.put(create_txis, contract_pk, create_txi)}
    end
  end

  defp contract_transfers(nil, _from_pk, _txi, _log_idx, _to_pk, _value), do: []

  defp contract_transfers(create_txi, from_pk, txi, log_idx, nil, value) do
    [
      {Model.AexnContractFromTransfer,
       Model.aexn_contract_from_transfer(index: {create_txi, from_pk, txi, log_idx, nil, value})}
    ]
  end

  defp contract_transfers(create_txi, from_pk, txi, log_idx, to_pk, value) do
    [
      {Model.AexnContractFromTransfer,
       Model.aexn_contract_from_transfer(index: {create_txi, from_pk, txi, log_idx, to_pk, value})},
      {Model.AexnContractToTransfer,
       Model.aexn_contract_to_transfer(index: {create_txi, to_pk, txi, log_idx, from_pk, value})}
    ]
  end
end
