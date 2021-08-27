alias AeMdw.Db.Model
alias AeMdw.Db.Util

require Model
require Ex2ms

reindexed? =
  fn ext_contract_pk ->
    is_tuple(ext_contract_pk) and elem(ext_contract_pk, 0) == :parent_contract_pk
  end

log_spec =
  Ex2ms.fun do
    {:contract_log, _index, ext_contract, _args, _data} -> ext_contract
  end

count =
  Model.ContractLog
  |> Util.select(log_spec)
  |> Enum.filter(fn ext_contract_pk -> reindexed?.(ext_contract_pk) end)
  |> Enum.count()

IO.puts "reindexed count: #{count}"
