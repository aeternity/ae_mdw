defmodule AeMdw.Channels do
  @moduledoc """
  Main channels module.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Txs
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

  @typep state() :: State.t()
  @typep pagination() :: Collection.direction_limit()
  @typep range() :: {:gen, Range.t()} | nil
  @typep cursor() :: Collection.pagination_cursor()

  @type channel() :: map()

  @table_active Model.ActiveChannel
  @table_activation Model.ActiveChannelActivation

  @spec fetch_active_channels(state(), pagination(), range(), cursor()) ::
          {:ok, cursor(), [channel()], cursor()} | {:error, Error.t()}
  def fetch_active_channels(state, pagination, range, cursor) do
    with {:ok, cursor} <- deserialize_cursor(cursor) do
      scope = deserialize_scope(range)

      {prev_cursor, expiration_keys, next_cursor} =
        state
        |> build_streamer(scope, cursor)
        |> Collection.paginate(pagination)

      channels = render_list(state, expiration_keys)

      {:ok, serialize_cursor(prev_cursor), channels, serialize_cursor(next_cursor)}
    end
  end

  @spec channels_opened_count(state(), Txs.txi(), Txs.txi()) :: non_neg_integer()
  def channels_opened_count(state, from_txi, next_txi),
    do: type_count(state, :channel_create_tx, from_txi, next_txi)

  @spec channels_closed_count(state(), Txs.txi(), Txs.txi()) :: non_neg_integer()
  def channels_closed_count(state, from_txi, next_txi) do
    type_count(state, :channel_close_solo_tx, from_txi, next_txi) +
      type_count(state, :channel_close_mutual_tx, from_txi, next_txi) +
      type_count(state, :channel_settle_tx, from_txi, next_txi)
  end

  defp type_count(state, type, from_txi, next_txi) do
    state
    |> Collection.stream(Model.Type, {type, from_txi})
    |> Stream.take_while(&match?({^type, txi} when txi < next_txi, &1))
    |> Enum.count()
  end

  defp build_streamer(state, scope, cursor) do
    fn direction ->
      Collection.stream(state, @table_activation, direction, scope, cursor)
    end
  end

  defp render_list(state, keys),
    do: Enum.map(keys, fn {_exp, channel_pk} -> render(state, channel_pk) end)

  defp render(state, channel_pk) do
    Model.channel(
      initiator: initiator_pk,
      responder: responder_pk,
      state_hash: state_hash,
      amount: amount,
      updates: [{{last_updated_height, _mbi}, last_updated_txi} | _rest] = updates
    ) = State.fetch!(state, @table_active, channel_pk)

    %{"hash" => tx_hash, "tx" => %{"type" => tx_type}} = Txs.fetch!(state, last_updated_txi)

    %{
      channel: Enc.encode(:channel, channel_pk),
      initiator: Enc.encode(:account_pubkey, initiator_pk),
      responder: Enc.encode(:account_pubkey, responder_pk),
      state_hash: :aeser_api_encoder.encode(:state, state_hash),
      amount: amount,
      last_updated_height: last_updated_height,
      last_updated_tx_hash: tx_hash,
      last_updated_tx_type: tx_type,
      updates_count: length(updates)
    }
  end

  defp deserialize_cursor(nil), do: {:ok, nil}

  defp deserialize_cursor(cursor_bin) do
    with [exp_height, channel_pk] <-
           Regex.run(~r/\A(\d+)-(\w+)\z/, cursor_bin, capture: :all_but_first),
         {:ok, channel_pk} <- Validate.id(channel_pk, [:channel]) do
      {:ok, {String.to_integer(exp_height), channel_pk}}
    else
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor_bin)}
    end
  end

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor({{height, channel_pk}, is_reversed?}),
    do: {"#{height}-#{Enc.encode(:channel, channel_pk)}", is_reversed?}

  defp deserialize_scope({:gen, first_gen..last_gen}) do
    {{first_gen, Util.min_bin()}, {last_gen, Util.max_256bit_bin()}}
  end

  defp deserialize_scope(_nil_or_txis_scope), do: nil
end
