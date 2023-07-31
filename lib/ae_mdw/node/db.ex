defmodule AeMdw.Node.Db do
  @moduledoc false

  alias AeMdw.Blocks
  alias AeMdw.DryRun.Runner
  alias AeMdw.Db.Model
  alias AeMdw.Log
  alias AeMdw.Node

  import AeMdw.Util

  require Logger
  require Model

  @type pubkey() :: <<_::256>>
  @type hash_type() :: :key | :micro
  @type hash() :: <<_::256>>
  @type height_hash() :: {hash_type(), pos_integer(), binary()}
  @type balances_map() :: %{{:address, pubkey()} => integer()}
  @type account_balance() :: {integer() | nil, height_hash()}
  @opaque key_block() :: tuple()
  @opaque micro_block() :: tuple()
  @opaque id() :: tuple()

  @spec get_blocks(Blocks.block_hash(), Blocks.block_hash()) :: {key_block(), [micro_block()]}
  def get_blocks(kb_hash, next_kb_hash) do
    {:aec_db.get_block(kb_hash), get_micro_blocks(next_kb_hash)}
  end

  @spec get_blocks_per_height(Blocks.height(), Blocks.block_hash() | Blocks.height()) :: [
          {Blocks.height(), [micro_block()], Blocks.block_hash() | nil}
        ]
  def get_blocks_per_height(from_height, block_hash) when is_binary(block_hash),
    do: get_blocks_per_height(from_height, block_hash, nil)

  def get_blocks_per_height(from_height, to_height) when is_integer(to_height) do
    {:ok, header} = :aec_chain.get_key_header_by_height(to_height + 1)

    last_mb_hash = :aec_headers.prev_hash(header)
    {:ok, last_kb_hash} = :aec_headers.hash_header(header)

    get_blocks_per_height(from_height, last_mb_hash, last_kb_hash)
  end

  defp get_blocks_per_height(from_height, last_mb_hash, last_kb_hash) do
    {:ok, root_hash} =
      :aec_chain.genesis_block()
      |> :aec_blocks.to_header()
      |> :aec_headers.hash_header()

    {last_mb_hash, last_kb_hash}
    |> Stream.unfold(fn
      {_last_mb_hash, ^root_hash} ->
        nil

      {last_mb_hash, last_kb_hash} ->
        {key_block, micro_blocks} = get_kb_mbs(last_mb_hash)

        prev_hash = :aec_blocks.prev_hash(key_block)
        key_header = :aec_blocks.to_header(key_block)
        {:ok, key_hash} = :aec_headers.hash_header(key_header)

        {{key_block, micro_blocks, last_kb_hash}, {prev_hash, key_hash}}
    end)
    |> Enum.take_while(fn {key_block, _micro_blocks, _last_kb_hash} ->
      :aec_blocks.height(key_block) >= from_height
    end)
    |> Enum.reverse()
  end

  defp get_kb_mbs(last_mb_hash) do
    last_mb_hash
    |> Stream.unfold(fn block_hash ->
      block = :aec_db.get_block(block_hash)

      {block, :aec_blocks.prev_hash(block)}
    end)
    |> Enum.reduce_while([], fn block, micro_blocks ->
      case :aec_blocks.type(block) do
        :micro -> {:cont, [block | micro_blocks]}
        :key -> {:halt, {block, micro_blocks}}
      end
    end)
  end

  @spec get_micro_blocks(Blocks.block_hash()) :: [micro_block()]
  def get_micro_blocks(next_block_hash),
    do: next_block_hash |> get_reverse_micro_blocks() |> Enum.reverse()

  @spec get_reverse_micro_blocks(Blocks.block_hash()) :: Enumerable.t()
  def get_reverse_micro_blocks(next_block_hash) do
    next_block_hash
    |> :aec_db.get_header()
    |> :aec_headers.prev_hash()
    |> Stream.unfold(&micro_block_walker/1)
  end

  @spec get_key_block_hash(Blocks.height()) :: Blocks.block_hash() | nil
  def get_key_block_hash(height) do
    with {:ok, next_kb_header} <- :aec_chain.get_key_header_by_height(height),
         {:ok, next_kb_hash} <- :aec_headers.hash_header(next_kb_header) do
      next_kb_hash
    else
      {:error, :chain_too_short} -> nil
    end
  end

  @spec get_next_hash(Blocks.block_hash(), Blocks.mbi()) :: Blocks.block_hash()
  def get_next_hash(next_kb_hash, mbi) do
    next_kb_hash
    |> get_micro_blocks()
    |> Enum.reduce_while(0, fn mblock, index ->
      if index == mbi + 1 do
        ok_mb_hash =
          mblock
          |> :aec_blocks.to_micro_header()
          |> :aec_headers.hash_header()

        {:halt, ok_mb_hash}
      else
        {:cont, index + 1}
      end
    end)
    |> case do
      {:ok, mb_hash} -> mb_hash
      _mb_count -> next_kb_hash
    end
  end

  @spec get_tx_data(binary()) ::
          {Blocks.block_hash(), Node.tx_type(), Node.signed_tx(), Node.tx()}
  def get_tx_data(<<_pk::256>> = tx_hash) do
    {block_hash, signed_tx} = :aec_db.find_tx_with_location(tx_hash)
    {type, tx_rec} = :aetx.specialize_type(:aetx_sign.tx(signed_tx))
    {block_hash, type, signed_tx, tx_rec}
  end

  @spec get_tx(binary()) :: Node.tx()
  def get_tx(<<_pk::256>> = tx_hash) do
    {_block_hash, signed_tx} = :aec_db.find_tx_with_location(tx_hash)
    {_type, tx_rec} = :aetx.specialize_type(:aetx_sign.tx(signed_tx))
    tx_rec
  end

  @spec get_signed_tx(binary()) :: tuple()
  def get_signed_tx(<<_pk::256>> = tx_hash) do
    {_block_hash, signed_tx} = :aec_db.find_tx_with_location(tx_hash)
    signed_tx
  end

  @spec top_height_hash(boolean()) :: height_hash()
  def top_height_hash(false = _the_very_top?) do
    block = :aec_chain.top_key_block() |> ok!
    header = :aec_blocks.to_key_header(block)
    {:key, :aec_headers.height(header), ok!(:aec_headers.hash_header(header))}
  end

  def top_height_hash(true = _the_very_top?) do
    {type, header} =
      case :aec_chain.top_block() do
        {:mic_block, header, _txs, _pof} -> {:micro, header}
        {:key_block, header} -> {:key, header}
      end

    {type, :aec_headers.height(header), ok!(:aec_headers.hash_header(header))}
  end

  @spec aex9_balance(pubkey(), pubkey()) ::
          {:ok, account_balance()} | {:error, Runner.call_error()}
  def aex9_balance(contract_pk, account_pk),
    do: aex9_balance(contract_pk, account_pk, false)

  @spec aex9_balance(pubkey(), pubkey(), nil | boolean()) ::
          {:ok, account_balance()} | {:error, Runner.call_error()}
  def aex9_balance(contract_pk, account_pk, nil), do: aex9_balance(contract_pk, account_pk, false)

  def aex9_balance(contract_pk, account_pk, the_very_top?) when is_boolean(the_very_top?),
    do: aex9_balance(contract_pk, account_pk, top_height_hash(the_very_top?))

  @spec aex9_balance(pubkey(), pubkey(), height_hash()) ::
          {:ok, account_balance()} | {:error, Runner.call_error()}
  def aex9_balance(contract_pk, account_pk, {type, height, hash}) do
    case Runner.call_contract(contract_pk, {type, height, hash}, "balance", [
           {:address, account_pk}
         ]) do
      {:ok, {:variant, [0, 1], 1, {amt}}} -> {:ok, {amt, {type, height, hash}}}
      {:ok, {:variant, [0, 1], 0, {}}} -> {:ok, {nil, {type, height, hash}}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec aex9_balances!(pubkey()) :: {balances_map(), height_hash()}
  def aex9_balances!(contract_pk),
    do: aex9_balances!(contract_pk, false)

  @spec aex9_balances!(pubkey(), boolean()) :: {balances_map(), height_hash()}
  def aex9_balances!(contract_pk, the_very_top?) when is_boolean(the_very_top?),
    do: aex9_balances!(contract_pk, top_height_hash(the_very_top?))

  @spec aex9_balances!(pubkey(), height_hash()) :: {balances_map(), height_hash()}
  def aex9_balances!(contract_pk, {type, height, hash}) do
    {:ok, addr_map} =
      Runner.call_contract(
        contract_pk,
        {type, height, hash},
        "balances",
        []
      )

    {addr_map, {type, height, hash}}
  end

  @spec aex9_balances(pubkey(), height_hash()) ::
          {:ok, balances_map()} | {:error, Runner.call_error()}
  def aex9_balances(contract_pk, {_type, _height, _hash} = height_hash) do
    case Runner.call_contract(
           contract_pk,
           height_hash,
           "balances",
           []
         ) do
      {:ok, addr_map} ->
        {:ok, addr_map}

      {:error, reason} ->
        contract_id = :aeser_api_encoder.encode(:contract_pubkey, contract_pk)
        Log.warn("balances() failed! ct_id=#{contract_id}, reason=#{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec prev_block_type(tuple()) :: :key | :micro
  def prev_block_type(header) do
    prev_hash = :aec_headers.prev_hash(header)
    prev_key_hash = :aec_headers.prev_key_hash(header)

    cond do
      :aec_headers.height(header) == 0 -> :key
      prev_hash == prev_key_hash -> :key
      true -> :micro
    end
  end

  @spec proto_vsn(Blocks.height()) :: non_neg_integer()
  def proto_vsn(height) do
    {vsn, _height} =
      AeMdw.Node.height_proto()
      |> Enum.find(fn {_vsn, vsn_height} -> height >= vsn_height end)

    vsn
  end

  @spec nonce_at_block(Blocks.block_hash(), pubkey()) :: non_neg_integer()
  def nonce_at_block(mb_hash, account_pk) do
    case :aec_accounts_trees.lookup(account_pk, block_accounts_tree(mb_hash)) do
      {:value, account} -> :aec_accounts.nonce(account) + 1
      :none -> 1
    end
  end

  @spec get_block_time(Blocks.block_hash()) :: key_block() | micro_block()
  def get_block_time(block_hash),
    do: block_hash |> :aec_db.get_header() |> :aec_headers.time_in_msecs()

  defp block_accounts_tree(mb_hash) do
    {:value, micro_block} = :aec_db.find_block(mb_hash)
    header = :aec_blocks.to_header(micro_block)
    {:ok, hash} = :aec_headers.hash_header(header)
    consensus_mod = :aec_headers.consensus_module(header)
    node = {:node, header, hash, :micro}
    prev_hash = :aec_block_insertion.node_prev_hash(node)

    {:value, trees_in, _tree, _difficulty, _fees, _fraud} =
      :aec_db.find_block_state_and_data(prev_hash, true)

    node
    |> consensus_mod.state_pre_transform_micro_node(trees_in)
    |> :aec_trees.accounts()
  end

  defp micro_block_walker(hash) do
    with block <- :aec_db.get_block(hash),
         :micro <- :aec_blocks.type(block) do
      {block, :aec_blocks.prev_hash(block)}
    else
      :key -> nil
    end
  end

  @spec id_pubkey(id()) :: pubkey()
  def id_pubkey(id) do
    {_id_tag, pubkey} = :aeser_id.specialize(id)

    pubkey
  end
end
