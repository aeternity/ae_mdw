defmodule AeMdw.Db do

  require AeMdw.Db.Model

  alias AeMdw.Db.Model

  import AeMdw.{Util, Sigil}




  def get_block_hash(block_index) do
    with {:ok, x} <- get_block(block_index),
      do: {:ok, Model.block(x, :hash)}
  end

  def get_block({height, mb_index}) when is_integer(height) and is_integer(mb_index),
    do: ~t[block] |> :mnesia.dirty_read({height, mb_index}) |> map_one(&{:ok, &1})
  def get_block(height),
    do: get_block({height, -1})


end
