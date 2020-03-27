defmodule AeMdw.Node.Db.Stream do
  def header_idx_tx(height) do
    Elixir.Stream.resource(
      fn -> {[], AeMdw.Node.Db.get_micro_blocks(height), nil, -1} end,
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
