defmodule AeMdw.Migrations.IndexOracleQueryAndRefunds do
  @moduledoc """
  Indexes oracle queries and refunds when oracle queries expire.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.InnerTx
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Node.Db
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    case State.prev(state, Model.Block, nil) do
      {:ok, {height, _mbi}} -> run_with_gens(state, height)
      :none -> {:ok, 0}
    end
  end

  defp run_with_gens(state, current_height) do
    oracle_query_txs = type_txs_stream(state, :oracle_query_tx)
    oracle_response_txs = type_txs_stream(state, :oracle_response_tx)
    internal_oracle_query_txs = internal_type_txs_stream(state, "Oracle.query")
    internal_oracle_response_txs = internal_type_txs_stream(state, "Oracle.respond")

    mutations =
      [
        oracle_query_txs,
        oracle_response_txs,
        internal_oracle_query_txs,
        internal_oracle_response_txs
      ]
      |> Collection.merge(:forward)
      |> Enum.reduce(%{}, fn
        {height, txi, _local_idx, :oracle_query_tx, tx}, queries ->
          oracle_pk = Validate.id!(:aeo_query_tx.oracle_id(tx))

          expiration_height =
            case :aeo_query_tx.query_ttl(tx) do
              {:delta, ttl} -> height + ttl
              {:block, height} -> height
            end

          sender_pk = :aeo_query_tx.sender_pubkey(tx)
          fee = :aeo_query_tx.query_fee(tx)
          query_id = :aeo_query_tx.query_id(tx)

          if Map.has_key?(queries, {oracle_pk, query_id}) do
            encoded_oracle_pk = :aeser_api_encoder.encode(:oracle_pubkey, oracle_pk)
            encoded_query_id = :aeser_api_encoder.encode(:oracle_query_id, query_id)

            IO.puts(
              "Adding a duplicated query #{encoded_query_id} from oracle #{encoded_oracle_pk} at txi #{txi}"
            )

            queries
          else
            Map.put(queries, {oracle_pk, query_id}, {txi, sender_pk, expiration_height, fee})
          end

        {_height, txi, _local_idx, :oracle_response_tx, tx}, queries ->
          oracle_pk = :aeo_response_tx.oracle_pubkey(tx)
          query_id = :aeo_response_tx.query_id(tx)

          if Map.has_key?(queries, {oracle_pk, query_id}) do
            Map.delete(queries, {oracle_pk, query_id})
          else
            encoded_oracle_pk = :aeser_api_encoder.encode(:oracle_pubkey, oracle_pk)
            encoded_query_id = :aeser_api_encoder.encode(:oracle_query_id, query_id)

            IO.puts(
              "Trying to delete a non-existing query #{encoded_query_id} from oracle #{encoded_oracle_pk} at txi #{txi}"
            )

            queries
          end
      end)
      |> Enum.flat_map(fn
        {{_oracle_pk, _query_id}, {txi, sender_pk, expiration_height, fee}}
        when expiration_height < current_height ->
          transfer_mutations({expiration_height, -1}, "fee_refund_oracle", sender_pk, txi, fee)

        {{oracle_pk, query_id}, {txi, sender_pk, expiration_height, fee}} ->
          query =
            Model.oracle_query(
              index: {oracle_pk, query_id},
              txi: txi,
              sender_pk: sender_pk,
              fee: fee,
              expire: expiration_height
            )

          query_expiration =
            Model.oracle_query_expiration(index: {expiration_height, oracle_pk, query_id})

          [
            WriteMutation.new(Model.OracleQuery, query),
            WriteMutation.new(Model.OracleQueryExpiration, query_expiration)
          ]
      end)

    IO.puts("Executing #{length(mutations)} mutations on database")

    _state = State.commit(state, mutations)

    IO.puts("Done.")

    {:ok, length(mutations)}
  end

  defp type_txs_stream(state, tx_type) do
    state
    |> Collection.stream(Model.Type, {tx_type, Util.min_int()})
    |> Stream.take_while(&match?({^tx_type, _txi}, &1))
    |> Stream.map(fn {^tx_type, txi} ->
      Model.tx(block_index: {height, _mbi}, id: tx_hash) = State.fetch!(state, Model.Tx, txi)
      aetx = :aetx_sign.tx(Db.get_signed_tx(tx_hash))

      tx =
        case :aetx.specialize_type(aetx) do
          {:ga_meta_tx, tx} ->
            aetx = InnerTx.signed_tx(:ga_meta_tx, tx)
            {_type, tx} = :aetx.specialize_type(aetx)
            tx

          {_type, tx} ->
            tx
        end

      {
        height,
        txi,
        -1,
        tx_type,
        tx
      }
    end)
  end

  defp internal_type_txs_stream(state, fname) do
    state
    |> Collection.stream(Model.FnameIntContractCall, {fname, Util.min_int(), Util.min_int()})
    |> Stream.take_while(&match?({^fname, _call_txi, _local_idx}, &1))
    |> Stream.map(fn {^fname, call_txi, local_idx} ->
      Model.int_contract_call(tx: aetx) =
        State.fetch!(state, Model.IntContractCall, {call_txi, local_idx})

      Model.tx(block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, call_txi)
      {tx_type, tx} = :aetx.specialize_type(aetx)

      {
        height,
        call_txi,
        local_idx,
        tx_type,
        tx
      }
    end)
  end

  defp transfer_mutations({height, pos_txi}, kind, target_pk, ref_txi, amount) do
    int_tx =
      Model.int_transfer_tx(index: {{height, pos_txi}, kind, target_pk, ref_txi}, amount: amount)

    kind_tx = Model.kind_int_transfer_tx(index: {kind, {height, pos_txi}, target_pk, ref_txi})

    target_kind_tx =
      Model.target_kind_int_transfer_tx(index: {target_pk, kind, {height, pos_txi}, ref_txi})

    [
      WriteMutation.new(Model.IntTransferTx, int_tx),
      WriteMutation.new(Model.KindIntTransferTx, kind_tx),
      WriteMutation.new(Model.TargetKindIntTransferTx, target_kind_tx)
    ]
  end
end
