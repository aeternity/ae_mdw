defmodule AeMdw.Channels do
  @moduledoc """
  Main channels module.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Collection
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util
  alias AeMdw.Validate

  import AeMdw.Util.Encoding

  require Model

  @typep state() :: State.t()
  @typep pubkey() :: Db.pubkey()
  @typep type_block_hash() :: {Db.hash_type(), Db.hash()}
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

      channels = render_active_channels(state, expiration_keys)

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

  @spec fetch_channel(state(), pubkey(), type_block_hash() | nil) ::
          {:ok, channel()} | {:error, Error.t()}
  def fetch_channel(state, channel_pk, type_block_hash \\ nil) do
    case locate(state, channel_pk) do
      {:ok, m_channel, source} ->
        is_active? = source == Model.ActiveChannel
        {:ok, render_channel(state, m_channel, is_active?, type_block_hash)}

      :not_found ->
        {:error, ErrInput.NotFound.exception(value: encode(:channel, channel_pk))}
    end
  end

  @spec fetch_record!(state(), pubkey()) :: Model.channel()
  def fetch_record!(state, channel_pk) do
    {:ok, m_channel, _table} = locate(state, channel_pk)
    m_channel
  end

  defp locate(state, channel_pk) do
    [Model.ActiveChannel, Model.InactiveChannel]
    |> Enum.find_value(:not_found, fn table ->
      case State.get(state, table, channel_pk) do
        {:ok, channel} -> {:ok, channel, table}
        :not_found -> false
      end
    end)
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

  defp render_active_channels(state, keys) do
    Enum.map(keys, fn {_exp, channel_pk} ->
      m_channel = State.fetch!(state, @table_active, channel_pk)
      render_channel(state, m_channel, true)
    end)
  end

  defp render_channel(
         state,
         Model.channel(
           index: channel_pk,
           initiator: initiator_pk,
           responder: responder_pk,
           state_hash: state_hash,
           amount: amount,
           updates: [last_updated_bi_txi_idx | _rest] = updates
         ),
         is_active?,
         type_block_hash \\ nil
       ) do
    {{last_updated_height, _mbi} = update_block_index, txi_idx} = last_updated_bi_txi_idx

    {_claim_aetx, tx_hash, tx_type, update_block_hash} =
      DbUtil.read_node_tx_details(state, txi_idx)

    channel = %{
      channel: encode(:channel, channel_pk),
      initiator: encode_account(initiator_pk),
      responder: encode_account(responder_pk),
      state_hash: encode(:state, state_hash),
      last_updated_height: last_updated_height,
      last_updated_tx_hash: encode(:tx_hash, tx_hash),
      last_updated_tx_type: Format.type_to_swagger_name(tx_type),
      updates_count: length(updates),
      active: is_active?
    }

    block_hash =
      get_oldest_block_hash(state, type_block_hash, update_block_hash, update_block_index)

    case :aec_chain.get_channel_at_hash(channel_pk, block_hash) do
      {:ok, node_channel} ->
        node_details = :aesc_channels.serialize_for_client(node_channel)

        channel
        |> Map.merge(node_details)
        |> Map.drop(~w(id initiator_id responder_id channel_amount))
        |> Map.put(:amount, node_details["channel_amount"])

      {:error, _reason} ->
        Map.put(channel, :amount, amount)
    end
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

  # Gets from the oldest block state tree since some channels might be absent from newer blocks
  defp get_oldest_block_hash(_state, nil, update_block_hash, _update_block_index),
    do: update_block_hash

  defp get_oldest_block_hash(
         state,
         {block_type, block_hash},
         update_block_hash,
         update_block_index
       ) do
    case get_block_index(state, block_type, block_hash) do
      {:ok, height, mbi} ->
        if update_block_index < {height, mbi} do
          update_block_hash
        else
          block_hash
        end

      {:error, _reason} ->
        update_block_hash
    end
  end

  defp get_block_index(state, :key, block_hash) do
    with {:ok, height} <- DbUtil.key_block_height(state, block_hash) do
      {:ok, height, -1}
    end
  end

  defp get_block_index(state, :micro, block_hash) do
    DbUtil.micro_block_height_index(state, block_hash)
  end
end
