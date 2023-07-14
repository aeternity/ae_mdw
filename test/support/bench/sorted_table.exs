alias AeMdw.Util.GbTree
alias AeMdw.Util.SortedTable
alias AeMdw.Db.Model

require Model

log_records = fn i, log_idx ->
  create_txi = 700_000
  txi = create_txi + i
  evt_hash = <<i::256>>

  m_log =
    Model.contract_log(
      index: {create_txi, txi, log_idx},
      ext_contract: <<1::256>>,
      args: [<<1::256>>, <<2::256>>, <<3::256>>],
      data: "",
      hash: evt_hash
    )

  m_data_log = Model.data_contract_log(index: {"", txi, create_txi, log_idx})
  m_evt_log = Model.evt_contract_log(index: {evt_hash, txi, create_txi, log_idx})
  m_ctevt_log = Model.ctevt_contract_log(index: {evt_hash, create_txi, txi, log_idx})
  m_idx_log = Model.idx_contract_log(index: {txi, log_idx, create_txi})

  [m_log, m_data_log, m_evt_log, m_ctevt_log, m_idx_log]
end

records = Enum.flat_map(1..10_000, fn i -> log_records.(i, 0) ++ log_records.(i, 1) end)

Benchee.run(%{
  "GbTree" => fn ->
    tables =
      Map.new(
        [
          :contract_log,
          :data_contract_log,
          :evt_contract_log,
          :ctevt_contract_log,
          :idx_contract_log
        ],
        fn name ->
          {name, GbTree.new()}
        end
      )

    Enum.reduce(records, tables, fn rec, tables ->
      table_name = elem(rec, 0)
      gbt = Map.get(tables, table_name)
      Map.put(tables, table_name, GbTree.insert(gbt, elem(rec, 1), Tuple.delete_at(rec, 0)))
    end)
  end,
  "SortedTable" => fn ->
    tables =
      Map.new(
        [
          :contract_log,
          :data_contract_log,
          :evt_contract_log,
          :ctevt_contract_log,
          :idx_contract_log
        ],
        fn name ->
          {name, SortedTable.new()}
        end
      )

    Enum.reduce(records, tables, fn rec, tables ->
      table_name = elem(rec, 0)
      table = Map.get(tables, table_name)

      Map.put(
        tables,
        table_name,
        SortedTable.insert(table, elem(rec, 1), Tuple.delete_at(rec, 0))
      )
    end)
  end
})
