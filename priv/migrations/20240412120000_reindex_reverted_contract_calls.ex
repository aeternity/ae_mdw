defmodule AeMdw.Migrations.ReindexRevertedContractCalls do
  @moduledoc """
  Re-index contract calls where the result of the call is :reverted.
  """

  alias AeMdw.Collection
  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.ContractCallMutation
  alias AeMdw.Node.Db

  import Bitwise

  @field_pos 1 <<< 15

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    count =
      state
      |> Collection.stream(Model.Field, {:contract_call_tx, @field_pos, "<unknown>", -1})
      |> Stream.take_while(&match?({:contract_call_tx, @field_pos, "<unknown>", _txi}, &1))
      |> Stream.map(fn {:contract_call_tx, @field_pos, "<unknown>", txi} ->
        Model.tx(id: tx_hash) = State.fetch!(state, Model.Tx, txi)
        {block_hash, :contract_call_tx, _signed_tx, tx} = Db.get_tx_data(tx_hash)

        contract_or_name_pk =
          tx
          |> :aect_call_tx.contract_id()
          |> Db.id_pubkey()

        contract_pk =
          Contract.maybe_resolve_contract_pk(
            contract_or_name_pk,
            block_hash
          )

        {Contract.call_tx_info(tx, contract_pk, contract_or_name_pk, block_hash),
         {contract_pk, txi}}
      end)
      |> Stream.filter(&match?({{%{result: :invalid}, _call}, _tx_info}, &1))
      |> Stream.map(fn {{fun_arg_res, call}, {contract_pk, txi}} ->
        call = :aect_call.set_log([], call)
        ContractCallMutation.new(contract_pk, txi, fun_arg_res, call)
      end)
      |> Stream.chunk_every(1_000)
      |> Stream.map(fn mutations ->
        _new_state = State.commit_db(state, mutations)
        length(mutations)
      end)
      |> Enum.sum()

    {:ok, count}
  end
end
