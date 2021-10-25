defmodule AeMdw.Migrations.IndexAex9AccountPresence do
  @moduledoc """
  Indexes missing Aex9AccountPresence based on contract balance.
  """
  alias AeMdw.Node.Db, as: DBN

  alias AeMdw.Db.Contract, as: DbContract
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Validate
  alias AeMdwWeb.Helpers.Aex9Helper

  require Model
  require Ex2ms

  @contracts_chunk_size 30

  defmodule Account2Fix do
    defstruct [:account_pk, :contract_pk]
  end

  @doc """

  """
  @spec run(boolean()) :: {:ok, {pos_integer(), pos_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    indexed_count =
      fetch_aex9_contracts()
      |> Enum.chunk_every(@contracts_chunk_size)
      |> Enum.reduce(0, fn contracts_chunk, acc ->
        count =
          contracts_chunk
          |> accounts_without_balance()
          |> Enum.map(&index_account_aex9_presence/1)
          |> Enum.count()

        acc + count
      end)

    duration = DateTime.diff(DateTime.utc_now(), begin)
    IO.puts("Indexed #{indexed_count} records in #{duration}s")

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
      IO.puts("Fixed #{account_id} mapping to #{contract_id}")
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

  defp accounts_without_balance(contract_list) do
    contract_list
    |> Enum.map(fn contract_pk ->
      # Process.sleep(5000)
      contract_id = Aex9Helper.enc_ct(contract_pk)
      IO.puts("Calling #{contract_id}...")
      {amounts, _last_block_tuple} = DBN.aex9_balances(contract_pk)
      IO.puts("Called #{contract_id}")

      {contract_pk, normalized_amounts(amounts)}
    end)
    |> Enum.flat_map(fn {contract_pk, amounts} ->
      amounts
      |> Map.keys()
      |> Enum.filter(fn account_id -> Map.get(amounts, account_id) > 0 end)
      |> Enum.map(fn account_id ->
        %Account2Fix{
          account_pk: AeMdw.Validate.id!(account_id, [:account_pubkey]),
          contract_pk: contract_pk
        }
      end)
    end)
    |> Enum.filter(fn %Account2Fix{contract_pk: contract_pk, account_pk: account_pk} ->
      :mnesia.async_dirty(fn -> not DbContract.aex9_presence_exists?(contract_pk, account_pk) end)
    end)
  end

  defp normalized_amounts(amounts), do: Aex9Helper.normalize_balances(amounts)
end
