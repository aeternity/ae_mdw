alias AeMdw.Db.Model
alias AeMdw.Db.Origin
alias AeMdw.Db.Util

require Model
require Ex2ms

safe_contract_pk = fn {create_txi, _, _, _} -> try do Origin.pubkey({:contract, create_txi}) rescue _e -> nil end end

reindex_events = fn record_list ->
  new_records =
    record_list
    |> Enum.filter(fn {_table, index, ext_contract_pk, _args, _data} ->
      contract_pk = safe_contract_pk.(index)
      nil != contract_pk and contract_pk != ext_contract_pk and not is_tuple(ext_contract_pk)
    end)
    |> Enum.map(fn {_table, index, ext_contract_pk, args, data} ->
      contract_pk = safe_contract_pk.(index)
      new_create_txi = Origin.tx_index({:contract, ext_contract_pk})
      new_index = index |> Tuple.delete_at(0) |> Tuple.insert_at(0, new_create_txi)
      Model.contract_log(
        index: new_index,
        ext_contract: {:parent_contract_pk, contract_pk},
        args: args,
        data: data
      )
    end)

  result = :mnesia.transaction(fn ->
    Enum.each(fn log_record -> :mnesia.write(Model.ContractLog, log_record, :write) end)
  end)

  case result do
    {:atomic, :ok} -> length(new_records)
    _ -> 0
  end
end

begin = DateTime.utc_now()

log_spec =
  Ex2ms.fun do
    {:contract_log, _index, _ext_contract, _args, _data} = record -> record
  end

{:atomic, count} = :mnesia.transaction(fn -> Util.count(Model.ContractLog) end)
IO.inspect "count: #{count}"
max_chunk_size = 100
num_chunks = div(count, max_chunk_size)

{chunk, initial_cont} = Util.select(Model.ContractLog, log_spec, max_chunk_size)
insert_count = reindex_events.(chunk)

{_, reindexed_count} =
  Enum.reduce_while(1..num_chunks, {initial_cont, insert_count}, fn _i, {cont, counter} ->
    case Util.select(cont) do
      {chunk, cont} ->
        insert_count = reindex_events.(chunk)
        {:cont, {cont, insert_count + counter}}
      :'$end_of_table' ->
        {:halt, {nil, insert_count}}
    end
  end)

IO.inspect "reindexed count: #{reindexed_count}"
IO.inspect "duration: #{DateTime.diff(DateTime.utc_now(), begin)}s"
