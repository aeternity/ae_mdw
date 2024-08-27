defmodule AeMdw.Migrations.Aex9TokensContractMintEventsFix do
  @moduledoc """
  Fixes the Deposit(address, value) that should have been names Mint(address, value)
  for one of the AE tokens contract (WAE DEX contract).
  """

  alias AeMdw.AexnContracts
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Origin
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Stats
  alias AeMdw.Util

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    contract_pk =
      :ae_mdw
      |> Application.fetch_env!(:ae_token)
      |> Map.get(:aec_governance.get_network_id())

    case Origin.tx_index(state, {:contract, contract_pk}) do
      {:ok, create_txi} ->
        run_with_contract(state, contract_pk, create_txi)

      :not_found ->
        {:ok, 0}
    end
  end

  defp run_with_contract(state, contract_pk, create_txi) do
    key_boundary = {
      {create_txi, 0, nil},
      {create_txi, nil, nil}
    }

    balances =
      state
      |> Collection.stream(Model.ContractLog, :forward, key_boundary, nil)
      |> Stream.map(&State.fetch!(state, Model.ContractLog, &1))
      |> Enum.reduce(%{}, fn Model.contract_log(
                               index: {^create_txi, txi, idx} = index,
                               args: args,
                               hash: event_hash
                             ),
                             balances ->
        event_name = AexnContracts.event_name(event_hash) || event_hash

        case {event_name, args} do
          {"Transfer", [from_pk, to_pk, <<transfered_value::256>>]} ->
            balances
            |> update_balance(from_pk, txi, idx, -transfered_value)
            |> update_balance(to_pk, txi, idx, transfered_value)

          # Mint
          {"Deposit", [to_pk, <<mint_value::256>>]} ->
            balances
            |> update_balance(to_pk, txi, idx, mint_value)

          # Burn
          {"Withdrawal", [from_pk, <<burn_value::256>>]} ->
            balances
            |> update_balance(from_pk, txi, idx, -burn_value)

          {"Allowance", [_from_pk, _to_pk, <<_allowance_value::256>>]} ->
            balances

          {event, args} ->
            IO.puts("UNKNOWN EVENT: #{inspect(event)}, args: #{inspect(args)}, #{inspect(index)}")
            balances
        end
      end)

    balances_mutations =
      Stream.flat_map(balances, fn {account_pk, {balance, txi, idx}} ->
        [
          WriteMutation.new(
            Model.Aex9BalanceAccount,
            Model.aex9_balance_account(
              index: {contract_pk, balance, account_pk},
              txi: txi,
              log_idx: idx
            )
          ),
          WriteMutation.new(
            Model.Aex9EventBalance,
            Model.aex9_event_balance(
              index: {contract_pk, account_pk},
              txi: txi,
              log_idx: idx,
              amount: balance
            )
          )
        ]
      end)

    total_holders =
      Enum.count(balances, fn {_account_pk, {balance, _txi, _idx}} -> balance > 0 end)

    total_balances_amount =
      balances
      |> Stream.map(fn {_account_pk, {balance, _txi, _idx}} ->
        balance
      end)
      |> Enum.sum()

    key_boundary = {
      {contract_pk, Util.min_int(), nil},
      {contract_pk, Util.max_int(), nil}
    }

    deletion_keys =
      state
      |> Collection.stream(Model.Aex9BalanceAccount, :forward, key_boundary, nil)
      |> Enum.to_list()

    mutations = [
      DeleteKeysMutation.new(%{
        Model.AexnInvalidContract => [{:aex9, contract_pk}],
        Model.Aex9BalanceAccount => deletion_keys
      }),
      WriteMutation.new(
        Model.Stat,
        Model.stat(index: Stats.aex9_holder_count_key(contract_pk), payload: total_holders)
      ),
      WriteMutation.new(
        Model.Aex9ContractBalance,
        Model.aex9_contract_balance(index: contract_pk, amount: total_balances_amount)
      )
    ]

    total_mutations =
      mutations
      |> Stream.concat(balances_mutations)
      |> Stream.chunk_every(1000)
      |> Stream.map(fn mutations ->
        _state = State.commit_db(state, mutations)
        length(mutations)
      end)
      |> Enum.sum()

    {:ok, total_mutations}
  end

  defp update_balance(balances, account_pk, txi, idx, amount) do
    old_balance =
      case Map.get(balances, account_pk) do
        nil -> 0
        {balance, _txi, _idx} -> balance
      end

    Map.put(balances, account_pk, {old_balance + amount, txi, idx})
  end
end
