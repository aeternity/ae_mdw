defmodule AeMdw.Migrations.AddAccountCounts do
  @moduledoc false
  alias AeMdw.Collection
  alias AeMdw.Validate
  alias AeMdw.Db.Sync.IdCounter
  alias AeMdw.Collection
  alias AeMdw.Fields
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.RocksDbCF

  require Model
  require Logger

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    {account_int_transfers_count, state1} =
      Model.TargetKindIntTransferTx
      |> RocksDbCF.stream()
      |> Enum.reduce({0, state}, fn Model.target_kind_int_transfer_tx(
                                      index: {account_id, _kind, _block_index, _opt_ref_txi}
                                    ),
                                    {c, acc} ->
        {c + 1, IdCounter.incr_account_activities_count(acc, account_id)}
      end)

    Logger.info("Accounts with int transfers: #{account_int_transfers_count}")

    {account_int_contract_calls_count, state2} =
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
      |> Enum.reduce({0, state1}, fn {{_txi, _local_idx}, account_pk}, {c, acc} ->
        {c + 1, IdCounter.incr_account_activities_count(acc, account_pk)}
      end)

    Logger.info("Accounts with int contract calls: #{account_int_contract_calls_count}")

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

    {aexn_transfers_activity_count, state3} =
      [aexn_transfers_activity_stream, rev_aexn_transfers_activity_stream]
      |> Collection.merge(:forward)
      |> Stream.dedup_by(fn {txi, _account_pk} -> txi end)
      |> Enum.reduce({0, state2}, fn {_txi, account_pk}, {c, acc} ->
        {c + 1, IdCounter.incr_account_activities_count(acc, account_pk)}
      end)

    Logger.info("Accounts with AEX9 transfers: #{aexn_transfers_activity_count}")

    {int_transfer_activity_count, state4} =
      Model.TargetKindIntTransferTx
      |> RocksDbCF.stream()
      |> Stream.reject(
        &match?(
          Model.target_kind_int_transfer_tx(index: {_account_pk, _kind, {_height, -1}, _ref_txi}),
          &1
        )
      )
      |> Stream.dedup_by(fn Model.target_kind_int_transfer_tx(
                              index:
                                {_account_pk, _kind, {_height, {_txi, _idx} = txi_idx},
                                 _opt_ref_txi_idx}
                            ) ->
        txi_idx
      end)
      |> Enum.reduce({0, state3}, fn Model.target_kind_int_transfer_tx(
                                       index:
                                         {account_pk, _kind, {_height, _txi_idx},
                                          _opt_ref_txi_idx}
                                     ),
                                     {c, acc} ->
        {c + 1, IdCounter.incr_account_activities_count(acc, account_pk)}
      end)

    Logger.info("Accounts with int transfers: #{int_transfer_activity_count}")

    name_claims_stream =
      Model.NameClaim
      |> RocksDbCF.stream()
      |> Stream.map(fn Model.name_claim(index: {name, _activation_height, txi_idx}) ->
        {txi_idx, name}
      end)

    auction_bid_claims_stream =
      Model.AuctionBidClaim
      |> RocksDbCF.stream()
      |> Stream.map(fn Model.auction_bid(index: {name, _expiration_height, txi_idx}) ->
        {txi_idx, name}
      end)

    {claims_activity_count, state5} =
      [name_claims_stream, auction_bid_claims_stream]
      |> Collection.merge(:forward)
      |> Stream.dedup_by(fn {txi_idx, _name} -> txi_idx end)
      |> Enum.reduce({0, state4}, fn {_txi_idx, name}, {c, acc} ->
        {c + 1, IdCounter.incr_account_activities_count(acc, name)}
      end)

    Logger.info("Accounts with name claims: #{claims_activity_count}")

    {swaps_activity_count, state6} =
      Model.DexAccountSwapTokens
      |> RocksDbCF.stream()
      |> Stream.dedup_by(fn Model.dex_account_swap_tokens(
                              index: {_account_pk, _create_txi, txi, _log_idx}
                            ) ->
        txi
      end)
      |> Enum.reduce({0, state5}, fn Model.dex_account_swap_tokens(
                                       index: {account_pk, _create_txi, _txi, _log_idx}
                                     ),
                                     {c, acc} ->
        {c + 1, IdCounter.incr_account_activities_count(acc, account_pk)}
      end)

    Logger.info("Accounts with swaps: #{swaps_activity_count}")

    {tx_activity_count, _state7} =
      Fields.tx_types_pos()
      |> Stream.flat_map(fn {tx_type, tx_field_pos} ->
        scope =
          Collection.generate_key_boundary(
            {tx_type, tx_field_pos, Collection.binary(), Collection.integer()}
          )

        Model.Field
        |> RocksDbCF.stream(key_boundary: scope)
        |> Stream.filter(fn Model.field(index: {^tx_type, ^tx_field_pos, _account_pk, txi}) ->
          tx_type != :contract_create_tx or State.exists?(state, Model.Type, {tx_type, txi})
        end)
        |> Enum.map(fn Model.field(index: {^tx_type, ^tx_field_pos, account_pk, txi}) ->
          {txi, account_pk}
        end)
        |> tap(fn asd ->
          Logger.info("Accounts with tx counts for #{tx_type}: #{length(asd)}")
        end)
      end)
      |> Stream.dedup_by(fn {txi, _account_pk} -> txi end)
      |> Enum.reduce(state6, fn {_txi, account_pk}, acc ->
        acc
        |> IdCounter.incr_account_tx_count(account_pk)
        |> IdCounter.incr_account_activities_count(account_pk)
      end)

    Logger.info("Accounts with tx counts: #{tx_activity_count}")

    {:ok,
     account_int_transfers_count +
       account_int_contract_calls_count +
       aexn_transfers_activity_count +
       int_transfer_activity_count +
       claims_activity_count +
       swaps_activity_count +
       tx_activity_count}
  end
end
