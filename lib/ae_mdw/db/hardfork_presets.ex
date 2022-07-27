defmodule AeMdw.Db.HardforkPresets do
  @moduledoc """
  Saves hardfork presets into Mdw database.
  """
  alias AeMdw.Database
  alias AeMdw.Db.IntTransfersMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  @doc """
  Imports hardfork migrated accounts.
  """
  @spec import_account_presets() :: :ok
  def import_account_presets do
    case Database.next_key(Model.KindIntTransferTx, {"accounts_lima", {-1, -1}, <<>>, -1}) do
      {:ok, {"accounts_lima", _bi, _target, _txi}} ->
        :ok

      _missing ->
        do_import_account_presets()
    end
  end

  defp do_import_account_presets() do
    genesis_mutation = hardfork_mutation(:genesis, &:aec_fork_block_settings.genesis_accounts/0)
    minerva_mutation = hardfork_mutation(:minerva, &:aec_fork_block_settings.minerva_accounts/0)
    fortuna_mutation = hardfork_mutation(:fortuna, &:aec_fork_block_settings.fortuna_accounts/0)
    lima_mutation = hardfork_mutation(:lima, &:aec_fork_block_settings.lima_accounts/0)

    State.commit(State.new(), [
      genesis_mutation,
      minerva_mutation,
      fortuna_mutation,
      lima_mutation
    ])
  end

  defp hardfork_mutation(hardfork, fork_settings_accounts_fn) do
    transfers = hardfork_transfers("accounts_#{hardfork}", fork_settings_accounts_fn)

    hardfork
    |> hardfork_height()
    |> IntTransfersMutation.new(transfers)
  end

  defp hardfork_transfers(kind, fork_settings_accounts_fn) do
    fork_settings_accounts_fn.()
    |> Enum.map(fn {account_pk, amount} ->
      {kind, account_pk, amount}
    end)
  end

  defp hardfork_height(:genesis), do: 0

  defp hardfork_height(hardfork) do
    hf_vsn = :aec_hard_forks.protocol_vsn(hardfork)

    :aec_governance.get_network_id()
    |> :aec_hard_forks.protocols_from_network_id()
    |> Map.get(hf_vsn)
  end
end
