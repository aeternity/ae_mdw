defmodule AeMdw.Db.Sync.Contract do
  alias AeMdw.Contract
  alias AeMdw.Db.Model

  require Record
  require Model

  ##########

  def create(pubkey, txi) do
    contract_info = Contract.get_info(pubkey)

    case Contract.is_aex9?(contract_info) do
      true ->
        {name, symbol, decimals} = Contract.aex9_meta_info(pubkey)
        aex9_contract = Model.aex9_contract(index: {name, symbol, txi, decimals})
        aex9_contract_sym = Model.aex9_contract_symbol(index: {symbol, name, txi, decimals})
        rev_aex9_contract = Model.rev_aex9_contract(index: {txi, name, symbol, decimals})
        :mnesia.write(Model.Aex9Contract, aex9_contract, :write)
        :mnesia.write(Model.Aex9ContractSymbol, aex9_contract_sym, :write)
        :mnesia.write(Model.RevAex9Contract, rev_aex9_contract, :write)

      false ->
        :ok
    end
  end


end
