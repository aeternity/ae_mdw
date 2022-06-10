defmodule AeMdw.DryRun.Contract do
  @moduledoc """
  Contract transactions for dry-running.
  """

  alias AeMdw.Util

  @typep pubkey() :: <<_::256>>
  @typep block_hash() :: <<_::256>>

  @abi_fate_sophia_1 3
  @gas 10_000_000_000_000_000_000_000

  @spec new_call_tx(
          pubkey(),
          pubkey(),
          block_hash(),
          AeMdw.Contract.method_name(),
          AeMdw.Contract.method_args(),
          pos_integer()
        ) :: tuple()
  def new_call_tx(caller_pk, contract_pk, block_hash, function_name, args, gas \\ @gas) do
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
      gas: gas,
      gas_price: min_gas_price(),
      call_data: call_data,
      fee: 200 * min_gas_price()
    }
    |> :aect_call_tx.new()
    |> Util.ok!()
  end

  @spec call_tx_base_gas(AeMdw.Blocks.height()) :: pos_integer()
  def call_tx_base_gas(height) do
    protocol = :aec_hard_forks.protocol_effective_at_height(height)
    :aec_governance.tx_base_gas(:contract_call_tx, protocol, abi_version())
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
