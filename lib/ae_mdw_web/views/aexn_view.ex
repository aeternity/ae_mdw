defmodule AeMdwWeb.AexnView do
  @moduledoc """
  Renders data for balance(s) endpoints.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util
  alias AeMdw.Node.Db, as: NodeDb
  alias AeMdw.Stats
  alias AeMdw.Aex9
  alias AeMdw.Aex141
  alias AeMdw.Txs

  require Model

  import AeMdw.Util.Encoding
  import AeMdwWeb.Helpers.AexnHelper

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @typep aex9_contract() :: %{
           name: String.t(),
           symbol: String.t(),
           decimals: integer(),
           contract_txi: Txs.txi(),
           contract_id: pubkey(),
           extensions: [String.t()]
         }

  @typep aex141_contract() :: %{
           name: String.t(),
           symbol: String.t(),
           base_url: String.t() | nil,
           contract_txi: Txs.txi(),
           contract_id: pubkey(),
           metadata_type: Model.aex141_metadata_type(),
           extensions: [String.t()]
         }

  @typep aex9_event_balance() :: %{
           contract_id: String.t(),
           account_id: String.t(),
           block_hash: AeMdw.Blocks.block_hash(),
           height: AeMdw.Blocks.height(),
           last_tx_hash: Txs.tx_hash(),
           last_log_idx: AeMdw.Contracts.log_idx(),
           amount: integer()
         }
  @type aexn_contract() :: aex9_contract() | aex141_contract()

  @typep account_transfer_key :: AeMdw.AexnTransfers.transfer_key()
  @typep pair_transfer_key :: AeMdw.AexnTransfers.pair_transfer_key()
  @typep contract_transfer_key :: AeMdw.AexnTransfers.contract_transfer_key()

  @spec balance_to_map(State.t(), {non_neg_integer(), non_neg_integer(), pubkey()}) ::
          map()
  def balance_to_map(state, {amount, call_txi, contract_pk}) do
    Model.tx(id: tx_hash, block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, call_txi)

    {block_hash, tx_type, _signed_tx, _tx_rec} = NodeDb.get_tx_data(tx_hash)

    Model.aexn_contract(meta_info: {name, symbol, _decimals}) =
      State.fetch!(state, Model.AexnContract, {:aex9, contract_pk})

    %{
      contract_id: encode_contract(contract_pk),
      block_hash: encode_block(:micro, block_hash),
      tx_hash: encode(:tx_hash, tx_hash),
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
      contract_id: encode_contract(contract_pk),
      block_hash: encode_block(block_type, block_hash),
      height: height,
      account_id: encode_account(account_pk),
      amount: amount
    }
  end

  @spec balances_to_map(tuple(), pubkey()) :: map()
  def balances_to_map({amounts, {block_type, height, block_hash}}, contract_pk) do
    %{
      contract_id: encode_contract(contract_pk),
      block_hash: encode_block(block_type, block_hash),
      height: height,
      amounts: normalize_balances(amounts)
    }
  end

  @spec render_event_balance(State.t(), {pubkey(), pubkey()} | {pubkey(), integer(), pubkey()}) ::
          aex9_event_balance()
  def render_event_balance(state, {contract_pk, account_pk}) do
    Model.aex9_event_balance(txi: txi, log_idx: log_idx, amount: amount) =
      State.fetch!(state, Model.Aex9EventBalance, {contract_pk, account_pk})

    do_render_event_balance(state, contract_pk, account_pk, txi, log_idx, amount)
  end

  def render_event_balance(state, {contract_pk, amount, account_pk}) do
    Model.aex9_balance_account(txi: txi, log_idx: log_idx) =
      State.fetch!(state, Model.Aex9BalanceAccount, {contract_pk, amount, account_pk})

    do_render_event_balance(state, contract_pk, account_pk, txi, log_idx, amount)
  end

  @spec render_contract(State.t(), Model.aexn_contract()) :: aexn_contract()
  def render_contract(
        state,
        Model.aexn_contract(
          index: {_type, contract_pk},
          txi_idx: {txi, _idx},
          meta_info: {name, symbol, decimals},
          extensions: extensions
        )
      ) do
    initial_supply =
      case State.get(state, Model.Aex9InitialSupply, contract_pk) do
        {:ok, Model.aex9_initial_supply(amount: amount)} -> amount
        :not_found -> 0
      end

    event_supply =
      case State.get(state, Model.Aex9ContractBalance, contract_pk) do
        {:ok, Model.aex9_contract_balance(amount: amount)} -> amount
        :not_found -> 0
      end

    num_holders = Aex9.fetch_holders_count(state, contract_pk)

    %{
      name: name,
      symbol: symbol,
      decimals: decimals,
      contract_txi: txi,
      contract_id: encode_contract(contract_pk),
      extensions: extensions,
      initial_supply: initial_supply,
      event_supply: event_supply,
      holders: num_holders
    }
  end

  def render_contract(
        state,
        Model.aexn_contract(
          index: {_type, contract_pk},
          txi_idx: {txi, _idx},
          meta_info: {name, symbol, base_url, metadata_type},
          extensions: extensions
        )
      ) do
    %{
      name: name,
      symbol: symbol,
      base_url: base_url,
      contract_txi: txi,
      contract_id: encode_contract(contract_pk),
      metadata_type: metadata_type,
      extensions: extensions,
      limits: Aex141.fetch_limits(state, contract_pk)
    }
    |> Map.merge(Stats.fetch_nft_stats(state, contract_pk))
  end

  @spec render_contracts(State.t(), [Model.aexn_contract()]) :: [aexn_contract()]
  def render_contracts(state, aexn_contracts) do
    Enum.map(aexn_contracts, &render_contract(state, &1))
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

  @spec contract_transfer_to_map(
          State.t(),
          Model.aexn_type(),
          :from | :to,
          contract_transfer_key()
        ) ::
          map()
  def contract_transfer_to_map(
        state,
        aexn_type,
        :from,
        {_create_txi, sender_pk, call_txi, recipient_pk, token_id, log_idx}
      ) do
    do_transfer_to_map(state, {aexn_type, sender_pk, call_txi, recipient_pk, token_id, log_idx})
  end

  def contract_transfer_to_map(
        state,
        aexn_type,
        :to,
        {_create_txi, recipient_pk, call_txi, sender_pk, token_id, log_idx}
      ) do
    do_transfer_to_map(state, {aexn_type, sender_pk, call_txi, recipient_pk, token_id, log_idx})
  end

  #
  # Private functions
  #
  defp do_render_event_balance(state, contract_pk, account_pk, txi, log_idx, amount) do
    Model.tx(id: tx_hash, block_index: block_index) = State.fetch!(state, Model.Tx, txi)

    Model.block(index: {height, _mbi}, hash: block_hash) =
      State.fetch!(state, Model.Block, block_index)

    %{
      contract_id: encode_contract(contract_pk),
      account_id: encode_account(account_pk),
      block_hash: encode_block(:micro, block_hash),
      height: height,
      last_tx_hash: encode(:tx_hash, tx_hash),
      last_log_idx: log_idx,
      amount: amount
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
        sender: encode_account(sender_pk),
        recipient: encode_account(recipient_pk),
        call_txi: call_txi,
        log_idx: log_idx,
        block_height: kbi,
        micro_index: mbi,
        micro_time: micro_time,
        contract_id: encode_contract(contract_pk),
        tx_hash: :aeser_api_encoder.encode(:tx_hash, hash)
      },
      aexn_key,
      aexn_value
    )
  end
end
