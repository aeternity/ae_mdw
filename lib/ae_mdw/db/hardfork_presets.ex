defmodule AeMdw.Db.HardforkPresets do
  @moduledoc """
  Saves hardfork presets into Mdw database.
  """
  alias AeMdw.Database
  alias AeMdw.Db.IntTransfersMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node

  @type hardfork :: :roma | :minerva | :fortuna | :lima | :iris | :ceres

  @doc """
  Imports hardfork migrated accounts.
  """
  @spec import_account_presets() :: :ok
  def import_account_presets do
    case Database.next_key(Model.KindIntTransferTx, {"accounts_lima", {-1, -1}, <<>>, -1}) do
      {:ok, {"accounts_lima", _bi, _target, _txi}} ->
        :ok

      _missing ->
        _state = do_import_account_presets()

        :ok
    end
  end

  @spec hardfork_height(hardfork()) :: AeMdw.Blocks.height()
  def hardfork_height(:roma), do: 0

  def hardfork_height(hardfork) do
    hf_vsn = :aec_hard_forks.protocol_vsn(hardfork)

    :aec_governance.get_network_id()
    |> :aec_hard_forks.protocols_from_network_id()
    |> Map.get(hf_vsn)
  end

  @spec mint_sum(hardfork()) :: pos_integer
  def mint_sum(hardfork) do
    hardfork
    |> accounts()
    |> Enum.map(fn {_pk, amount} -> amount end)
    |> Enum.sum()
  end

  defp accounts(:roma), do: :aec_fork_block_settings.genesis_accounts()
  defp accounts(:minerva), do: :aec_fork_block_settings.minerva_accounts()
  defp accounts(:fortuna), do: :aec_fork_block_settings.fortuna_accounts()
  defp accounts(:lima) do
    contract_account =
      Node.lima_contracts()
      |> Enum.map(fn %{pubkey: pk, amount: amount} ->
        {pk, amount}
      end)

    contract_account ++
      Node.lima_accounts() ++
      Node.lima_extra_accounts()
  end
  defp accounts(:iris), do: %{}
  defp accounts(:ceres), do: %{}

  defp do_import_account_presets() do
    if :aec_governance.get_network_id() in ["ae_uat", "ae_mainnet"] do
      State.commit(
        State.new(),
        [
          hardfork_mutation(:roma, &:aec_fork_block_settings.genesis_accounts/0),
          hardfork_mutation(:minerva, &:aec_fork_block_settings.minerva_accounts/0),
          hardfork_mutation(:fortuna, &:aec_fork_block_settings.fortuna_accounts/0),
          hardfork_mutation(:lima, &Node.lima_accounts/0),
          lima_contracts_mutation(),
          lima_extra_accounts_mutation()
        ]
      )
    end
  end

  defp hardfork_mutation(hardfork, fork_settings_accounts_fn) do
    transfers = hardfork_transfers("accounts_#{hardfork}", fork_settings_accounts_fn)

    hardfork
    |> hardfork_height()
    |> IntTransfersMutation.new(transfers)
  end

  defp lima_extra_accounts_mutation do
    transfers = hardfork_transfers("accounts_extra_lima", &Node.lima_extra_accounts/0)

    :lima
    |> hardfork_height()
    |> IntTransfersMutation.new(transfers)
  end

  defp lima_contracts_mutation do
    transfers =
      Node.lima_contracts()
      |> Enum.map(fn %{pubkey: pk, amount: amount} ->
        {"contracts_lima", pk, amount}
      end)

    :lima
    |> hardfork_height()
    |> IntTransfersMutation.new(transfers)
  end

  defp hardfork_transfers(kind, fork_settings_accounts_fn) do
    fork_settings_accounts_fn.()
    |> Enum.map(fn {account_pk, amount} ->
      {kind, account_pk, amount}
    end)
  end
end
