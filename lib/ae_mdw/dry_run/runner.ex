defmodule AeMdw.DryRun.Runner do
  @moduledoc """
  Simulates transactions with dry run. This means that the calls won't be added to chain (nor it's results).
  """

  alias AeMdw.DryRun.Contract

  @typep pubkey() :: <<_::256>>
  @typep block_hash() :: <<_::256>>

  # arbitrary new pk to run the calls
  @runner_pk <<13, 24, 60, 171, 170, 28, 99, 114, 174, 14, 112, 19, 49, 53, 233, 194, 46, 149,
               172, 14, 114, 22, 38, 51, 153, 136, 58, 149, 27, 56, 30, 105>>

  @amount trunc(:math.pow(10, 35))

  @doc """
  Executes a transaction on a certain state of the chain.
  """
  @spec dry_run(tuple() | map(), block_hash()) :: {:ok, tuple()}
  def dry_run(tx_or_call_req, block_hash) do
    accounts = [%{pub_key: @runner_pk, amount: @amount}]
    txs = (is_tuple(tx_or_call_req) && [{:tx, tx_or_call_req}]) || [{:call_req, tx_or_call_req}]
    :aec_dry_run.dry_run(block_hash, accounts, txs, tx_events: false)
  end

  @doc """
  Creates a contract call transaction record (without running it).
  """
  @spec new_contract_call_tx(pubkey(), block_hash(), String.t(), list()) :: tuple()
  def new_contract_call_tx(contract_pk, block_hash, function_name, args) do
    Contract.new_call_tx(@runner_pk, contract_pk, block_hash, function_name, args)
  end
end
