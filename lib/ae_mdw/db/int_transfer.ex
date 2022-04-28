defmodule AeMdw.Db.IntTransfer do
  @moduledoc """
  Writes internal transfers to the database.
  """

  alias AeMdw.Blocks
  alias AeMdw.Txs
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Database
  alias AeMdw.Collection

  require Ex2ms
  require Model

  alias AeMdw.Db.BlockRewardsMutation
  alias AeMdw.Node.Db

  # @type kind() :: "fee_lock_name" | "fee_refund_name" | "fee_spend_name" |
  #                 "reward_block" | "reward_dev" | "reward_oracle
  @type kind() :: binary()
  @type target() :: Db.pubkey()
  @type ref_txi() :: Txs.txi() | -1
  @type amount() :: pos_integer()

  @typep kind_suffix() :: :lock_name | :spend_name | :refund_name | :earn_oracle

  @fee_kinds [:lock_name, :spend_name, :refund_name, :earn_oracle]

  @reward_block_kind "reward_block"
  @reward_dev_kind "reward_dev"

  @spec block_rewards_mutation(Blocks.height(), Blocks.key_header(), Blocks.block_hash()) ::
          BlockRewardsMutation.t()
  def block_rewards_mutation(height, key_header, key_hash) do
    delay = :aec_governance.beneficiary_reward_delay()
    dev_benefs = Enum.map(:aec_dev_reward.beneficiaries(), &elem(&1, 0))

    block_rewards =
      {:node, key_header, key_hash, :key}
      |> :aec_chain_state.grant_fees(:aec_trees.new(), delay, false, nil)
      |> :aec_trees.accounts()
      |> :aeu_mtrees.to_list()
      |> Enum.map(fn {target_pk, ser_account} ->
        amount = :aec_accounts.balance(:aec_accounts.deserialize(target_pk, ser_account))

        kind = (target_pk in dev_benefs && @reward_dev_kind) || @reward_block_kind

        {kind, target_pk, amount}
      end)

    BlockRewardsMutation.new(height, block_rewards)
  end

  @spec fee(
          State.t(),
          Blocks.block_index_txi_pos(),
          kind_suffix(),
          target(),
          ref_txi(),
          amount()
        ) :: State.t()
  def fee(state, {height, txi_pos}, kind, target, ref_txi, amount) when kind in @fee_kinds do
    write(
      state,
      {height, txi_pos},
      "fee_" <> to_string(kind),
      target,
      ref_txi,
      amount
    )
  end

  @spec write(
          State.t(),
          Blocks.block_index_txi_pos(),
          kind(),
          target(),
          ref_txi(),
          amount()
        ) :: State.t()
  def write(state, {height, pos_txi}, kind, target_pk, ref_txi, amount) do
    int_tx =
      Model.int_transfer_tx(index: {{height, pos_txi}, kind, target_pk, ref_txi}, amount: amount)

    kind_tx = Model.kind_int_transfer_tx(index: {kind, {height, pos_txi}, target_pk, ref_txi})

    target_kind_tx =
      Model.target_kind_int_transfer_tx(index: {target_pk, kind, {height, pos_txi}, ref_txi})

    state
    |> State.put(Model.IntTransferTx, int_tx)
    |> State.put(Model.KindIntTransferTx, kind_tx)
    |> State.put(Model.TargetKindIntTransferTx, target_kind_tx)
  end

  @spec read_block_reward(State.t(), Blocks.height()) :: pos_integer()
  def read_block_reward(state, height) do
    sum_reward_amount(state, height, @reward_block_kind)
  end

  @spec read_dev_reward(State.t(), Blocks.height()) :: pos_integer()
  def read_dev_reward(state, height) do
    sum_reward_amount(state, height, @reward_dev_kind)
  end

  defp sum_reward_amount(state, height, kind) do
    height_pos = {height, -1}

    state
    |> Collection.stream(Model.IntTransferTx, {height_pos, kind, <<>>, -1})
    |> Stream.take_while(fn
      {^height_pos, ^kind, _target, _ref} -> true
      _other_height_kind -> false
    end)
    |> Enum.map(fn key ->
      Model.int_transfer_tx(amount: amount) = Database.fetch!(Model.IntTransferTx, key)
      amount
    end)
    |> Enum.sum()
  end
end
