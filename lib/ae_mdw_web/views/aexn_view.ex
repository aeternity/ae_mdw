defmodule AeMdwWeb.AexnView do
  @moduledoc """
  Renders data for balance(s) endpoints.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util
  alias AeMdw.Node.Db, as: NodeDb

  require Model

  import AeMdwWeb.Helpers.AexnHelper

  @type aexn_token() :: map()

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @typep account_transfer_key :: AeMdw.AexnTransfers.transfer_key()
  @typep pair_transfer_key :: AeMdw.AexnTransfers.pair_transfer_key()

  @spec balance_to_map(State.t(), {non_neg_integer(), non_neg_integer(), pubkey()}) ::
          map()
  def balance_to_map(state, {amount, call_txi, contract_pk}) do
    Model.tx(id: tx_hash, block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, call_txi)

    {block_hash, tx_type, _signed_tx, _tx_rec} = NodeDb.get_tx_data(tx_hash)

    Model.aexn_contract(meta_info: {name, symbol, _decimals}) =
      State.fetch!(state, Model.AexnContract, {:aex9, contract_pk})

    %{
      contract_id: enc_ct(contract_pk),
      block_hash: enc_block(:micro, block_hash),
      tx_hash: enc(:tx_hash, tx_hash),
      tx_index: call_txi,
      tx_type: tx_type,
      height: height,
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
          meta_info: meta_info,
          extensions: extensions
        )
      ) do
    do_render_token(contract_pk, txi, meta_info, extensions)
  end

  @spec render_tokens([Model.aexn_contract()]) :: [aexn_token()]
  def render_tokens(aexn_tokens) do
    Enum.map(aexn_tokens, &render_token/1)
  end

  @spec sender_transfer_to_map(State.t(), account_transfer_key()) :: map()
  def sender_transfer_to_map(state, key),
    do: do_transfer_to_map(state, key)

  @spec recipient_transfer_to_map(State.t(), account_transfer_key()) :: map()
  def recipient_transfer_to_map(
        state,
        {type, recipient_pk, call_txi, sender_pk, amount, log_idx}
      ),
      do: do_transfer_to_map(state, {type, sender_pk, call_txi, recipient_pk, amount, log_idx})

  @spec pair_transfer_to_map(State.t(), pair_transfer_key()) :: map()
  def pair_transfer_to_map(state, {type, sender_pk, recipient_pk, call_txi, amount, log_idx}),
    do: do_transfer_to_map(state, {type, sender_pk, call_txi, recipient_pk, amount, log_idx})

  #
  # Private functions
  #
  defp do_render_token(contract_pk, txi, {name, symbol, decimals}, extensions) do
    %{
      name: name,
      symbol: symbol,
      decimals: decimals,
      contract_txi: txi,
      contract_id: enc_ct(contract_pk),
      extensions: extensions
    }
  end

  defp do_render_token(contract_pk, txi, {name, symbol, base_url, metadata_type}, extensions) do
    %{
      name: name,
      symbol: symbol,
      base_url: base_url,
      contract_txi: txi,
      contract_id: enc_ct(contract_pk),
      metadata_type: metadata_type,
      extensions: extensions
    }
  end

  defp do_transfer_to_map(
         state,
         {aexn_type, sender_pk, call_txi, recipient_pk, aexn_value, log_idx} = transfer_key
       ) do
    Model.aexn_transfer(contract_pk: contract_pk) =
      State.fetch!(state, Model.AexnTransfer, transfer_key)

    Model.tx(id: hash, block_index: {kbi, mbi}, time: micro_time) = Util.read_tx!(state, call_txi)
    aexn_key = if aexn_type == :aex9, do: :amount, else: :token_id

    Map.put(
      %{
        sender: enc_id(sender_pk),
        recipient: enc_id(recipient_pk),
        call_txi: call_txi,
        log_idx: log_idx,
        block_height: kbi,
        micro_index: mbi,
        micro_time: micro_time,
        contract_id: enc_ct(contract_pk),
        tx_hash: :aeser_api_encoder.encode(:tx_hash, hash)
      },
      aexn_key,
      aexn_value
    )
  end
end
