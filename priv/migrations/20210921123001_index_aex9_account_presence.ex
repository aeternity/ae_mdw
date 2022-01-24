defmodule AeMdw.Migrations.IndexAex9AccountPresence do
  @moduledoc """
  Indexes missing Aex9AccountPresence based on contract balance.
  """
  alias AeMdw.Node.Db, as: DBN

  alias AeMdw.Db.Contract, as: DbContract
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Util
  alias AeMdw.Log
  alias AeMdw.Validate
  alias AeMdwWeb.Helpers.Aex9Helper

  require Model
  require Ex2ms
  require Logger

  @max_wait_ms 60_000
  @tmp_table :tmp_aex9_presence_migration

  defmodule Account2Fix do
    @moduledoc false
    defstruct [:account_pk, :contract_pk]
  end

  @doc """
  Calls the balance of all AEX9 contracts to check and index accounts presence.
  """
  @spec run(boolean()) :: {:ok, {pos_integer(), pos_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    # for tasks/contracts that takes more than @max_wait_ms
    {:ok, _sup} =
      Supervisor.start_link([{Task.Supervisor, name: Aex9MigrationSupervisor}],
        strategy: :one_for_one
      )

    :dets.open_file(@tmp_table, type: :set)

    indexed_count =
      fetch_aex9_contracts()
      |> Enum.map(fn contract_pk ->
        contract_pk
        |> accounts_without_balance()
        |> Enum.map(&index_account_aex9_presence/1)
        |> Enum.count()
      end)
      |> Enum.sum()

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    if :dets.first(@tmp_table) == :"$end_of_table" do
      :dets.close(@tmp_table)
      File.rm(to_string(@tmp_table))
    else
      :dets.close(@tmp_table)
    end

    {:ok, {indexed_count, duration}}
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

  defp fetch_aex9_contracts() do
    aex9_spec =
      Ex2ms.fun do
        {:aex9_contract, :_, :_} = record -> record
      end

    Model.Aex9Contract
    |> Util.select(aex9_spec)
    |> Enum.map(fn Model.aex9_contract(index: {_name, _symbol, txi, _decimals}) ->
      txi
      |> Util.read_tx!()
      |> Format.to_map()
      |> get_in(["tx", "contract_id"])
      |> Validate.id!([:contract_pubkey])
    end)
  end

  defp accounts_without_balance(contract_pk) do
    contract_id = Aex9Helper.enc_ct(contract_pk)
    Log.info("Calling #{contract_id}...")

    task =
      Task.Supervisor.async_nolink(
        Aex9MigrationSupervisor,
        fn ->
          DBN.aex9_balances(contract_pk)
        end
      )

    case Task.yield(task, @max_wait_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, ok_res} ->
        Log.info("Called #{contract_id}")
        {amounts, _last_block_tuple} = ok_res

        filter_accounts_without_balance(contract_pk, amounts)

      nil ->
        Log.warn("Delayed #{contract_id}")
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
      create_txi =
        case Origin.tx_index({:contract, contract_pk}) do
          :not_found -> -1
          {:ok, create_txi} -> create_txi
        end

      :mnesia.async_dirty(fn ->
        not DbContract.aex9_presence_exists?(contract_pk, account_pk, create_txi)
      end)
    end)
  end
end
