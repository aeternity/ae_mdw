defmodule AeMdw.Db.Sync.IdCounter do
  @moduledoc """
  Counts the ocurrences of blockchain ids/pubkeys.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Db.State

  require Model

  @typep pubkey() :: Db.pubkey()

  @spec incr_count(State.t(), Node.tx_type(), non_neg_integer(), pubkey(), boolean()) :: State.t()
  def incr_count(state, tx_type, pos, pk, is_repeated?) do
    state = incr_id_count(state, Model.IdCount, {tx_type, pos, pk})

    if is_repeated? do
      incr_id_count(state, Model.DupIdCount, {tx_type, pos, pk})
    else
      state
    end
  end

  defp incr_id_count(state, table, field_key) do
    State.update(
      state,
      table,
      field_key,
      fn
        Model.id_count(count: count) = id_count -> Model.id_count(id_count, count: count + 1)
      end,
      Model.id_count(index: field_key, count: 0)
    )
  end

  def incr_account_tx_count(state, account_pk) do
    State.update(
      state,
      Model.AccountCounter,
      account_pk,
      fn
        Model.account_counter(txs: txs) = account_counter ->
          Model.account_counter(account_counter, txs: txs + 1)
      end,
      Model.account_counter(index: account_pk, txs: 0)
    )
  end

  def incr_account_activities_count(state, account_pk) do
    State.update(
      state,
      Model.AccountCounter,
      account_pk,
      fn
        Model.account_counter(activities: activities) = account_counter ->
          Model.account_counter(account_counter, activities: activities + 1)
      end,
      Model.account_counter(index: account_pk)
    )
  end

  def incr_account_aex9_count(state, account_pk) do
    State.update(
      state,
      Model.AccountCounter,
      account_pk,
      fn
        Model.account_counter(aex9: aex9, tokens: tokens) =
            account_counter ->
          Model.account_counter(account_counter,
            aex9: aex9 + 1,
            tokens: tokens + 1
          )
      end,
      Model.account_counter(index: account_pk)
    )
  end

  def decr_account_aex9_count(state, account_pk) do
    State.update(
      state,
      Model.AccountCounter,
      account_pk,
      fn
        Model.account_counter(aex9: aex9, tokens: tokens) =
            account_counter ->
          Model.account_counter(account_counter,
            aex9: aex9 - 1,
            tokens: tokens - 1
          )
      end,
      Model.account_counter(index: account_pk)
    )
  end

  def incr_account_aex9_with_activities_count(state, account_pk) do
    State.update(
      state,
      Model.AccountCounter,
      account_pk,
      fn
        Model.account_counter(aex9: aex9, activities: activities, tokens: tokens) =
            account_counter ->
          Model.account_counter(account_counter,
            aex9: aex9 + 1,
            activities: activities + 1,
            tokens: tokens + 1
          )
      end,
      Model.account_counter(index: account_pk)
    )
  end

  def decr_account_aex9_with_activities_count(state, account_pk) do
    State.update(
      state,
      Model.AccountCounter,
      account_pk,
      fn
        Model.account_counter(aex9: aex9, activities: activities, tokens: tokens) =
            account_counter ->
          Model.account_counter(account_counter,
            aex9: aex9 - 1,
            tokens: tokens - 1,
            activities: activities + 1
          )
      end,
      Model.account_counter(index: account_pk)
    )
  end

  # def incr_account_aex141_count(state, account_pk) do
  #   State.update(
  #     state,
  #     Model.AccountCounter,
  #     account_pk,
  #     fn
  #       Model.account_counter(aex141: aex141, tokens: tokens) =
  #           account_counter ->
  #         Model.account_counter(account_counter,
  #           aex141: aex141 + 1,
  #           tokens: tokens + 1
  #         )
  #     end,
  #     Model.account_counter(index: account_pk)
  #   )
  # end

  # def decr_account_aex141_count(state, account_pk) do
  #   State.update(
  #     state,
  #     Model.AccountCounter,
  #     account_pk,
  #     fn
  #       Model.account_counter(aex141: aex141, tokens: tokens) =
  #           account_counter ->
  #         Model.account_counter(account_counter,
  #           aex141: aex141 - 1,
  #           tokens: tokens - 1
  #         )
  #     end,
  #     Model.account_counter(index: account_pk)
  #   )
  # end

  def incr_account_aex141_with_activities_count(state, account_pk) do
    State.update(
      state,
      Model.AccountCounter,
      account_pk,
      fn
        Model.account_counter(aex141: aex141, activities: activities, tokens: tokens) =
            account_counter ->
          Model.account_counter(account_counter,
            aex141: aex141 + 1,
            activities: activities + 1,
            tokens: tokens + 1
          )
      end,
      Model.account_counter(index: account_pk)
    )
  end

  def decr_account_aex141_with_activities_count(state, account_pk) do
    State.update(
      state,
      Model.AccountCounter,
      account_pk,
      fn
        Model.account_counter(aex141: aex141, activities: activities, tokens: tokens) =
            account_counter ->
          Model.account_counter(account_counter,
            aex141: aex141 - 1,
            tokens: tokens - 1,
            activities: activities + 1
          )
      end,
      Model.account_counter(index: account_pk)
    )
  end
end
