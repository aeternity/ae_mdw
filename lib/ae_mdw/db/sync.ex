defmodule AeMdw.Db.Sync do
  require Logger
  require AeMdw.Db.Model

  alias AeMdw.Db.Model, as: Model

  import AeMdw.Util

  use GenServer

  def init(_) do
    # {:ok, next_generation()} # TODO:, {:continue, :start_sync}}
  end

  def handle_continue(:start_sync, next_gen) do
    #     cond do
    #       has_work?(next_gen) ->
    # #        sync(next_gen)
    #         {:noreply, next_gen}
    #       true ->
    #         {:noreply, next_gen}
    #     end
  end

  def sync(_height) do
    # meta = Model.list_meta()
    # bi_height = meta[:sync_block_index] ||
    #   raise KeyError, key: :sync_block_index # we can run only *after* block index sync finishes
  end

  # def has_work?(next_gen \\ next_generation()),
  #   do: next_gen < :aec_headers.height(:aec_chain.top_header())

  # def next_generation() do
  #   empty_chain_key = Model.defaults(:chain)[:key]
  #   (~t[chain] |> Mnesia.dirty_last |> last_key(empty_chain_key) |> elem(0)) + 1
  # end

  # defp last_key(key, default \\ -1)
  # defp last_key(:"$end_of_table", default), do: default
  # defp last_key(key, _default), do: key

  def progress_logger(work_fn, freq, msg_fn) do
    fn x, acc ->
      rem(x, freq) == 0 && Logger.info(msg_fn.(x, acc))
      work_fn.(x, acc)
    end
  end
end
