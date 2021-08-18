defmodule AeMdw.Db.Sync.IntTransfer do
  @fee_kinds [:lock_name, :spend_name, :refund_name, :earn_oracle]

  def block_rewards(key_header, key_hash) do
    all_rewards = calc_block_rewards(key_header, key_hash)
    dev_benefs = Enum.map(:aec_dev_reward.beneficiaries(), &elem(&1, 0))
    AeMdw.Db.IntTransfer.write_block_rewards(all_rewards, dev_benefs, key_header)
  end

  def fee({height, pos_txi}, kind, target, ref_txi, amount) when kind in @fee_kinds,
    do:
      AeMdw.Db.IntTransfer.write(
        {height, pos_txi},
        "fee_" <> to_string(kind),
        target,
        ref_txi,
        amount
      )

  def calc_block_rewards(key_header),
    do: calc_block_rewards(key_header, :aec_headers.hash_header(key_header))

  def calc_block_rewards(key_header, key_hash) do
    delay = :aec_governance.beneficiary_reward_delay()

    {:node, key_header, key_hash, :key}
    |> :aec_chain_state.grant_fees(:aec_trees.new(), delay, false, nil)
    |> :aec_trees.accounts()
    |> :aeu_mtrees.to_list()
    |> Enum.map(fn {pk, ser_account} ->
      {pk, :aec_accounts.balance(:aec_accounts.deserialize(pk, ser_account))}
    end)
  end
end
