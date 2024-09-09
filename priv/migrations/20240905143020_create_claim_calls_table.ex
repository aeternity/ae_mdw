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

    {:ok, counter_agent} = Agent.start_link(fn -> 0 end)

    chunk_size = 500

    IO.inspect(chunk_size, label: "Chunk size")

    _state =
      state
      |> Collection.stream(
        Model.Field,
        :backward,
        key_boundary,
        nil
      )
      |> Stream.chunk_every(chunk_size)
      |> Task.async_stream(
        fn chunk ->
          chunk
          |> Task.async_stream(
            fn {_tx_type, _tx_field_pos, account_pk, tx_index} ->
              Model.tx(id: tx_hash, block_index: {height, _mbi} = _bi) =
                State.fetch!(state, Model.Tx, tx_index)

              name =
                tx_hash
                |> Db.get_tx()
                |> case do
                  {:name_claim_tx, aetx} ->
                    :aens_claim_tx.name(aetx)

                  {:contract_call_tx, aetx} ->
                    # {:id, :contract, contract_id} = :aect_call_tx.contract_id(aetx)

                    IO.inspect(aetx, label: "Tx")

                    Collection.stream(
                      state,
                      Model.IntContractCall,
                      :backward,
                      Collection.generate_key_boundary({tx_index, Collection.integer()}),
                      nil
                    )
                    |> Enum.take(10)
                    |> IO.inspect(label: "Int contract calls")

                    Model.int_contract_call(tx: name_aetx) =
                      State.fetch!(
                        state,
                        Model.IntContractCall,
                        {tx_index, 0}
                      )

                    name_aetx
                    |> :aetx.specialize_type()
                    |> elem(1)
                    |> :aens_claim_tx.name()

                  _ ->
                    raise "Invalid tx type for tx_hash: #{tx_hash}"
                end

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
            end,
            timeout: :infinity
          )
          |> Enum.flat_map(fn {:ok, mutations} -> mutations end)
        end,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, mutations} ->
        Agent.update(counter_agent, fn count ->
          total_count = count + length(mutations)
          tap(total_count, &IO.inspect(&1, label: "Count"))
        end)

        State.commit_db(state, mutations)
      end)

    count = Agent.get(counter_agent, & &1)

    {:ok, count}
  end
end
