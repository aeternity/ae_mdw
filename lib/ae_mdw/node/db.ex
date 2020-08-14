defmodule AeMdw.Node.Db do
  alias AeMdw.Db.Model
  require Model

  # we require that block index is in place
  import AeMdw.Db.Util, only: [read_block!: 1]

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

  # NOTE: only needed for manual patching of the DB in case of missing blocks
  #
  # def devfix_write_block({:mic_block, header, txs, fraud}) do
  #   {:ok, hash} = :aec_headers.hash_header(header)
  #   tx_hashes = txs |> Enum.map(&:aetx_sign.hash/1)
  #   block = {:aec_blocks, hash, tx_hashes, fraud}
  #   :mnesia.transaction(fn -> :mnesia.write(block) end)
  # end
end
