defmodule AeMdw.Migrations.DeriveAex9PresenceAndBalance do
  @moduledoc """
  Initializes aex9 presence and balance.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Log
  alias AeMdw.Sync.AsyncTasks

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    indexed_count =
      fetch_aex9_pubkeys()
      |> Enum.map(fn contract_pk ->
        create_txi = fetch_aex9_txi(contract_pk)
        {kbi, mbi} = fetch_txi_bi(create_txi)
        AsyncTasks.Producer.enqueue(:derive_aex9_presence, [contract_pk, kbi, mbi, create_txi])
      end)
      |> Enum.count()

    AsyncTasks.Producer.commit_enqueued()

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end

  defp fetch_aex9_pubkeys() do
    Model.Aex9ContractPubkey
    |> Database.all_keys()
    |> Enum.filter(fn contract_pk ->
      case Database.next_key(Model.Aex9Balance, {contract_pk, nil}) do
        {:ok, {^contract_pk, _account_pk}} -> false
        _not_found -> true
      end
    end)
  end

  defp fetch_aex9_txi(contract_pk) do
    Model.aex9_contract_pubkey(txi: txi) = Database.fetch!(Model.Aex9ContractPubkey, contract_pk)
    txi
  end

  defp fetch_txi_bi(create_txi) do
    Model.tx(block_index: block_index) = Util.read_tx!(create_txi)
    block_index
  end
end
