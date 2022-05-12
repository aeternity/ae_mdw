defmodule AeMdw.Db.NamesExpirationMutation do
  @moduledoc """
  Deactivate all Names and Auctions that have expired on a block height.
  """

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.State

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:height]

  @opaque t() :: %__MODULE__{
            height: Blocks.height()
          }

  @spec new(Blocks.height()) :: t()
  def new(height), do: %__MODULE__{height: height}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{height: height}, state) do
    new_state =
      state
      |> Collection.stream(Model.ActiveNameExpiration, {height, <<>>})
      |> Stream.take_while(&match?({^height, _plain_name}, &1))
      |> Enum.reduce(state, fn {_height, plain_name}, state ->
        Name.expire_name(state, height, plain_name)
      end)

    state
    |> Collection.stream(Model.AuctionExpiration, {height, <<>>})
    |> Stream.take_while(&match?({^height, _plain_name}, &1))
    |> Enum.map(&State.fetch!(state, Model.AuctionExpiration, &1))
    |> Enum.reduce(new_state, fn Model.expiration(
                                   index: {_height, plain_name},
                                   value: auction_timeout
                                 ),
                                 state ->
      Name.expire_auction(state, height, plain_name, auction_timeout)
    end)
  end
end
