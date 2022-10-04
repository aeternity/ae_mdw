defmodule AeMdw.Migrations.AddTypeCountTable do
  @moduledoc """
  Add type count table to contain the count for each tx type.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.RocksDbCF
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Util

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    {mutations, indexed_count} =
      Model.Type
      |> Database.first_key()
      |> Stream.unfold(fn
        {:ok, {tx_type, _txi}} ->
          {tx_type, Database.next_key(Model.Type, {tx_type, Util.max_int()})}

        :none ->
          nil
      end)
      |> Stream.map(fn tx_type ->
        count =
          RocksDbCF.count_range(
            Model.Type,
            {tx_type, Util.min_int()},
            {tx_type, Util.max_int()}
          )

        {tx_type, count}
      end)
      |> Enum.map_reduce(0, fn {tx_type, count}, acc ->
        {WriteMutation.new(Model.TypeCount, Model.type_count(index: tx_type, count: count)),
         acc + count}
      end)

    _state = State.commit(state, mutations)

    {:ok, indexed_count}
  end
end
