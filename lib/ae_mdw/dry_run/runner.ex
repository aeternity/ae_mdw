defmodule AeMdw.DryRun.Runner do
  @moduledoc """
  Simulates transactions with dry run. This means that the calls won't be added to chain (nor it's results).
  """

  alias AeMdw.DryRun.Contract
  alias AeMdw.Node.Db, as: DBN

  @typep block_hash :: AeMdw.Blocks.block_hash()
  @typep method_name :: AeMdw.Contract.method_name()
  @typep method_args :: AeMdw.Contract.method_args()

  @typep node_call_res :: {:ok, AeMdw.Node.aect_call()} | {:error, any()}

  @type node_run_request :: map()
  @type run_tx_res :: {AeMdw.Node.tx_type(), node_call_res()}
  @type node_event :: tuple()
  @type node_run_result :: {[run_tx_res()], [node_event()]}
  @type call_return :: any()

  # arbitrary new pk to run the calls
  @runner_pk <<13, 24, 60, 171, 170, 28, 99, 114, 174, 14, 112, 19, 49, 53, 233, 194, 46, 149,
               172, 14, 114, 22, 38, 51, 153, 136, 58, 149, 27, 56, 30, 105>>

  @amount trunc(:math.pow(10, 35))
  @low_gas_limit_factor 1.5
  @extension_methods ["aex9_extensions", "aex141_extensions"]

  @spec call_contract(DBN.pubkey(), method_name(), method_args()) ::
          {:ok, call_return()} | {:error, binary() | :dry_run_error} | :revert
  def call_contract(contract_pk, function_name, args),
    do: call_contract(contract_pk, DBN.top_height_hash(false), function_name, args)

  @spec call_contract(DBN.pubkey(), DBN.height_hash(), method_name(), method_args()) ::
          {:ok, call_return()} | {:error, binary() | :dry_run_error} | :revert
  def call_contract(contract_pk, {_type, height, block_hash}, function_name, args) do
    contract_pk
    |> new_contract_call_tx(height, block_hash, function_name, args)
    |> dry_run(block_hash)
    |> case do
      {:ok, {[contract_call_tx: {:ok, call_res}], _events}} ->
        case :aect_call.return_type(call_res) do
          :ok ->
            res_binary = :aect_call.return_value(call_res)
            {:ok, :aeb_fate_encoding.deserialize(res_binary)}

          :error ->
            {:error, :aect_call.return_value(call_res)}

          :revert ->
            :revert
        end

      {:error, _internal_error_msg} ->
        {:error, :dry_run_error}
    end
  end

  @doc """
  Executes a single transaction on a certain state of the chain.
  """
  @spec dry_run(AeMdw.Node.aetx() | node_run_request(), block_hash()) ::
          {:ok, node_run_result()} | {:error, iodata()}
  def dry_run(tx_or_call_req, block_hash) do
    accounts = [%{pub_key: @runner_pk, amount: @amount}]
    txs = (is_tuple(tx_or_call_req) && [{:tx, tx_or_call_req}]) || [{:call_req, tx_or_call_req}]
    :aec_dry_run.dry_run(block_hash, accounts, txs, tx_events: false)
  end

  defp new_contract_call_tx(contract_pk, height, block_hash, function_name, args)
       when function_name == "meta_info" or function_name in @extension_methods do
    base_gas = Contract.call_tx_base_gas(height)

    Contract.new_call_tx(
      @runner_pk,
      contract_pk,
      block_hash,
      function_name,
      args,
      trunc(base_gas * @low_gas_limit_factor)
    )
  end

  defp new_contract_call_tx(contract_pk, _height, block_hash, function_name, args) do
    Contract.new_call_tx(@runner_pk, contract_pk, block_hash, function_name, args)
  end
end
