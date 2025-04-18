defmodule AeMdw.Migrations.AddAccountCounts do
  @moduledoc false
  alias AeMdw.Collection
  alias AeMdw.Validate
  # alias AeMdw.Db.Sync.IdCounter
  # alias AeMdw.Collection
  # alias AeMdw.Fields
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.RocksDbCF

  require Model
  require Logger

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(_state, _from_start?) do
    # account_int_transfers =
    #   Model.TargetKindIntTransferTx
    #   |> RocksDbCF.stream()
    #   |> Enum.reduce(%{}, fn Model.target_kind_int_transfer_tx(
    #                            index: {account_id, _kind, _block_index, _opt_ref_txi}
    #                          ),
    #                          acc ->
    #     Map.update(acc, account_id, 1, &(&1 + 1))
    #   end)

    # Logger.info("Accounts with int transfers: #{map_size(account_int_transfers)}")

    account_int_contract_calls =
      Model.IdIntContractCall
      |> RocksDbCF.stream()
      |> Stream.filter(fn Model.id_int_contract_call(
                            index: {pk, _field_pos, _call_txi, _local_idx}
                          ) ->
        pk
        |> Validate.id([:account_pubkey])
        |> case do
          {:ok, _pk} ->
            true

          _otherwise ->
            false
        end
      end)
      |> Stream.map(fn Model.id_int_contract_call(
                         index: {account_pk, _field_pos, call_txi, local_idx}
                       ) ->
        {{call_txi, local_idx}, account_pk}
      end)
      |> Stream.dedup_by(fn {{txi, local_idx}, _account_pk} -> {txi, local_idx} end)
      |> Enum.reduce(%{}, fn {{_txi, _local_idx}, account_pk}, acc ->
        Map.update(acc, account_pk, 1, &(&1 + 1))
      end)

    Logger.info("Accounts with int contract calls: #{map_size(account_int_contract_calls)}")

    aexn_transfers_activity_stream =
      Model.AexnTransfer
      |> RocksDbCF.stream()
      |> Stream.flat_map(fn Model.aexn_transfer(
                              index: {_aexn_type, from_pk, call_txi, _log_idx, to_pk, _amount}
                            ) ->
        [{call_txi, from_pk}, {call_txi, to_pk}]
      end)

    rev_aexn_transfers_activity_stream =
      Model.RevAexnTransfer
      |> RocksDbCF.stream()
      |> Stream.flat_map(fn Model.rev_aexn_transfer(
                              index: {_aexn_type, to_pk, call_txi, from_pk, _amount, _log_idx}
                            ) ->
        [{call_txi, from_pk}, {call_txi, to_pk}]
      end)

    aexn_transfers_activity =
      [aexn_transfers_activity_stream, rev_aexn_transfers_activity_stream]
      |> Collection.merge(:forward)
      |> Stream.dedup_by(fn {txi, _account_pk} -> txi end)
      |> Enum.reduce(%{}, fn {_txi, account_pk}, acc ->
        Map.update(acc, account_pk, 1, &(&1 + 1))
      end)

    Logger.info("Accounts with AEX9 transfers: #{map_size(aexn_transfers_activity)}")

    # state =
    #   Fields.tx_types_pos()
    #   |> Stream.flat_map(fn {tx_type, tx_field_pos} ->
    #     scope =
    #       Collection.generate_key_boundary(
    #         {tx_type, tx_field_pos, Collection.binary(), Collection.integer()}
    #       )

    #     Model.Field
    #     |> RocksDbCF.stream(key_boundary: scope)
    #     |> Stream.filter(fn Model.field(index: {^tx_type, ^tx_field_pos, _account_pk, txi}) ->
    #       tx_type != :contract_create_tx or State.exists?(state, Model.Type, {tx_type, txi})
    #     end)
    #     |> Enum.map(fn Model.field(index: {^tx_type, ^tx_field_pos, account_pk, txi}) ->
    #       {txi, account_pk}
    #     end)
    #     |> tap(fn asd ->
    #       Logger.info("Accounts with tx counts for #{tx_type}: #{length(asd)}")
    #     end)
    #   end)
    #   # |> Stream.flat_map(fn {:ok, account_tx_counts} -> account_tx_counts end)
    #   |> Stream.dedup_by(fn {txi, _account_pk} -> txi end)
    #   |> Enum.reduce(state, fn {_txi, account_pk}, acc_state ->
    #     IdCounter.incr_account_tx_count(acc_state, account_pk)
    #   end)

    # Logger.info("Accounts with tx counts: #{State.count_keys(state, Model.AccountCounter)}")
    raise "TODO: implement"
  end
end
