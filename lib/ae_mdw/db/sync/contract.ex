defmodule AeMdw.Db.Sync.Contract do
  alias AeMdw.Contract
  # alias AeMdw.Db
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.Model
  # alias AeMdw.Db.Util, as: DBU

  require Model

  ##########

  def create(contract_pk, txi, _bi) do
    contract_info = Contract.get_info(contract_pk)

    case Contract.is_aex9?(contract_info) do
      true ->
        meta_info = Contract.aex9_meta_info(contract_pk)
        DBContract.aex9_creation_write(meta_info, contract_pk, txi)

      false ->
        :ok
    end
  end

  # def call(contract_pk, tx, txi, bi) do
  #   block_hash = Model.block(DBU.read_block!(bi), :hash)
  #   create_txi = Db.Origin.tx_index({:contract, contract_pk})
  #   {%{function: fname, arguments: args, result: result}, call_rec} =
  #     Contract.call_tx_info(tx, contract_pk, block_hash, &Contract.to_map/1)
  #   DBContract.call_write(create_txi, txi, fname, args, result)
  #   DBContract.logs_write(create_txi, txi, call_rec)
  # end
end
