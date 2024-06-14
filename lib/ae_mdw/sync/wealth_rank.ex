defmodule AeMdw.Sync.WealthRank do
  @moduledoc """
  Wallet balance ranking.
  """

  alias AeMdw.Db.Model

  require Model

  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @opaque key :: {integer, pubkey()}

  @spec rank_size_config :: integer()
  def rank_size_config do
    with nil <- :persistent_term.get({__MODULE__, :rank_size}, nil) do
      rank_size = Application.fetch_env!(:ae_mdw, :wealth_rank_size)
      :persistent_term.put({__MODULE__, :rank_size}, rank_size)
      rank_size
    end
  end
end
