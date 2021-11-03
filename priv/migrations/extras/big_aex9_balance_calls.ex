defmodule BigAx9BalanceCalls do
  @max_wait_ms 30 * 60_000
  @tmp_table :tmp_aex9_presence_migration

  alias AeMdw.Node.Db, as: DBN

  alias AeMdw.Db.Contract, as: DbContract
  alias AeMdw.Db.Model
  alias AeMdw.Log
  alias AeMdwWeb.Helpers.Aex9Helper

  require Model
  require Ex2ms
  require Logger

  defmodule Account2Fix do
    defstruct [:account_pk, :contract_pk]
  end

  def run() do
    spawn_link(fn -> do_run() end)
  end

  def do_run() do
    begin = DateTime.utc_now()

    # for tasks/contracts that takes more than @max_wait_ms
    {:ok, _sup} =
        Supervisor.start_link([{Task.Supervisor, name: Aex9MigrationSupervisor}],
          strategy: :one_for_one
        )
    {:ok, _table} = :dets.open_file(@tmp_table, type: :set)

    indexed_count =
      @tmp_table
      |> :dets.match_object(:"$1")
      |> Enum.map(fn {contract_pk} ->
        IO.inspect contract_pk
        contract_pk
        |> accounts_without_balance()
        |> Enum.map(&index_account_aex9_presence/1)
        |> Enum.count()
      end)
      |> Enum.sum()

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("[#{__MODULE__}] Indexed #{indexed_count} records in #{duration}s")

    if :dets.first(@tmp_table) == :"$end_of_table" do
      :dets.close(@tmp_table)
      File.rm(to_string(@tmp_table))
    else
      :dets.close(@tmp_table)
    end
  end

  defp index_account_aex9_presence(%Account2Fix{
         account_pk: account_pk,
         contract_pk: contract_pk
       }) do
    :mnesia.transaction(fn ->
      # no call txi then -1 (and balance not necessarily from create)
      DbContract.aex9_write_presence(contract_pk, -1, account_pk)
      account_id = Aex9Helper.enc_id(account_pk)
      contract_id = Aex9Helper.enc_ct(contract_pk)
      Log.info("Fixed #{account_id} mapping to #{contract_id}")
    end)

    :ok
  end

  defp accounts_without_balance(contract_pk) do
    contract_id = Aex9Helper.enc_ct(contract_pk)
    Log.info("[#{__MODULE__}] Calling #{contract_id}...")

    task =
      Task.Supervisor.async_nolink(
        Aex9MigrationSupervisor,
        fn ->
          DBN.aex9_balances(contract_pk)
        end
      )

    case Task.yield(task, @max_wait_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, ok_res} ->
        Log.info("[#{__MODULE__}] Called #{contract_id}")
        {amounts, _last_block_tuple} = ok_res

        filter_accounts_without_balance(contract_pk, amounts)

      nil ->
        Log.warn("[#{__MODULE__}] Delayed again #{contract_id}")
        :dets.insert(@tmp_table, {contract_pk})
        []
    end
  end

  defp normalized_amounts(amounts), do: Aex9Helper.normalize_balances(amounts)

  defp filter_accounts_without_balance(contract_pk, amounts) do
    amounts
    |> normalized_amounts()
    |> Map.keys()
    |> Enum.map(fn account_id ->
      %Account2Fix{
        account_pk: AeMdw.Validate.id!(account_id, [:account_pubkey]),
        contract_pk: contract_pk
      }
    end)
    |> Enum.filter(fn %{contract_pk: contract_pk, account_pk: account_pk} ->
      :mnesia.async_dirty(fn -> not DbContract.aex9_presence_exists?(contract_pk, account_pk) end)
    end)
  end
end
