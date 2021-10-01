defmodule AeMdwWeb.Views.Aex9ControllerView do
  @moduledoc """
  Renders data for balance(s) endpoints.
  """

  alias AeMdw.Db.Format
  alias AeMdw.Db.Util

  import AeMdwWeb.Helpers.Aex9Helper

  @typep pubkey() :: <<_::256>>

  @spec balance_to_map({integer(), integer(), pubkey()}) :: map()
  def balance_to_map({amount, -1, contract_pk}) do
    %{
      contract_id: enc_ct(contract_pk),
      amount: amount
    }
  end

  def balance_to_map({amount, txi, contract_pk}) do
    tx_idx = Util.read_tx!(txi)
    info = Format.to_raw_map(tx_idx)

    %{
      contract_id: enc_ct(contract_pk),
      block_hash: enc_block(:micro, info.block_hash),
      tx_hash: enc(:tx_hash, info.hash),
      tx_index: txi,
      tx_type: info.tx.type,
      height: info.block_height,
      amount: amount
    }
  end

  @spec balance_to_map(tuple(), pubkey(), pubkey()) :: map()
  def balance_to_map({amount, {block_type, height, block_hash}}, contract_pk, account_pk) do
    %{
      contract_id: enc_ct(contract_pk),
      block_hash: enc_block(block_type, block_hash),
      height: height,
      account_id: enc_id(account_pk),
      amount: amount
    }
  end

  @spec balances_to_map(tuple(), pubkey()) :: map()
  def balances_to_map({amounts, {block_type, height, block_hash}}, contract_pk) do
    %{
      contract_id: enc_ct(contract_pk),
      block_hash: enc_block(block_type, block_hash),
      height: height,
      amounts: normalize_balances(amounts)
    }
  end

  @spec transfer_to_map(tuple(), atom()) :: map()
  def transfer_to_map({recipient_pk, sender_pk, amount, call_txi, log_idx}, :rev_aex9_transfer),
    do: transfer_to_map({sender_pk, recipient_pk, amount, call_txi, log_idx}, :aex9_transfer)

  def transfer_to_map({sender_pk, recipient_pk, amount, call_txi, log_idx}, :aex9_transfer) do
    tx = call_txi |> Util.read_tx!() |> Format.to_map()

    %{
      sender: enc_id(sender_pk),
      recipient: enc_id(recipient_pk),
      amount: amount,
      call_txi: call_txi,
      log_idx: log_idx,
      block_height: tx["block_height"],
      micro_time: tx["micro_time"],
      contract_id: tx["tx"]["contract_id"]
    }
  end
end
