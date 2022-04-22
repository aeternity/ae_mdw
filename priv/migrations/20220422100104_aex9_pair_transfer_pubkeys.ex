defmodule AeMdw.Migrations.Aex9PairTransferPubkeys do
  @moduledoc """
  Fixes the order of aex9 pair transfer pubkeys.
  """

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Model
  alias AeMdw.Log

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    old_keys_and_mutations =
      Model.Aex9PairTransfer
      |> Collection.stream({<<>>, <<>>, -1, -1, -1})
      |> Stream.map(fn {to_pk, from_pk, txi, amount, i} = old_key ->
        m_pair_transfer = Model.aex9_pair_transfer(index: {from_pk, to_pk, txi, amount, i})
        {old_key, WriteMutation.new(Model.Aex9PairTransfer, m_pair_transfer)}
      end)
      |> Enum.to_list()

    Database.commit([
      DeleteKeysMutation.new(%{
        Model.Aex9PairTransfer =>
          Enum.map(old_keys_and_mutations, fn {old_key, _mutation} -> old_key end)
      })
    ])

    old_keys_and_mutations
    |> Enum.map(fn {_old_key, mutation} -> mutation end)
    |> Database.commit()

    indexed_count = length(old_keys_and_mutations)

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end
end
