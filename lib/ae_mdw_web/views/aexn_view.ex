defmodule AeMdwWeb.AexnView do
  @moduledoc """
  Renders data for balance(s) endpoints.
  """

  alias AeMdw.Database
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util

  require Model

  import AeMdwWeb.Helpers.AexnHelper

  @type aexn_token() :: map()

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @typep account_transfer_key :: AeMdw.Aex9.account_transfer_key()
  @typep pair_transfer_key :: AeMdw.Aex9.pair_transfer_key()
  @typep transfer_key_type :: :aex9_transfer | :rev_aex9_transfer | :aex9_pair_transfer

  @spec balance_to_map({non_neg_integer(), non_neg_integer(), pubkey()}) ::
          map()
  def balance_to_map({amount, call_txi, contract_pk}) do
    tx_idx = Util.read_tx!(call_txi)
    info = Format.to_raw_map(tx_idx)

    Model.aexn_contract(meta_info: {name, symbol, _decimals}) =
      Database.fetch!(Model.AexnContract, {:aex9, contract_pk})

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

  @spec render_token(Model.aexn_contract()) :: aexn_token()
  def render_token(
        Model.aexn_contract(
          index: {_type, contract_pk},
          txi: txi,
          meta_info: meta_info
        )
      ) do
    do_render_token(contract_pk, txi, meta_info)
  end

  @spec render_tokens([Model.aexn_contract()]) :: [aexn_token()]
  def render_tokens(aexn_tokens) do
    Enum.map(aexn_tokens, &render_token/1)
  end

  @spec sender_transfer_to_map(account_transfer_key()) :: map()
  def sender_transfer_to_map(key), do: do_transfer_to_map(key)

  @spec recipient_transfer_to_map(account_transfer_key()) :: map()
  def recipient_transfer_to_map({pk1, call_txi, pk2, amount, log_idx}),
    do: do_transfer_to_map({pk2, call_txi, pk1, amount, log_idx})

  @spec pair_transfer_to_map(pair_transfer_key()) :: map()
  def pair_transfer_to_map({pk1, pk2, call_txi, amount, log_idx}),
    do: do_transfer_to_map({pk1, call_txi, pk2, amount, log_idx})

  @spec transfer_to_map(account_transfer_key() | pair_transfer_key(), transfer_key_type()) ::
          map()
  def transfer_to_map({sender_pk, call_txi, recipient_pk, amount, log_idx}, :aex9_transfer),
    do: do_transfer_to_map({sender_pk, call_txi, recipient_pk, amount, log_idx})

  def transfer_to_map({recipient_pk, call_txi, sender_pk, amount, log_idx}, :rev_aex9_transfer),
    do: do_transfer_to_map({sender_pk, call_txi, recipient_pk, amount, log_idx})

  def transfer_to_map({sender_pk, recipient_pk, call_txi, amount, log_idx}, :aex9_pair_transfer),
    do: do_transfer_to_map({sender_pk, call_txi, recipient_pk, amount, log_idx})

  #
  # Private functions
  #
  defp do_render_token(contract_pk, txi, {name, symbol, decimals}) do
    %{
      name: name,
      symbol: symbol,
      decimals: decimals,
      contract_txi: txi,
      contract_id: enc_ct(contract_pk)
    }
  end

  defp do_render_token(contract_pk, txi, {name, symbol, base_url, metadata_type}) do
    %{
      name: name,
      symbol: symbol,
      base_url: base_url,
      contract_txi: txi,
      contract_id: enc_ct(contract_pk),
      metadata_type: metadata_type
    }
  end

  defp do_transfer_to_map({sender_pk, call_txi, recipient_pk, amount, log_idx}) do
    Model.tx(id: hash, block_index: {kbi, mbi}, time: micro_time) = Util.read_tx!(call_txi)
    {_block_hash, type, _signed_tx, tx_rec} = AeMdw.Node.Db.get_tx_data(hash)

    contract_pk =
      if type == :contract_call_tx do
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
