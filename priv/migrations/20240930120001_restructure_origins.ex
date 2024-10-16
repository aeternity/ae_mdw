defmodule AeMdw.Migrations.RestructureOrigins do
  @moduledoc """
  Reindex Origin and RevOrigin records, now including transaction index.
  """
  alias AeMdw.Collection
  alias AeMdw.Contract
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.Transaction
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Node.Db

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    state
    |> Collection.stream(Model.Origin, nil)
    |> Stream.filter(&match?({_tx_type, _pubkey, txi} when is_integer(txi), &1))
    |> Stream.map(fn {tx_type, pubkey, txi} = index ->
      rev_origin_index = {txi, tx_type, pubkey}
      idx = search_pubkey_idx(state, txi, pubkey)

      {
        [
          WriteMutation.new(
            Model.Origin,
            Model.origin(
              index: {tx_type, pubkey},
              txi_idx: {txi, idx}
            )
          ),
          WriteMutation.new(
            Model.RevOrigin,
            Model.rev_origin(index: {{txi, idx}, tx_type}, pubkey: pubkey)
          )
        ],
        {index, rev_origin_index}
      }
    end)
    |> Stream.chunk_every(1_000)
    |> Stream.map(fn chunk ->
      {mutations, deletion_keys} = Enum.unzip(chunk)
      {origin_deletion_keys, rev_deletion_keys} = Enum.unzip(deletion_keys)

      mutations = [
        DeleteKeysMutation.new(%{
          Model.Origin => origin_deletion_keys,
          Model.RevOrigin => rev_deletion_keys
        })
        | mutations
      ]

      _state = State.commit_db(state, mutations)
      length(mutations)
    end)
    |> Enum.sum()
    |> then(&{:ok, &1})
  end

  defp search_pubkey_idx(state, txi, pubkey) do
    Model.tx(id: tx_hash, block_index: block_index) = State.fetch!(state, Model.Tx, txi)

    case Db.get_tx_data(tx_hash) do
      {block_hash, :contract_create_tx, signed_tx, tx} ->
        contract_pubkey = :aect_create_tx.contract_pubkey(tx)

        if contract_pubkey == pubkey do
          -1
        else
          mb_events =
            block_hash
            |> :aec_db.get_block()
            |> Contract.get_grouped_events()

          %WriteMutation{record: Model.origin(index: {_tx_type, ^pubkey}, txi_idx: {^txi, idx})} =
            signed_tx
            |> Transaction.transaction_mutations(txi, block_index, block_hash, 0, mb_events)
            |> List.flatten()
            |> Enum.find(
              &match?(
                %WriteMutation{
                  table: Model.Origin,
                  record: Model.origin(index: {_tx_type, ^pubkey})
                },
                &1
              )
            )

          idx
        end

      {block_hash, :contract_call_tx, signed_tx, _tx} ->
        mb_events =
          block_hash
          |> :aec_db.get_block()
          |> Contract.get_grouped_events()

        %WriteMutation{record: Model.origin(index: {_tx_type, ^pubkey}, txi_idx: {^txi, idx})} =
          signed_tx
          |> Transaction.transaction_mutations(txi, block_index, block_hash, 0, mb_events)
          |> List.flatten()
          |> Enum.find(
            &match?(
              %WriteMutation{
                table: Model.Origin,
                record: Model.origin(index: {_tx_type, ^pubkey})
              },
              &1
            )
          )

        idx

      {_block_hash, _tx_type, _signed_tx, _tx} ->
        -1
    end
  end
end
