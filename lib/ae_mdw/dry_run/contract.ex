defmodule AeMdw.DryRun.Contract do
  @moduledoc """
  Contract transactions for dry-running.
  """

  alias AeMdw.Util

  @abi_fate_sophia_1 3

  @gas 10_000_000_000_000_000_000

  def new_call_tx(caller_pk, contract_pk, block_hash, function_name, args) do
    {_tx_env, trees} = :aetx_env.tx_env_and_trees_from_hash(:aetx_contract, block_hash)
    contracts = :aec_trees.contracts(trees)

    contract_id =
      contract_pk
      |> :aect_state_tree.get_contract(contracts)
      |> :aect_contracts.id()

    call_data =
      function_name
      |> String.to_charlist()
      |> :aeb_fate_abi.create_calldata(args)
      |> Util.ok!()

    %{
      caller_id: :aeser_id.create(:account, caller_pk),
      nonce: 1,
      contract_id: contract_id,
      abi_version: abi_version(),
      amount: 0,
      gas: @gas,
      gas_price: div(min_gas_price(), 1000),
      call_data: call_data,
      fee: 200 * min_gas_price()
    }
    |> :aect_call_tx.new()
    |> Util.ok!()
  end

  defp min_gas_price do
    protocol = :aec_hard_forks.protocol_effective_at_height(1)

    max(
      :aec_governance.minimum_gas_price(protocol),
      :aec_tx_pool.minimum_miner_gas_price()
    )
  end

  defp abi_version, do: @abi_fate_sophia_1
end
