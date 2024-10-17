defmodule AeMdw.Migrations.ReindexAexnFromAndToTransfers do
  @moduledoc false

  alias AeMdw.Collection
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State
  alias AeMdw.Db.Model
  alias AeMdw.Db.DeleteKeysMutation

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    changes =
      [Model.AexnContractFromTransfer, Model.AexnContractToTransfer]
      |> Task.async_stream(
        fn table ->
          state
          |> Collection.stream(table, nil)
          |> Stream.filter(fn {_aexn_type, _pk1, _call_txi, pk2, _value, _log_idx} ->
            is_binary(pk2) or is_nil(pk2)
          end)
          |> Stream.map(fn {aexn_type, pk1, call_txi, pk2, value, log_idx} = old_key ->
            write_mutation =
              case table do
                Model.AexnContractFromTransfer ->
                  WriteMutation.new(
                    Model.AexnContractFromTransfer,
                    Model.aexn_contract_from_transfer(
                      index: {aexn_type, pk1, call_txi, log_idx, pk2, value}
                    )
                  )

                Model.AexnContractToTransfer ->
                  WriteMutation.new(
                    Model.AexnContractToTransfer,
                    Model.aexn_contract_to_transfer(
                      index: {aexn_type, pk1, call_txi, log_idx, pk2, value}
                    )
                  )
              end

            {write_mutation, old_key}
          end)
          |> then(&replace_keys(state, table, &1))
        end,
        timeout: :infinity
      )
      |> Enum.reduce(0, fn {:ok, count}, acc -> count + acc end)

    {:ok, changes}
  end

  defp replace_keys(state, table, zipped_mutations) do
    zipped_mutations
    |> Stream.chunk_every(1_000)
    |> Stream.map(fn chunk ->
      {mutations, deletion_keys} = Enum.unzip(chunk)

      mutations = [
        DeleteKeysMutation.new(%{table => deletion_keys}) | mutations
      ]

      _state = State.commit_db(state, mutations)
      length(mutations)
    end)
    |> Enum.sum()
  end
end
