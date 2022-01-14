defmodule AeMdw.Migrations.InactiveNameOwner do
  @moduledoc """
  Indexes InactiveNameOwner based on owner field for names in InactiveName table.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Log

  require Ex2ms
  require Model

  @doc """
  Writes {account_pk, create_txi, contract_pk} aex9 presence and deletes old ones with txi = -1.
  """
  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    indexed_count = :mnesia.sync_dirty(fn ->
      any_spec =
        Ex2ms.fun do
          record -> record
        end

      Model.InactiveName
      |> :mnesia.select(any_spec, :read)
      |> Enum.map(fn Model.name(index: plain_name, owner: owner) ->
        m_owner = Model.owner(index: {owner, plain_name})
        :mnesia.write(Model.InactiveNameOwner, m_owner, :write)
      end)
      |> Enum.count()
    end)

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end
end
