defmodule AeMdw.Miners do
  @moduledoc """
  Context module for dealing with Miners.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db

  require Model

  @type miner() :: map()
  @type cursor() :: binary() | nil
  @typep state() :: State.t()
  @typep pubkey() :: Db.pubkey()
  @typep pagination() :: Collection.direction_limit()

  @spec fetch_miners(state(), pagination(), cursor()) :: {cursor(), [miner()], cursor()}
  def fetch_miners(state, pagination, cursor) do
    cursor = deserialize_cursor(cursor)

    {prev_cursor, miners, next_cursor} =
      state
      |> build_streamer(cursor)
      |> Collection.paginate(pagination)

    {serialize_cursor(prev_cursor), Enum.map(miners, &fetch_miner!(state, &1)),
     serialize_cursor(next_cursor)}
  end

  @spec fetch_miner!(state(), pubkey()) :: miner()
  def fetch_miner!(state, miner_pk),
    do: render_miner(State.fetch!(state, Model.Miner, miner_pk))

  defp build_streamer(state, cursor), do: &Collection.stream(state, Model.Miner, &1, nil, cursor)

  defp render_miner(
         Model.miner(
           index: miner_pk,
           total_reward: total_reward
         )
       ) do
    %{
      miner: Enc.encode(:account_pubkey, miner_pk),
      total_reward: total_reward
    }
  end

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor({miner_pk, is_reversed?}),
    do: {Enc.encode(:account_pubkey, miner_pk), is_reversed?}

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(cursor_bin) do
    case Enc.safe_decode(:account_pubkey, cursor_bin) do
      {:ok, miner_pk} -> {:ok, miner_pk}
      {:error, _reason} -> nil
    end
  end
end
