defmodule AeMdw.Db.Sync.Contract do
  alias AeMdw.Contract
  alias AeMdw.Db
  alias AeMdw.Db.Contract, as: DBContract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util, as: DBU

  require Model

  @migrate_contract_pk <<84, 180, 196, 235, 185, 254, 235, 68, 37, 168, 101, 128, 127, 111, 97,
                         136, 141, 11, 134, 251, 228, 200, 73, 71, 175, 98, 22, 115, 172, 159,
                         234, 177>>

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

  def call(contract_pk, tx, txi, bi) do
    block_hash = Model.block(DBU.read_block!(bi), :hash)

    create_txi =
      (contract_pk == @migrate_contract_pk &&
         -1) || Db.Origin.tx_index({:contract, contract_pk})

    {fun_arg_res, call_rec} =
      Contract.call_tx_info(tx, contract_pk, block_hash, &Contract.to_map/1)

    DBContract.call_write(create_txi, txi, fun_arg_res)
    DBContract.logs_write(create_txi, txi, call_rec)
  end

  def migrate_contract_pk(),
    do: @migrate_contract_pk
end
