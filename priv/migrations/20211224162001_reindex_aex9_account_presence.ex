defmodule AeMdw.Migrations.IndexAex9AccountPresenceWithCreateTxi do
  @moduledoc """
  Indexes Aex9AccountPresence with `create_txi` for every {account_pk, contract_pk} pair.
  """
  alias AeMdw.Database
  alias AeMdw.Db.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Log

  require Model

  @doc """
  Writes {account_pk, create_txi, contract_pk} aex9 presence and deletes old ones with txi = -1.
  """
  @spec run(boolean()) :: {:ok, {pos_integer(), pos_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    {:atomic, pairs_to_update} =
      :mnesia.transaction(fn ->
        Model.Aex9AccountPresence
        |> Database.all_keys()
        |> Enum.into(MapSet.new(), fn {account_pk, _txi, contract_pk} ->
          {account_pk, contract_pk}
        end)
      end)

    indexed_count =
      :mnesia.sync_dirty(fn ->
        Enum.reduce(pairs_to_update, 0, fn {account_pk, contract_pk}, acc ->
          create_txi = Origin.tx_index!({:contract, contract_pk})

          Contract.aex9_delete_presence(contract_pk, -1, account_pk)
          Contract.aex9_write_presence(contract_pk, create_txi, account_pk)

          acc = acc + 1
          # credo:disable-for-next-line
          if rem(acc, 100) == 0, do: :mnesia.dump_log()

          acc
        end)
      end)

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end
end
