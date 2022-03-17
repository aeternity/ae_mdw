defmodule AeMdw.Db.NamesExpirationMutation do
  @moduledoc """
  Deactivate all Names and Auctions that have expired on a block height.
  """

  alias AeMdw.Blocks
  alias AeMdw.Database
  alias AeMdw.Db.Name
  alias AeMdw.Names

  @derive AeMdw.Db.TxnMutation
  defstruct [:height, :expired_names, :expired_auctions]

  @typep auction_key() :: {Names.plain_name(), Names.auction_timeout()}

  @opaque t() :: %__MODULE__{
            height: Blocks.height(),
            expired_names: [Names.plain_name()],
            expired_auctions: [auction_key()]
          }

  @spec new(Blocks.height(), [Names.plain_name()], [auction_key()]) :: t()
  def new(height, expired_names, expired_auctions) do
    %__MODULE__{height: height, expired_names: expired_names, expired_auctions: expired_auctions}
  end

  @spec execute(t(), Database.transaction()) :: :ok
  def execute(
        %__MODULE__{
          height: height,
          expired_names: expired_names,
          expired_auctions: expired_auctions
        },
        txn
      ) do
    Enum.each(expired_names, &Name.expire_name(txn, height, &1))

    Enum.each(expired_auctions, fn {plain_name, auction_timeout} ->
      Name.expire_auction(txn, height, plain_name, auction_timeout)
    end)
  end
end
