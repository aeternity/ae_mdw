defmodule AeMdw.Db.NamesExpirationMutation do
  @moduledoc """
  Deactivate all Names and Auctions that have expired on a block height.
  """

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync.Name
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.ObjectKeys

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
        ObjectKeys.put_inactive_name(state, plain_name)
        Name.expire_name(state, height, plain_name)
      end)

    new_state
    |> Collection.stream(Model.AuctionExpiration, {height, <<>>})
    |> Stream.take_while(&match?({^height, _plain_name}, &1))
    |> Enum.map(&State.fetch!(new_state, Model.AuctionExpiration, &1))
    |> Enum.reduce(new_state, fn Model.expiration(index: {^height, plain_name}), state ->
      ObjectKeys.put_active_name(state, plain_name)
      Name.expire_auction(state, height, plain_name)
    end)
  end
end
