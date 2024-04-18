defmodule AeMdw.Db.IntTransfer do
  @moduledoc """
  Writes internal transfers to the database.
  """

  alias AeMdw.Blocks
  alias AeMdw.Txs
  alias AeMdw.Db.Model
  alias AeMdw.Db.MinerRewardsMutation
  alias AeMdw.Db.Mutation
  alias AeMdw.Db.State
  alias AeMdw.Collection

  require Ex2ms
  require Model

  alias AeMdw.Db.IntTransfersMutation
  alias AeMdw.Node.Db

  # @type kind() :: "fee_lock_name" | "fee_refund_name" | "fee_spend_name" | "fee_refund_oracle"
  #                 "reward_block" | "reward_dev" | "reward_oracle"
  @type kind() :: binary()
  @type target() :: Db.pubkey()
  @type amount() :: pos_integer()
  @type rewards() :: [{target(), amount()}]

  @typep optional_txi_idx() :: Txs.optional_txi_idx()
  @typep height_optional_txi_idx() :: {Blocks.height(), optional_txi_idx()}
  @typep kind_suffix() :: :lock_name | :spend_name | :refund_name | :earn_oracle | :refund_oracle
  @opaque key_block() :: tuple()

  @fee_kinds [:lock_name, :spend_name, :refund_name, :earn_oracle, :refund_oracle]

  @reward_block_kind "reward_block"
  @reward_dev_kind "reward_dev"

  @spec block_rewards_mutations(key_block()) :: [
          Mutation.t()
        ]
  def block_rewards_mutations(key_block) do
    height = :aec_blocks.height(key_block)
    delay = :aec_governance.beneficiary_reward_delay()

    dev_benefs =
      for {protocol, _height} <- :aec_hard_forks.protocols(),
          {pk, _share} <- :aec_dev_reward.beneficiaries(protocol) do
        pk
      end

    {devs_rewards, miners_rewards} =
      key_block
      |> :aec_chain_state.wrap_block()
      |> :aec_chain_state.grant_fees(:aec_trees.new(), delay, false, nil)
      |> :aec_trees.accounts()
      |> :aeu_mtrees.to_list()
      |> Enum.map(fn {target_pk, ser_account} ->
        amount = :aec_accounts.balance(:aec_accounts.deserialize(target_pk, ser_account))

        {target_pk, amount}
      end)
      |> Enum.split_with(fn {target_pk, _amount} -> target_pk in dev_benefs end)

    miners_transfers =
      Enum.map(miners_rewards, fn {target_pk, amount} ->
        {@reward_block_kind, target_pk, amount}
      end)

    devs_transfers =
      Enum.map(devs_rewards, fn {target_pk, amount} ->
        {@reward_dev_kind, target_pk, amount}
      end)

    [
      IntTransfersMutation.new(height, miners_transfers ++ devs_transfers),
      MinerRewardsMutation.new(miners_rewards)
    ]
  end

  @spec fee(
          State.t(),
          height_optional_txi_idx(),
          kind_suffix(),
          target(),
          optional_txi_idx(),
          amount()
        ) :: State.t()
  def fee(state, {height, opt_txi_idx}, kind, target, ref_txi_idx, amount)
      when kind in @fee_kinds do
    write(
      state,
      {height, opt_txi_idx},
      "fee_" <> to_string(kind),
      target,
      ref_txi_idx,
      amount
    )
  end

  @spec write(
          State.t(),
          height_optional_txi_idx(),
          kind(),
          target(),
          optional_txi_idx(),
          amount()
        ) :: State.t()
  def write(state, {height, opt_txi_idx}, kind, target_pk, ref_txi_idx, amount) do
    int_tx =
      Model.int_transfer_tx(
        index: {{height, opt_txi_idx}, kind, target_pk, ref_txi_idx},
        amount: amount
      )

    kind_tx =
      Model.kind_int_transfer_tx(index: {kind, {height, opt_txi_idx}, target_pk, ref_txi_idx})

    target_kind_tx =
      Model.target_kind_int_transfer_tx(
        index: {target_pk, kind, {height, opt_txi_idx}, ref_txi_idx}
      )

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
      Model.int_transfer_tx(amount: amount) = State.fetch!(state, Model.IntTransferTx, key)
      amount
    end)
    |> Enum.sum()
  end
end
