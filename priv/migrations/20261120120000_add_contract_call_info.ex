defmodule AeMdw.Migrations.AddContractCallInfo do
  @moduledoc """
  Stores the gas used, return type and log count of each synced contract call, so that
  rendering a call no longer reads its call object from the node.

  Runs in the background while syncing, with idempotent writes that skip State.commit_db.
  Calls that already have a row are skipped, so a rerun after a restart resumes. Until a
  call has its row, it renders from the node as before.
  """

  alias AeMdw.Contract
  alias AeMdw.Db.Contract, as: DbContract
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.InnerTx
  alias AeMdw.Log
  alias AeMdw.Node.Db

  require Model

  @log_every 1_000_000

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()} | {:async, [fun()]}
  def run(state, true = _from_start?), do: {:async, [fn -> do_run(state) end]}

  def run(state, _from_start?), do: {:ok, do_run(state)}

  defp do_run(state) do
    # node reads, half the schedulers to leave room for syncing and the API
    concurrency = max(div(System.schedulers_online(), 2), 1)

    Model.ContractCall
    |> RocksDbCF.stream_keys(:forward, nil)
    |> Stream.map(fn {_create_txi, call_txi} -> call_txi end)
    |> Stream.reject(&State.exists?(state, Model.ContractCallInfo, &1))
    |> Task.async_stream(&write_call_info(state, &1),
      max_concurrency: concurrency,
      ordered: false,
      timeout: :infinity
    )
    |> Stream.with_index(1)
    |> Enum.reduce(0, fn {{:ok, written}, processed}, count ->
      if rem(processed, @log_every) == 0,
        do: Log.info("[add_contract_call_info] #{processed} calls, #{count + written} written")

      count + written
    end)
  end

  defp write_call_info(state, call_txi) do
    with {:ok, Model.tx(id: tx_hash, block_index: block_index)} <-
           State.get(state, Model.Tx, call_txi),
         {:ok, Model.block(hash: block_hash)} <- State.get(state, Model.Block, block_index),
         {:value, signed_tx} <- :aec_db.find_signed_tx(tx_hash),
         {:ok, call_signed_tx, call_tx} <- contract_call_tx(signed_tx),
         contract_or_name_pk = call_tx |> :aect_call_tx.contract_id() |> Db.id_pubkey(),
         {:ok, call_rec} <- Contract.call_rec(call_signed_tx, contract_or_name_pk, block_hash) do
      _state = DbContract.call_info_write(state, call_txi, call_rec)
      1
    else
      # rendered from the node as before, e.g. below a node GC height
      _no_call -> 0
    end
  end

  defp contract_call_tx(signed_tx) do
    case signed_tx |> :aetx_sign.tx() |> :aetx.specialize_type() do
      {:contract_call_tx, call_tx} ->
        {:ok, signed_tx, call_tx}

      {wrapper_type, wrapper_tx} when wrapper_type in [:ga_meta_tx, :paying_for_tx] ->
        wrapper_type |> InnerTx.signed_tx(wrapper_tx) |> contract_call_tx()

      _other_type ->
        :error
    end
  end
end
