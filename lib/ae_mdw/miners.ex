defmodule AeMdw.Miners do
  @moduledoc """
  Context module for dealing with Miners.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
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
  def fetch_miner!(state, {_total_reward, miner_pk}),
    do: render_miner(State.fetch!(state, Model.Miner, miner_pk))

  defp build_streamer(state, cursor),
    do: &Collection.stream(state, Model.RewardMiner, &1, nil, cursor)

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

  defp serialize_cursor({total_reward, miner_pk}) do
    {total_reward, miner_pk}
    |> :erlang.term_to_binary()
    |> Base.hex_encode32(padding: false)
  end

  defp deserialize_cursor(nil), do: {:ok, nil}

  defp deserialize_cursor(cursor_hex) do
    with {:ok, cursor_bin} <- Base.hex_decode32(cursor_hex, padding: false),
         {total_reward, <<miner_pk::256>>}
         when is_integer(total_reward) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, {total_reward, <<miner_pk::256>>}}
    else
      _invalid_cursor ->
        {:error, ErrInput.Cursor.exception(value: cursor_hex)}
    end
  end
end
