defmodule AeMdw.Db.NamesExpirationMutation do
  @moduledoc """
  Deactivate all Names and Auctions that have expired on a block height.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Name
  alias AeMdw.Names

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

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        height: height,
        expired_names: expired_names,
        expired_auctions: expired_auctions
      }) do
    Enum.each(expired_names, &Name.expire_name(height, &1))

    Enum.each(expired_auctions, fn {plain_name, auction_timeout} ->
      Name.expire_auction(height, plain_name, auction_timeout)
    end)
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.NamesExpirationMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
