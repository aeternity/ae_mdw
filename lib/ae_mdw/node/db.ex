defmodule AeMdw.Node.Db do
  alias AeMdw.Db.Model
  require Model

  # we require that block index is in place
  import AeMdw.Db.Util, only: [read_block!: 1]
  import AeMdw.Util

  ##########

  def get_blocks(height) when is_integer(height) do
    kb_hash = Model.block(read_block!({height, -1}), :hash)
    {:aec_db.get_block(kb_hash), get_micro_blocks(height)}
  end

  def get_micro_blocks(height) when is_integer(height),
    do: do_get_micro_blocks(Model.block(read_block!({height + 1, -1}), :hash))

  defp do_get_micro_blocks(<<next_gen_kb_hash::binary>>) do
    :aec_db.get_header(next_gen_kb_hash)
    |> :aec_headers.prev_hash()
    |> Stream.unfold(&micro_block_walker/1)
    |> Enum.reverse()
  end

  def micro_block_walker(hash) do
    with block <- :aec_db.get_block(hash),
         :micro <- :aec_blocks.type(block) do
      {block, :aec_blocks.prev_hash(block)}
    else
      :key -> nil
    end
  end

  def get_tx_data(<<_::256>> = tx_hash) do
    {block_hash, signed_tx} = :aec_db.find_tx_with_location(tx_hash)
    {type, tx_rec} = :aetx.specialize_type(:aetx_sign.tx(signed_tx))
    {block_hash, type, signed_tx, tx_rec}
  end

  def get_tx(<<_::256>> = tx_hash) do
    {_, signed_tx} = :aec_db.find_tx_with_location(tx_hash)
    {_, tx_rec} = :aetx.specialize_type(:aetx_sign.tx(signed_tx))
    tx_rec
  end

  def get_signed_tx(<<_::256>> = tx_hash) do
    {_, signed_tx} = :aec_db.find_tx_with_location(tx_hash)
    signed_tx
  end

  def top_height_hash(_the_very_top? = false) do
    block = :aec_chain.top_key_block() |> ok!
    header = :aec_blocks.to_key_header(block)
    {:key, :aec_headers.height(header), ok!(:aec_headers.hash_header(header))}
  end

  def top_height_hash(_the_very_top? = true) do
    {type, header} =
      case :aec_chain.top_block() do
        {:mic_block, header, _txs, _} -> {:micro, header}
        {:key_block, header} -> {:key, header}
      end
    {type, :aec_headers.height(header), ok!(:aec_headers.hash_header(header))}
  end

  # def height_hash!(bi) do
  #   m_block = read_block!(bi)
  #   {height, _} = Model.block(m_block, :index)
  #   {height, Model.block(m_block, :hash)}
  # end

  def aex9_balance(contract_pk, account_pk),
    do: aex9_balance(contract_pk, account_pk, false)

  def aex9_balance(contract_pk, account_pk, the_very_top?) when is_boolean(the_very_top?),
    do: aex9_balance(contract_pk, account_pk, top_height_hash(the_very_top?))

  def aex9_balance(contract_pk, account_pk, {type, height, hash}) do
    case AeMdw.Contract.call_contract(contract_pk, {type, height, hash}, "balance", [
           {:address, account_pk}
         ]) do
      {:ok, {:variant, [0, 1], 1, {amt}}} -> {amt, {type, height, hash}}
      {:ok, {:variant, [0, 1], 0, {}}} -> {nil, {type, height, hash}}
    end
  end

  def aex9_balances(contract_pk),
    do: aex9_balances(contract_pk, false)

  def aex9_balances(contract_pk, the_very_top?) when is_boolean(the_very_top?),
    do: aex9_balances(contract_pk, top_height_hash(the_very_top?))

  def aex9_balances(contract_pk, {type, height, hash}) do
    {:ok, addr_map} = AeMdw.Contract.call_contract(
      contract_pk,
      {type, height, hash},
      "balances",
      []
    )
    {addr_map, {type, height, hash}}
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
