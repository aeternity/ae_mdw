defmodule AeMdw.Migrations.FixInternalOracleResponsesTransfers do
  @moduledoc """
  Reindexes internal oracle_reward transfers that are in the format `{height, {txi, -1}}`,
  but should actually point to an internal call using `{height, {txi, idx}}`.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Db.State
  alias AeMdw.Util

  require Model

  @kind "reward_oracle"

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    scope = {
      {@kind, {Util.min_int(), Util.min_int()}, nil, nil},
      {@kind, {Util.max_int(), Util.max_int()}, nil, nil}
    }

    mutations =
      state
      |> Collection.stream(Model.KindIntTransferTx, :forward, scope, nil)
      |> Stream.flat_map(fn {@kind, {height, old_response_txi_idx}, target_pk, old_query_txi_idx} =
                              old_kind_key ->
        Model.int_transfer_tx(amount: amount) =
          State.fetch!(
            state,
            Model.IntTransferTx,
            {{height, old_response_txi_idx}, @kind, target_pk, old_query_txi_idx}
          )

        response_txi_idx =
          correct_txi_idx(state, old_response_txi_idx, "Oracle.respond", :oracle_response_tx)

        query_txi_idx =
          correct_txi_idx(state, old_query_txi_idx, "Oracle.query", :oracle_query_tx)

        int_transfer =
          Model.int_transfer_tx(
            index: {{height, response_txi_idx}, @kind, target_pk, query_txi_idx},
            amount: amount
          )

        new_kind_key = {@kind, {height, response_txi_idx}, target_pk, query_txi_idx}
        kind_tx = Model.kind_int_transfer_tx(index: new_kind_key)

        target_kind_tx =
          Model.target_kind_int_transfer_tx(
            index: {target_pk, @kind, {height, response_txi_idx}, query_txi_idx}
          )

        if old_kind_key != new_kind_key do
          [
            WriteMutation.new(Model.IntTransferTx, int_transfer),
            WriteMutation.new(Model.KindIntTransferTx, kind_tx),
            WriteMutation.new(Model.TargetKindIntTransferTx, target_kind_tx),
            DeleteKeysMutation.new(%{
              Model.IntTransferTx => [
                {{height, old_response_txi_idx}, @kind, target_pk, old_query_txi_idx}
              ],
              Model.KindIntTransferTx => [old_kind_key],
              Model.TargetKindIntTransferTx => [
                {target_pk, @kind, {height, old_response_txi_idx}, old_query_txi_idx}
              ]
            })
          ]
        else
          []
        end
      end)
      |> Enum.to_list()

    _new_state = State.commit(state, mutations)

    {:ok, length(mutations)}
  end

  defp correct_txi_idx(state, {txi, _idx} = old_txi_idx, fname, tx_type) do
    case DbUtil.read_node_tx_details(state, old_txi_idx) do
      {_tx, ^tx_type, _hash, _tx_type, _block_hash} ->
        old_txi_idx

      _contract_call_details ->
        {:ok, {^fname, ^txi, idx}} =
          State.next(state, Model.FnameIntContractCall, {fname, txi, -1})

        {txi, idx}
    end
  end
end
