defmodule AeMdw.Migrations.ReindexRemoteLogs do
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Util

  require Model
  require Ex2ms

  # single case of pubkey that causes a pk mismatch error:
  # ** (CaseClauseError) no case clause matching: {:contract_create_tx, <<84, 161, 71, 116, 248, 82, 0, 46, 52, 142, 60, 121, 255, 115, 239, 189, 180, 252, 224, 142, 255, 39, 10, 83, 243, 93, 69, 189, 148, 123, 164, 60>>, 22913712}
  # https://github.com/aeternity/ae_mdw/blob/0854208fbc932f6214b7378b29b23bd1021be1b3/lib/ae_mdw/db/origin.ex#L19
  @blacklisted_pk <<84, 180, 196, 235, 185, 254, 235, 68, 37, 168, 101, 128, 127, 111, 97, 136,
                    141, 11, 134, 251, 228, 200, 73, 71, 175, 98, 22, 115, 172, 159, 234, 177>>

  defp safe_contract_pk({create_txi, _, _, _}) when is_integer(create_txi) and create_txi > 0,
    do: Origin.pubkey({:contract, create_txi})

  defp safe_contract_pk(_), do: nil

  defp safe_contract_txi(@blacklisted_pk), do: nil
  defp safe_contract_txi(pubkey), do: Origin.tx_index({:contract, pubkey})

  def run() do
    reindex_events = fn record_list ->
      new_records =
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

      result =
        :mnesia.sync_transaction(fn ->
          Enum.reduce(new_records, 0, fn log_record, acc ->
            # double check before insert
            {new_create_txi, _, _, _} = elem(log_record, 1)

            if is_integer(new_create_txi) and new_create_txi > 0 do
              :ok = :mnesia.write(Model.ContractLog, log_record, :write)
              acc + 1
            else
              acc
            end
          end)
        end)

      case result do
        {:atomic, count} -> count
        _ -> 0
      end
    end

    begin = DateTime.utc_now()

    log_spec =
      Ex2ms.fun do
        {:contract_log, _index, ext_contract, _args, _data} = record
        when not is_tuple(ext_contract) ->
          record
      end

    {:atomic, count} = :mnesia.transaction(fn -> Util.count(Model.ContractLog) end)
    IO.puts("table size: #{count}")
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

          :"$end_of_table" ->
            {:halt, {nil, insert_count}}
        end
      end)

    duration = DateTime.diff(DateTime.utc_now(), begin)
    IO.puts("Indexed #{reindexed_count} records in #{duration}s")

    {reindexed_count, duration}
  end
end
