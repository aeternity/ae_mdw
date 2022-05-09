defmodule AeMdw.Migrations.MoveAsyncTasks do
  @moduledoc """
  Restructure async tasks to include extra args avoiding the use of cache
  to pass non deduped parameters.
  """

  alias AeMdw.Database
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Log

  require Model

  @spec run(boolean()) :: {:ok, {non_neg_integer(), non_neg_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()
    keys = Database.all_keys(Model.AsyncTasks)

    write_mutations =
      Enum.map(keys, fn key ->
        Model.async_tasks(index: {ts, type}, args: args) = Database.fetch!(Model.AsyncTasks, key)
        extra_args = get_extra_args(type, args)
        m_task = Model.async_task(index: {ts, type}, args: args, extra_args: extra_args)

        WriteMutation.new(Model.AsyncTask, m_task)
      end)

    mutations = [DeleteKeysMutation.new(%{Model.AsyncTasks => keys}) | write_mutations]

    State.commit(State.new(), mutations)

    indexed_count = length(mutations) - 1
    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{indexed_count} records in #{duration}s")

    {:ok, {indexed_count, duration}}
  end

  defp get_extra_args(:update_aex9_state, [contract_pk]) do
    create_txi = Origin.tx_index!({:contract, contract_pk})
    {:ok, {^create_txi, call_txi}} = Database.prev_key(Model.ContractCall, {create_txi, nil})
    Model.tx(block_index: block_index) = Database.fetch!(Model.Tx, call_txi)

    [block_index, call_txi]
  end

  defp get_extra_args(_other_type, _args), do: []
end
