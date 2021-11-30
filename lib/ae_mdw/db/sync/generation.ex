defmodule AeMdw.Db.Sync.Generation do
  @moduledoc """
  Key block and microblocks of a generation.
  """
  @type t() :: %__MODULE__{}

  defstruct height: -1, key_block: nil, micro_blocks: []
end
