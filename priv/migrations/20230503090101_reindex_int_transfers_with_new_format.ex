defmodule AeMdw.Migrations.ReindexIntTransfersWithNewFormat do
  @moduledoc """
  Reindexes internal transfers from `{height, txi | -1}` format to `{height, txi_idx | -1}`.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    {_new_state, count} =
      state
      |> Collection.stream(Model.IntTransferTx, nil)
      |> Stream.filter(fn
        {{_height, -1}, _kind, _target_pk, -1} ->
          false

        {{_height, txi}, _kind, _target_pk, -1} when is_integer(txi) ->
          true

        {{_height, -1}, _kind, _target_pk, ref_txi} when is_integer(ref_txi) ->
          true

        {{_height, txi}, _kind, _target_pk, ref_txi}
        when is_integer(ref_txi) or is_integer(txi) ->
          true

        _key ->
          false
      end)
      |> Stream.map(fn {{height, opt_txi}, kind, target_pk, opt_ref_txi} = old_key ->
        opt_txi_idx = opt_txi_to_opt_txi_idx(opt_txi)
        opt_ref_txi_idx = opt_txi_to_opt_txi_idx(opt_ref_txi)
        Model.int_transfer_tx(amount: amount) = State.fetch!(state, Model.IntTransferTx, old_key)

        int_transfer =
          Model.int_transfer_tx(
            index: {{height, opt_txi_idx}, kind, target_pk, opt_ref_txi_idx},
            amount: amount
          )

        kind_tx =
          Model.kind_int_transfer_tx(
            index: {kind, {height, opt_txi_idx}, target_pk, opt_ref_txi_idx}
          )

        target_kind_tx =
          Model.target_kind_int_transfer_tx(
            index: {target_pk, kind, {height, opt_txi_idx}, opt_ref_txi_idx}
          )

        {height,
         [
           WriteMutation.new(Model.IntTransferTx, int_transfer),
           WriteMutation.new(Model.KindIntTransferTx, kind_tx),
           WriteMutation.new(Model.TargetKindIntTransferTx, target_kind_tx),
           DeleteKeysMutation.new(%{
             Model.IntTransferTx => [old_key],
             Model.KindIntTransferTx => [{kind, {height, opt_txi}, target_pk, opt_ref_txi}],
             Model.TargetKindIntTransferTx => [{target_pk, kind, {height, opt_txi}, opt_ref_txi}]
           })
         ]}
      end)
      |> Stream.chunk_every(10_000)
      |> Enum.reduce({state, 0}, fn [{first_height, _mutations} | _rest] = height_mutations,
                                    {state, count} ->
        mutations = Enum.flat_map(height_mutations, &elem(&1, 1))
        IO.puts("Processed up to height #{first_height}..")

        new_state = State.commit(state, mutations)

        {new_state, count + length(mutations)}
      end)

    {:ok, count}
  end

  defp opt_txi_to_opt_txi_idx(-1), do: -1

  defp opt_txi_to_opt_txi_idx({txi, idx}), do: {txi, idx}

  defp opt_txi_to_opt_txi_idx(txi), do: {txi, -1}
end
