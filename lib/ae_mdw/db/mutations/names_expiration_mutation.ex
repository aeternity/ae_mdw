defmodule AeMdw.Db.NamesExpirationMutation do
  @moduledoc """
  Deactivate all Names and Auctions that have expired on a block height.
  """

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name

  require Model

  @derive AeMdw.Db.TxnMutation
  defstruct [:height]

  @opaque t() :: %__MODULE__{
            height: Blocks.height()
          }

  @spec new(Blocks.height()) :: t()
  def new(height), do: %__MODULE__{height: height}

  @spec execute(t(), Database.transaction()) :: :ok
  def execute(%__MODULE__{height: height}, txn) do
    Model.ActiveNameExpiration
    |> Collection.stream({height, <<>>})
    |> Stream.take_while(&match?({^height, _plain_name}, &1))
    |> Enum.each(fn {_height, plain_name} -> Name.expire_name(txn, height, plain_name) end)

    Model.AuctionExpiration
    |> Collection.stream({height, <<>>})
    |> Stream.take_while(&match?({^height, _plain_name}, &1))
    |> Enum.map(&Database.fetch!(Model.AuctionExpiration, &1))
    |> Enum.each(fn Model.expiration(index: {_height, plain_name}, value: auction_timeout) ->
      Name.expire_auction(txn, height, plain_name, auction_timeout)
    end)
  end
end
