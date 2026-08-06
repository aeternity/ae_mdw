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
  @type call_error :: binary() | :contract_does_not_exist | :dry_run_error

  # arbitrary new pk to run the calls
  @runner_pk <<13, 24, 60, 171, 170, 28, 99, 114, 174, 14, 112, 19, 49, 53, 233, 194, 46, 149,
               172, 14, 114, 22, 38, 51, 153, 136, 58, 149, 27, 56, 30, 105>>

  @amount trunc(:math.pow(10, 35))
  @extension_methods ["aex9_extensions", "aex141_extensions"]

  # Execution budget for the AEX-N introspection calls. They return a
  # fixed-size tuple and never iterate a collection, so the only input-dependent
  # cost is loading the contract's state register, which is charged per byte.
  # 6_000_000 is the protocol's default per-microblock gas limit: no contract
  # call the chain itself would accept can consume more than this, so it is an
  # upper bound on honest work while still capping a looping contract during
  # sync. It is a constant rather than a read of
  # `:aec_governance.block_gas_limit/0` so that a node configured with a lower
  # gas limit cannot shrink it - the metadata is resolved once, at contract
  # creation, and an `out_of_gas` result is written to the index permanently.
  @introspection_gas 6_000_000

  @spec call_contract(DBN.pubkey(), method_name(), method_args()) ::
          {:ok, call_return()} | {:error, call_error()} | :revert
  def call_contract(contract_pk, function_name, args),
    do: call_contract(contract_pk, DBN.top_height_hash(false), function_name, args)

  @spec call_contract(DBN.pubkey(), DBN.height_hash(), method_name(), method_args()) ::
          {:ok, call_return()} | {:error, call_error()} | :revert
  def call_contract(contract_pk, {_type, _height, block_hash}, function_name, args) do
    contract_pk
    |> new_contract_call_tx(function_name, args)
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

      {:ok, {[contract_call_tx: {:error, :contract_does_not_exist}], []}} ->
        {:error, :contract_does_not_exist}

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

  defp new_contract_call_tx(contract_pk, function_name, args)
       when function_name == "meta_info" or function_name in @extension_methods do
    Contract.new_call_tx(
      @runner_pk,
      contract_pk,
      function_name,
      args,
      @introspection_gas
    )
  end

  defp new_contract_call_tx(contract_pk, function_name, args) do
    Contract.new_call_tx(@runner_pk, contract_pk, function_name, args)
  end
end
