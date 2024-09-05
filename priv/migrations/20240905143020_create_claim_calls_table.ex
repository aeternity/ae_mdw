defmodule AeMdw.Migrations.CreateClaimCallsTable do
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    key_boundary =
      Collection.generate_key_boundary(
        {:name_claim_tx, Collection.integer(), Collection.binary(), Collection.integer()}
      )

    chunk_size = 500

    IO.inspect(chunk_size, label: "Chunk size")

    count =
      state
      |> Collection.stream(
        Model.Field,
        :backward,
        key_boundary,
        nil
      )
      |> Stream.chunk_every(chunk_size)
      |> Task.async_stream(fn chunk ->
        chunk
        |> Task.async_stream(fn {_tx_type, _tx_field_pos, account_pk, tx_index} ->
          Model.tx(id: tx_hash, block_index: {height, _mbi}) =
            State.fetch!(state, Model.Tx, tx_index)

          {:name_claim_tx, aetx} = Db.get_tx(tx_hash)
          name = :aens_claim_tx.name(aetx)

          boundaries =
            Collection.generate_key_boundary({name, height, {tx_index, Collection.integer()}})

          [
            Collection.stream(
              state,
              Model.NameClaim,
              :backward,
              boundaries,
              nil
            ),
            Collection.stream(
              state,
              Model.AuctionBidClaim,
              :backward,
              boundaries,
              nil
            )
          ]
          |> Collection.merge(:backward)
          |> Enum.map(fn {plain_name, height, call_idx} ->
            WriteMutation.new(
              Model.ClaimCall,
              Model.claim_call(index: {account_pk, call_idx, plain_name, height})
            )
          end)
        end)
        |> Enum.map(fn {:ok, mutations} -> mutations end)
      end)
      |> Enum.reduce(0, fn {:ok, mutations}, count ->
        _state = State.commit_db(state, mutations)

        len = length(mutations)
        count = count + len
        IO.inspect(count, label: "Field count")
        count
      end)

    {:ok, count}
  end
end
