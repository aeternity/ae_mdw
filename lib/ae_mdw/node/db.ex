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
end
