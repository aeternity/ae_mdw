defmodule AeMdw.Migrations.RecalculateAex9Holders do
  @moduledoc """
  Recalculate AEX9 holders count.
  """
  alias AeMdw.Aex9
  alias AeMdw.Db.State
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Collection

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    invalid_number_of_holder_reason = Aex9.invalid_number_of_holders_reason()

    Model.Stat
    |> RocksDbCF.stream(
      key_boundary: Collection.generate_key_boundary({:aex9_holder_count, Collection.binary()})
    )
    |> Task.async_stream(
      fn Model.stat(index: {:aex9_holder_count, contract_pk}) ->
        {:ok, create_txi} = Origin.tx_index(State.mem_state(), {:contract, contract_pk})

        key_boundary =
          Collection.generate_key_boundary(
            {create_txi, Collection.integer(), Collection.integer()}
          )

        holders =
          Model.ContractLog
          |> AeMdw.Db.RocksDbCF.stream(key_boundary: key_boundary)
          |> Enum.reduce(%{}, fn Model.contract_log(
                                   index: {^create_txi, _txi, _idx},
                                   args: args,
                                   hash: event_hash
                                 ),
                                 balances_transfers ->
            event_name = AeMdw.AexnContracts.event_name(event_hash) || event_hash

            case {event_name, args} do
              {"Transfer", [from_pk, to_pk, <<transfered_value::256>>]} ->
                balances_transfers
                |> update_balance(from_pk, -transfered_value)
                |> update_balance(to_pk, transfered_value)

              # Mint
              {mint_event, [to_pk, <<mint_value::256>>]} when mint_event in ["Deposit", "Mint"] ->
                balances_transfers
                |> update_balance(to_pk, mint_value)

              # Burn
              {burn_event, [from_pk, <<burn_value::256>>]}
              when burn_event in ["Withdrawal", "Burn"] ->
                balances_transfers
                |> update_balance(from_pk, -burn_value)

              {_other_event, _args} ->
                balances_transfers
            end
          end)
          |> Enum.count(fn {_pk, balance} -> balance > 0 end)

        {contract_pk, holders}
      end,
      timeout: :infinity
    )
    |> Stream.flat_map(fn {:ok, {contract_pk, holders}} ->
      write_mutation =
        WriteMutation.new(
          Model.Stat,
          Model.stat(index: {:aex9_holder_count, contract_pk}, payload: holders)
        )

      case State.get(state, Model.AexnInvalidContract, {:aex9, contract_pk}) do
        {:ok, Model.aexn_invalid_contract(reason: ^invalid_number_of_holder_reason)} ->
          [
            write_mutation,
            DeleteKeysMutation.new(%{Model.AexnInvalidContract => [{:aex9, contract_pk}]})
          ]

        {:ok, _another_reason} ->
          [write_mutation]

        :not_found ->
          [write_mutation]
      end
    end)
    |> Stream.chunk_every(1000)
    |> Enum.reduce({state, 0}, fn mutations, {acc_state, count} ->
      {
        State.commit_db(acc_state, mutations),
        count + length(mutations)
      }
    end)
    |> then(fn {_state, mutations_length} ->
      {:ok, mutations_length}
    end)
  end

  defp update_balance(balances, account_pk, amount) do
    Map.update(balances, account_pk, amount, fn balance -> balance + amount end)
  end
end
