defmodule AeMdw.DryRun.Contract do
  @moduledoc """
  Contract transactions for dry-running.
  """

  alias AeMdw.Util

  @typep pubkey() :: <<_::256>>

  @abi_fate_sophia_1 3
  # allows 10 times the gas used for a contract with balance for aprox 50k accounts.
  @gas 910_000_000 * 10

  @spec new_call_tx(
          pubkey(),
          pubkey(),
          AeMdw.Contract.method_name(),
          AeMdw.Contract.method_args(),
          pos_integer()
        ) :: AeMdw.Node.aetx()
  def new_call_tx(caller_pk, contract_pk, function_name, args, gas \\ @gas) do
    contract_id = :aeser_id.create(:contract, contract_pk)

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
