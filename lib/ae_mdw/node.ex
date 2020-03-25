defmodule AeMdw.Node do
  alias AeMdw.Db.Model

  def tx_types(),
    do: Model.get_meta!(:tx_types)

  def tx_mod(tx_type),
    do: Model.get_meta!({:tx_mod, tx_type})

  def tx_ids(tx_type),
    do: Model.get_meta!({:tx_ids, tx_type})

  def tx_fields(tx_type),
    do: Model.get_meta!({:tx_fields, tx_type})

  def tx_to_map(tx_type, tx_rec) do
    tx_fields(tx_type)
    |> Stream.with_index(1)
    |> Enum.reduce(
      %{},
      fn {field, pos}, acc ->
        put_in(acc[field], elem(tx_rec, pos))
      end
    )
  end


  defmodule Db do

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
      |> :aec_headers.prev_hash
      |> Stream.unfold(&micro_block_walker/1)
      |> Enum.reverse
    end

    def micro_block_walker(hash) do
      with block  <- :aec_db.get_block(hash),
           :micro <- :aec_blocks.type(block) do
        {block, :aec_blocks.prev_hash(block)}
      else
        :key -> nil
      end
    end

  end


  defmodule Stream do

    def header_idx_tx(height) do
      Elixir.Stream.resource(
        fn -> {[], Db.get_micro_blocks(height), nil, -1} end,
        &stream_next/1,
        &AeMdw.Util.id/1
      )
    end

    def stream_next({[tx | txs], blocks, header, mbi}),
      do: {[{header, mbi, tx}], {txs, blocks, header, mbi}}
    def stream_next({[], [], _, _}),
      do: {:halt, :done}
    def stream_next({[], [block | blocks], _, mbi}) do
      header = :aec_blocks.to_micro_header(block)
      stream_next({:aec_blocks.txs(block), blocks, header, mbi + 1})
    end

  end

end
