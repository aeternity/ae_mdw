defmodule AeMdw.Miners do
  @moduledoc """
  Context module for dealing with Miners.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error
  alias AeMdw.Node.Db

  require Model

  @type miner() :: map()
  @type cursor() :: binary() | nil
  @typep state() :: State.t()
  @typep pubkey() :: Db.pubkey()
  @typep pagination() :: Collection.direction_limit()

  @spec fetch_miners(state(), pagination(), cursor()) ::
          {:ok, {cursor(), [miner()], cursor()}} | {:error, Error.t()}
  def fetch_miners(state, pagination, cursor) do
    with {:ok, cursor} <- deserialize_cursor(cursor) do
      state
      |> build_streamer(cursor)
      |> Collection.paginate(pagination, &fetch_miner!(state, &1), &serialize_cursor/1)
      |> then(&{:ok, &1})
    end
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

  defp serialize_cursor(miner_pk), do: Enc.encode(:account_pubkey, miner_pk)

  defp deserialize_cursor(nil), do: {:ok, nil}

  defp deserialize_cursor(cursor_bin) do
    case Enc.safe_decode(:account_pubkey, cursor_bin) do
      {:ok, miner_pk} -> {:ok, miner_pk}
      {:error, _reason} -> nil
    end
  end
end
