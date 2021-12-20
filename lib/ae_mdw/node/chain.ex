defmodule AeMdw.Node.Chain do
  @moduledoc """
  Calls to the chain Node excluding the ones related to :aec_db (for these please see `AeMdw.Node.Db`).
  """
  @type height :: non_neg_integer()

  @spec checked_height(height()) :: height()
  def checked_height(height) when is_integer(height) and height >= 0 do
    top = top_height()

    if height > top and top > 0,
      do: raise(RuntimeError, message: "no such generation: #{height} (max = #{top})")

    height
  end

  @spec top_height() :: height()
  def top_height(),
    do: :aec_headers.height(:aec_chain.top_header())
end
