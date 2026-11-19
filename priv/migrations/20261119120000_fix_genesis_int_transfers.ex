defmodule AeMdw.Migrations.FixGenesisIntTransfers do
  @moduledoc """
  Replaces the `accounts_genesis` int transfers that older presets wrote with the
  `accounts_roma` ones that sync now writes at height 0, also on networks that had none.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.HardforkPresets
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @old_kind "accounts_genesis"

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    old_keys =
      state
      |> Collection.stream(Model.KindIntTransferTx, {@old_kind, nil, nil, nil})
      |> Stream.take_while(&match?({@old_kind, _bi, _target, _ref_txi}, &1))
      |> Enum.to_list()

    delete_mutation =
      DeleteKeysMutation.new(%{
        Model.KindIntTransferTx => old_keys,
        Model.IntTransferTx =>
          Enum.map(old_keys, fn {kind, bi, pk, ref_txi} -> {bi, kind, pk, ref_txi} end),
        Model.TargetKindIntTransferTx =>
          Enum.map(old_keys, fn {kind, bi, pk, ref_txi} -> {pk, kind, bi, ref_txi} end)
      })

    {genesis_mutations, written_count} =
      if State.exists?(state, Model.Block, {0, -1}) do
        {[HardforkPresets.genesis_transfers_mutation()],
         length(:aec_fork_block_settings.genesis_accounts())}
      else
        {[], 0}
      end

    _state = State.commit_db(state, [delete_mutation | genesis_mutations])

    {:ok, length(old_keys) + written_count}
  end
end
