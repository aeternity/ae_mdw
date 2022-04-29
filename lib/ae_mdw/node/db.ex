defmodule AeMdw.Node.Db do
  @moduledoc false

  alias AeMdw.Blocks
  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Log

  import AeMdw.Util

  require Logger
  require Model

  @type pubkey() :: <<_::256>>
  @type hash_type() :: nil | :key | :micro
  @type height_hash() :: {hash_type(), pos_integer(), binary()}

  @spec get_blocks(Blocks.block_hash(), Blocks.block_hash()) :: tuple()
  def get_blocks(kb_hash, next_kb_hash) do
    {:aec_db.get_block(kb_hash), get_micro_blocks(next_kb_hash)}
  end

  @spec get_micro_blocks(Blocks.block_hash()) :: list()
  def get_micro_blocks(next_kb_hash) do
    next_kb_hash
    |> :aec_db.get_header()
    |> :aec_headers.prev_hash()
    |> Stream.unfold(&micro_block_walker/1)
    |> Enum.reverse()
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

  @spec get_tx_data(binary()) :: tuple()
  def get_tx_data(<<_::256>> = tx_hash) do
    {block_hash, signed_tx} = :aec_db.find_tx_with_location(tx_hash)
    {type, tx_rec} = :aetx.specialize_type(:aetx_sign.tx(signed_tx))
    {block_hash, type, signed_tx, tx_rec}
  end

  @spec get_tx(binary()) :: tuple()
  def get_tx(<<_::256>> = tx_hash) do
    {_, signed_tx} = :aec_db.find_tx_with_location(tx_hash)
    {_, tx_rec} = :aetx.specialize_type(:aetx_sign.tx(signed_tx))
    tx_rec
  end

  @spec get_signed_tx(binary()) :: tuple()
  def get_signed_tx(<<_::256>> = tx_hash) do
    {_, signed_tx} = :aec_db.find_tx_with_location(tx_hash)
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
        {:mic_block, header, _txs, _} -> {:micro, header}
        {:key_block, header} -> {:key, header}
      end

    {type, :aec_headers.height(header), ok!(:aec_headers.hash_header(header))}
  end

  @spec aex9_balance(pubkey(), pubkey()) :: {integer() | nil, height_hash()}
  def aex9_balance(contract_pk, account_pk),
    do: aex9_balance(contract_pk, account_pk, false)

  @spec aex9_balance(pubkey(), pubkey(), boolean()) :: {integer() | nil, height_hash()}
  def aex9_balance(contract_pk, account_pk, the_very_top?) when is_boolean(the_very_top?),
    do: aex9_balance(contract_pk, account_pk, top_height_hash(the_very_top?))

  @spec aex9_balance(pubkey(), pubkey(), height_hash()) ::
          {integer() | nil, height_hash()}
  def aex9_balance(contract_pk, account_pk, {type, height, hash}) do
    case Contract.call_contract(contract_pk, {type, height, hash}, "balance", [
           {:address, account_pk}
         ]) do
      {:ok, {:variant, [0, 1], 1, {amt}}} -> {amt, {type, height, hash}}
      {:ok, {:variant, [0, 1], 0, {}}} -> {nil, {type, height, hash}}
    end
  end

  @spec aex9_balances!(pubkey()) :: {map(), height_hash()}
  def aex9_balances!(contract_pk),
    do: aex9_balances!(contract_pk, false)

  @spec aex9_balances!(pubkey(), boolean()) :: {map(), height_hash()}
  def aex9_balances!(contract_pk, the_very_top?) when is_boolean(the_very_top?),
    do: aex9_balances!(contract_pk, top_height_hash(the_very_top?))

  @spec aex9_balances!(pubkey(), height_hash()) :: {map(), height_hash()}
  def aex9_balances!(contract_pk, {type, height, hash}) do
    {:ok, addr_map} =
      Contract.call_contract(
        contract_pk,
        {type, height, hash},
        "balances",
        []
      )

    {addr_map, {type, height, hash}}
  end

  @spec aex9_balances(pubkey()) :: {map(), height_hash()}
  def aex9_balances(contract_pk),
    do: aex9_balances(contract_pk, top_height_hash(false))

  @spec aex9_balances(pubkey(), height_hash()) :: {map(), height_hash()}
  def aex9_balances(contract_pk, {_type, _height, _hash} = height_hash) do
    case Contract.call_contract(
           contract_pk,
           height_hash,
           "balances",
           []
         ) do
      {:ok, addr_map} ->
        {addr_map, height_hash}

      {:error, reason} ->
        contract_id = :aeser_api_encoder.encode(:contract_pubkey, contract_pk)
        Log.warn("balances() failed! ct_id=#{contract_id}, reason=#{inspect(reason)}")
        {%{}, nil}
    end
  end

  defp micro_block_walker(hash) do
    with block <- :aec_db.get_block(hash),
         :micro <- :aec_blocks.type(block) do
      {block, :aec_blocks.prev_hash(block)}
    else
      :key -> nil
    end
  end

  # NOTE: only needed for manual patching of the DB in case of missing blocks
  #
  # def devfix_write_block({:mic_block, header, txs, fraud}) do
  #   {:ok, hash} = :aec_headers.hash_header(header)
  #   tx_hashes = txs |> Enum.map(&:aetx_sign.hash/1)
  #   block = {:aec_blocks, hash, tx_hashes, fraud}
  #   :mnesia.transaction(fn -> :mnesia.write(block) end)
  # end
end
