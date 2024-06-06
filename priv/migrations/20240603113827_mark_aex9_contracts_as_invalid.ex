defmodule AeMdw.Migrations.MarkAex9ContractsAsInvalid do
  @moduledoc """
  Mark AEX9 contracts as invalid.
  """

  alias AeMdw.Aex9
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Util

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    count_invalid_balance =
      state
      |> Collection.stream(Model.Aex9BalanceAccount, :forward)
      |> Stream.reject(fn {_contract_pk, amount, _pubkey} ->
        amount >= 0
      end)
      |> Stream.map(fn {contract_pk, _amount, _pubkey} ->
        WriteMutation.new(
          Model.AexnInvalidContract,
          Model.aexn_invalid_contract(
            index: {:aex9, contract_pk},
            reason: Aex9.invalid_holder_balance()
          )
        )
      end)
      |> Stream.chunk_every(1000)
      |> Stream.map(fn mutations ->
        _state = State.commit_db(state, mutations)

        length(mutations)
      end)
      |> Enum.sum()

    stats_boundary =
      {{:aex9_holder_count, <<>>}, {:aex9_holder_count, Util.max_256bit_bin()}}

    count_invalid_holders =
      state
      |> Collection.stream(Model.Stat, :forward, stats_boundary, nil)
      |> Stream.map(fn key ->
        State.fetch!(state, Model.Stat, key)
      end)
      |> Stream.reject(fn Model.stat(payload: count) ->
        count >= 0
      end)
      |> Stream.map(fn Model.stat(index: {:aex9_holder_count, contract_pk}) ->
        WriteMutation.new(
          Model.AexnInvalidContract,
          Model.aexn_invalid_contract(
            index: {:aex9, contract_pk},
            reason: Aex9.invalid_number_of_holders()
          )
        )
      end)
      |> Stream.chunk_every(1000)
      |> Stream.map(fn mutations ->
        _state = State.commit_db(state, mutations)

        length(mutations)
      end)
      |> Enum.sum()

    {:ok, count_invalid_balance + count_invalid_holders}
  end
end
