defmodule AeMdw.Migrations.ReindexRemoteLogs do
  @moduledoc """
  Reindexes remote call event logs with the called contract txi.
  The logs indexed by the caller contract are not changed.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Util
  alias AeMdw.Log
  alias AeMdw.Database

  require Model
  require Ex2ms
  require Logger

  # single case of pubkey that causes a pk mismatch error:
  # ** (CaseClauseError) no case clause matching: {:contract_create_tx, <<84, 161, 71, 116, 248, 82, 0, 46, 52, 142, 60, 121, 255, 115, 239, 189, 180, 252, 224, 142, 255, 39, 10, 83, 243, 93, 69, 189, 148, 123, 164, 60>>, 22913712}
  # https://github.com/aeternity/ae_mdw/blob/0854208fbc932f6214b7378b29b23bd1021be1b3/lib/ae_mdw/db/origin.ex#L19
  @blacklisted_pk <<84, 180, 196, 235, 185, 254, 235, 68, 37, 168, 101, 128, 127, 111, 97, 136,
                    141, 11, 134, 251, 228, 200, 73, 71, 175, 98, 22, 115, 172, 159, 234, 177>>

  @max_chunk_size 100

  @spec reindex_events([tuple()]) :: integer()
  defp reindex_events(records_list) do
    records_list
    |> filter_map_records()
    |> save_records()
  end

  @doc """
  Inserts new :contract_log records for remote call event logs indexing by the called contract create_txi.
  For these new records, the ext_contract field is tagged with {:parent_contract_pk, pubkey} where pubkey
  is the one of the caller contract.
  """
  @spec run(boolean()) :: {:ok, {non_neg_integer(), pos_integer()}}
  def run(_from_startup?) do
    begin = DateTime.utc_now()

    table_size = :mnesia.async_dirty(fn -> Util.count(Model.ContractLog) end)
    Log.info("table size: #{table_size}")
    num_chunks = div(table_size, @max_chunk_size) + 1

    log_spec =
      Ex2ms.fun do
        {:contract_log, _index, ext_contract, _args, _data} = record
        when not is_tuple(ext_contract) and not is_list(ext_contract) ->
          record
      end

    {chunk, select_cont} = Util.select(Model.ContractLog, log_spec, @max_chunk_size)
    insert_count = reindex_events(chunk)

    {_mnesia_cont, reindexed_count} =
      Enum.reduce_while(1..num_chunks, {select_cont, insert_count}, fn _i, {cont, counter} ->
        case Util.select(cont) do
          {chunk, cont} ->
            insert_count = reindex_events(chunk)
            {:cont, {cont, insert_count + counter}}

          :"$end_of_table" ->
            {:halt, {nil, counter}}
        end
      end)

    duration = DateTime.diff(DateTime.utc_now(), begin)
    Log.info("Indexed #{reindexed_count} records in #{duration}s")

    {:ok, {reindexed_count, duration}}
  end

  @spec safe_contract_pk({integer(), any(), any(), any()}) :: binary() | nil
  defp safe_contract_pk({create_txi, _call_txi, _event_hash, _log_idx})
       when is_integer(create_txi) and create_txi > 0,
       do: Origin.pubkey({:contract, create_txi})

  defp safe_contract_pk(_key), do: nil

  @spec safe_contract_txi(binary()) :: integer() | nil
  defp safe_contract_txi(@blacklisted_pk), do: nil
  defp safe_contract_txi(pubkey), do: Origin.tx_index({:contract, pubkey})

  @spec filter_map_records([tuple()]) :: [tuple()]
  defp filter_map_records(record_list) do
    record_list
    |> Enum.filter(fn {_table, index, ext_contract_pk, _args, _data} ->
      contract_pk = safe_contract_pk(index)
      contract_txi = safe_contract_txi(ext_contract_pk)

      is_integer(contract_txi) and
        contract_txi > 0 and
        nil != contract_pk and
        contract_pk != ext_contract_pk
    end)
    |> Enum.map(fn {_table, index, ext_contract_pk, args, data} ->
      contract_pk = safe_contract_pk(index)
      new_create_txi = safe_contract_txi(ext_contract_pk)
      new_index = index |> Tuple.delete_at(0) |> Tuple.insert_at(0, new_create_txi)

      Model.contract_log(
        index: new_index,
        ext_contract: {:parent_contract_pk, contract_pk},
        args: args,
        data: data
      )
    end)
  end

  @spec save_records([tuple()]) :: non_neg_integer()
  defp save_records([]), do: 0

  defp save_records(new_records) do
    :mnesia.sync_dirty(fn ->
      Enum.reduce(new_records, 0, fn log_record, acc ->
        # double check before insert value set after filtering
        {new_create_txi, _call_txi, _event_hash, _log_idx} = elem(log_record, 1)

        # credo:disable-for-next-line
        if is_integer(new_create_txi) and new_create_txi > 0 do
          :ok = Database.write(Model.ContractLog, log_record)
          acc + 1
        else
          acc
        end
      end)
    end)
  end
end
