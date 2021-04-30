defmodule AeMdw.Db.IntTransfer do
  alias AeMdw.Db.Model

  require Model

  ##########
  
  def write_block_rewards(all_rewards, dev_benefs, key_header) do
    height = :aec_headers.height(key_header)
    for {target_pk, amount} <- all_rewards do
      kind = target_pk in dev_benefs && "reward_dev" || "reward_block"
      write({height, -1}, kind, target_pk, -1, amount)
      AeMdw.Ets.inc(:stat_sync_cache, kind == "reward_dev" && :dev_reward || :block_reward, amount)
    end
  end

  def write({height, pos_txi}, kind, target_pk, ref_txi, amount) do
    int_tx = Model.int_transfer_tx(index: {{height, pos_txi}, kind, target_pk, ref_txi}, amount: amount)
    kind_tx = Model.kind_int_transfer_tx(index: {kind, {height, pos_txi}, target_pk, ref_txi})
    target_tx = Model.target_int_transfer_tx(index: {target_pk, {height, pos_txi}, kind, ref_txi})
    :mnesia.write(Model.IntTransferTx, int_tx, :write)
    :mnesia.write(Model.KindIntTransferTx, kind_tx, :write)
    :mnesia.write(Model.TargetIntTransferTx, target_tx, :write)
  end
    
end
