defmodule AeMdwWeb.Views.Aex9ControllerView do
  @moduledoc """
  Renders data for balance(s) endpoints.
  """

  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util

  require Model

  import AeMdwWeb.Helpers.Aex9Helper

  @typep pubkey() :: <<_::256>>

  @spec balance_to_map({non_neg_integer(), non_neg_integer(), non_neg_integer(), pubkey()}) ::
          map()
  def balance_to_map({amount, create_txi, call_txi, contract_pk}) do
    tx_idx = Util.read_tx!(call_txi)
    info = Format.to_raw_map(tx_idx)

    {^create_txi, name, symbol, _decimals} =
      Util.next(Model.RevAex9Contract, {create_txi, nil, nil, nil})

    %{
      contract_id: enc_ct(contract_pk),
      block_hash: enc_block(:micro, info.block_hash),
      tx_hash: enc(:tx_hash, info.hash),
      tx_index: call_txi,
      tx_type: info.tx.type,
      height: info.block_height,
      amount: amount,
      token_symbol: symbol,
      token_name: name
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
    Model.tx(id: hash, block_index: {kbi, mbi}, time: micro_time) = Util.read_tx!(call_txi)
    {_block_hash, _type, _signed_tx, tx_rec} = AeMdw.Node.Db.get_tx_data(hash)

    contract_pk =
      if elem(tx_rec, 0) == :contract_call_tx do
        :aect_call_tx.contract_pubkey(tx_rec)
      else
        :aect_create_tx.contract_pubkey(tx_rec)
      end

    %{
      sender: enc_id(sender_pk),
      recipient: enc_id(recipient_pk),
      amount: amount,
      call_txi: call_txi,
      log_idx: log_idx,
      block_height: kbi,
      micro_index: mbi,
      micro_time: micro_time,
      contract_id: enc_ct(contract_pk)
    }
  end
end
