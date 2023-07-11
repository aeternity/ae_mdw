defmodule AeMdw.Migrations.EventLogsHash do
  # credo:disable-for-this-file
  @moduledoc """
  Reindex logs to move the hash out of the key and use built-in encoding for the value part of the records.
  """

  alias AeMdw.Db.RocksDb
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State

  require Model
  require Logger

  @range_size 200_000

  @dialyzer :no_return

  defmodule DeleteKeysMutation do
    @moduledoc false
    alias AeMdw.Db.Model
    alias AeMdw.Db.State
    alias AeMdw.Db.RocksDb

    require Model

    @derive AeMdw.Db.Mutation
    defstruct [:args]

    def new(args) do
      %__MODULE__{args: args}
    end

    def execute(%__MODULE__{args: [log_key, data_log_key, idx_log_key]}, state) do
      txn = Map.get(state.store, :txn)
      :ok = RocksDb.delete(txn, Model.ContractLog, :sext.encode(log_key))
      :ok = RocksDb.delete(txn, Model.DataContractLog, :sext.encode(data_log_key))
      :ok = RocksDb.delete(txn, Model.IdxContractLog, :sext.encode(idx_log_key))
      state
    end
  end

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    case State.prev(state, Model.Tx, nil) do
      {:ok, db_last_txi} ->
        num_ranges = div(db_last_txi, @range_size) + 1

        count =
          0..(num_ranges - 1)
          |> Enum.map(fn i ->
            first_txi = i * @range_size
            last_txi = min((i + 1) * @range_size, db_last_txi)

            range_mutations = logs_mutations(state, first_txi, last_txi)
            count = length(range_mutations)
            log("commiting #{count} mutations...")

            range_mutations
            |> Enum.chunk_every(240_000)
            |> Enum.each(fn write_mutations ->
              {ts, _state} = :timer.tc(fn -> _state = State.commit(state, write_mutations) end)
              IO.puts("commit: #{inspect({length(write_mutations), ts})}")
            end)

            count
          end)
          |> Enum.sum()

        {:ok, count}

      :none ->
        {:ok, 0}
    end
  end

  defp logs_mutations(state, first_txi, last_txi) do
    :erlang.garbage_collect()
    num_tasks = System.schedulers_online()
    amount_per_task = trunc(:math.ceil((last_txi - first_txi) / num_tasks))

    log("num_tasks: #{num_tasks}, amount_per_task: #{amount_per_task}")
    log("first_txi: #{first_txi}, last_txi: #{last_txi}")

    Enum.map(0..(num_tasks - 1), fn i ->
      task_first_txi = first_txi + i * amount_per_task
      task_last_txi = first_txi + (i + 1) * amount_per_task
      cursor = {task_first_txi, 0, 0, <<>>}
      boundary = {cursor, {task_last_txi, nil, nil, <<>>}}

      Task.async(fn ->
        state
        |> Collection.stream(Model.IdxContractLog, :forward, boundary, cursor)
        |> Enum.flat_map(fn {call_txi, log_idx, create_txi, evt_hash} = idx_log_key ->
          log_key = {create_txi, call_txi, evt_hash, log_idx}

          {:contract_log, ^log_key, ext_contract, args, data} = fetch_old!(log_key)

          m_log =
            Model.contract_log(
              index: {create_txi, call_txi, log_idx},
              ext_contract: ext_contract,
              args: args,
              data: data,
              hash: evt_hash
            )

          m_data_log = Model.data_contract_log(index: {data, call_txi, create_txi, log_idx})
          m_idx_log = Model.idx_contract_log(index: {call_txi, log_idx, create_txi})

          data_log_key = {data, call_txi, create_txi, evt_hash, log_idx}

          [
            DeleteKeysMutation.new([log_key, data_log_key, idx_log_key]),
            WriteMutation.new(Model.ContractLog, m_log),
            WriteMutation.new(Model.DataContractLog, m_data_log),
            WriteMutation.new(Model.IdxContractLog, m_idx_log)
          ]
        end)
      end)
    end)
    |> Task.await_many(60_000 * 20)
    |> List.flatten()
    |> Enum.uniq()
  end

  @spec log(binary()) :: :ok
  def log(msg) do
    Logger.info(msg)
    IO.puts(msg)
  end

  defp fetch_old!(index) do
    key = :sext.encode(index)

    {:ok, value} = RocksDb.get(Model.ContractLog, key)
    record_type = Model.record(Model.ContractLog)

    value
    |> :sext.decode()
    |> Tuple.insert_at(0, index)
    |> Tuple.insert_at(0, record_type)
  end
end
