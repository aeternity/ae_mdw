defmodule AeMdw.Transfers do
  @moduledoc """
  Context module for dealing with Transfers.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Collection
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

  @type cursor :: {binary(), Collection.is_reversed?()}
  @type transfer :: term()
  @type query :: %{binary() => binary()}

  @typep pagination :: Collection.direction_limit()
  @typep range :: {:gen, Range.t()} | {:txi, Range.t()} | nil
  @typep reason :: binary()

  @pagination_params ~w(limit cursor rev direction scope tx_hash)

  @hardforks_accounts ~w(accounts_genesis accounts_minerva accounts_fortuna accounts_lima)
  @kinds ~w(fee_lock_name fee_refund_name fee_spend_name reward_block reward_dev reward_oracle) ++
           @hardforks_accounts

  @int_transfer_table Model.IntTransferTx
  @target_kind_int_transfer_tx_table Model.TargetKindIntTransferTx
  @kind_int_transfer_tx_table Model.KindIntTransferTx

  @spec fetch_transfers(State.t(), pagination(), range(), query(), cursor() | nil) ::
          {:ok, cursor() | nil, [transfer()], cursor() | nil} | {:error, reason()}
  def fetch_transfers(state, pagination, range, query, cursor) do
    cursor = deserialize_cursor(cursor)
    scope = deserialize_scope(state, range)

    try do
      {prev_cursor, transfers, next_cursor} =
        query
        |> Map.drop(@pagination_params)
        |> Map.new(&convert_param/1)
        |> build_streamer(state, scope, cursor)
        |> Collection.paginate(pagination)

      {:ok, serialize_cursor(prev_cursor), Enum.map(transfers, &render(state, &1)),
       serialize_cursor(next_cursor)}
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  # Retrieves transfers within the {account, kind_prefix_*, gen_txi, X} range.
  defp build_streamer(%{account_pk: account_pk, kind_prefix: kind_prefix}, state, scope, cursor) do
    {{first_gen_txi, _first_kind, _first_account_pk, _first_ref_txi},
     {last_gen_txi, _last_kind, _last_account_pk, _last_ref_txi}} = scope

    tables_spec =
      @kinds
      |> Enum.filter(&String.starts_with?(&1, kind_prefix))
      |> Enum.map(fn kind ->
        scope = {{account_pk, kind, first_gen_txi, nil}, {account_pk, kind, last_gen_txi, nil}}

        cursor =
          case cursor do
            nil -> nil
            {gen_txi, _kind, account_pk, ref_txi} -> {account_pk, kind, gen_txi, ref_txi}
          end

        {scope, cursor}
      end)

    fn direction ->
      tables_spec
      |> Enum.map(fn {scope, cursor} ->
        build_target_kind_int_transfer_stream(state, direction, scope, cursor)
      end)
      |> Collection.merge(direction)
    end
  end

  # Retrieves transfers within the {account, gen_txi, X, Y} range.
  defp build_streamer(%{account_pk: account_pk}, state, scope, cursor) do
    build_streamer(%{account_pk: account_pk, kind_prefix: ""}, state, scope, cursor)
  end

  # Retrieves transfers within the {kind_prefix_*, gen_txi, account, X} range.
  defp build_streamer(%{kind_prefix: kind_prefix}, state, scope, cursor) do
    {{first_gen_txi, _first_kind, first_account_pk, _first_ref_txi},
     {last_gen_txi, _last_kind, last_account_pk, _last_ref_txi}} = scope

    tables_spec =
      @kinds
      |> Enum.filter(&String.starts_with?(&1, kind_prefix))
      |> Enum.map(fn kind ->
        scope =
          {{kind, first_gen_txi, first_account_pk, nil},
           {kind, last_gen_txi, last_account_pk, nil}}

        cursor =
          case cursor do
            nil -> nil
            {gen_txi, _kind, account_pk, ref_txi} -> {kind, gen_txi, account_pk, ref_txi}
          end

        {scope, cursor}
      end)

    fn direction ->
      tables_spec
      |> Enum.map(fn {scope, cursor} ->
        build_kind_int_transfer_stream(state, direction, scope, cursor)
      end)
      |> Collection.merge(direction)
    end
  end

  defp build_streamer(_query, state, scope, cursor),
    do: &Collection.stream(state, @int_transfer_table, &1, scope, cursor)

  defp build_target_kind_int_transfer_stream(state, direction, scope, cursor) do
    state
    |> Collection.stream(@target_kind_int_transfer_tx_table, direction, scope, cursor)
    |> Stream.map(fn {account_pk, kind, gen_txi, ref_txi} ->
      {gen_txi, kind, account_pk, ref_txi}
    end)
  end

  defp build_kind_int_transfer_stream(state, direction, scope, cursor) do
    state
    |> Collection.stream(@kind_int_transfer_tx_table, direction, scope, cursor)
    |> Stream.map(fn {kind, gen_txi, account_pk, ref_txi} ->
      {gen_txi, kind, account_pk, ref_txi}
    end)
  end

  defp deserialize_scope(_state, nil) do
    {{{Util.min_int(), Util.min_int()}, Util.min_bin(), Util.min_bin(), Util.min_int()},
     {{Util.max_int(), Util.max_int()}, Util.max_256bit_bin(), Util.max_256bit_bin(),
      Util.max_int()}}
  end

  defp deserialize_scope(_state, {:gen, first_gen..last_gen}) do
    {{{first_gen, Util.min_int()}, Util.min_bin(), Util.min_bin(), Util.min_int()},
     {{last_gen, Util.max_int()}, Util.max_256bit_bin(), Util.max_256bit_bin(), Util.max_int()}}
  end

  defp deserialize_scope(state, {:txi, first_txi..last_txi}) do
    first_gen = DbUtil.txi_to_gen(state, first_txi)
    last_gen = DbUtil.txi_to_gen(state, last_txi)
    deserialize_scope(state, {:gen, first_gen..last_gen})
  end

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(cursor) do
    with {:ok, decoded_cursor} <- Base.hex_decode32(cursor, padding: false),
         [gen_txi_bin, kind_bin, account_pk_bin, ref_txi_bin] <-
           String.split(decoded_cursor, "$"),
         {:ok, gen_txi} <- deserialize_cursor_gen_txi(gen_txi_bin),
         {:ok, kind} <- deserialize_cursor_kind(kind_bin),
         {:ok, account_pk} <- deserialize_cursor_account_pk(account_pk_bin),
         {:ok, ref_txi} <- deserialize_cursor_ref_txi(ref_txi_bin) do
      {gen_txi, kind, account_pk, ref_txi}
    else
      _invalid_cursor -> nil
    end
  end

  defp deserialize_cursor_gen_txi(gen_txi_bin) do
    with [gen_bin, txi_bin] <- String.split(gen_txi_bin, ","),
         {gen, ""} <- Integer.parse(gen_bin),
         {txi, ""} <- Integer.parse(txi_bin) do
      {:ok, {gen, txi}}
    else
      _error -> :error
    end
  end

  defp deserialize_cursor_kind(kind_bin), do: {:ok, kind_bin}

  defp deserialize_cursor_account_pk(account_pk_bin),
    do: Base.decode32(account_pk_bin, padding: false)

  defp deserialize_cursor_ref_txi(ref_txi_bin) do
    case Integer.parse(ref_txi_bin) do
      {ref_txi, ""} -> {:ok, ref_txi}
      _error -> :error
    end
  end

  defp convert_param({"account", account_id}) when is_binary(account_id),
    do: {:account_pk, Validate.id!(account_id, [:account_pubkey])}

  defp convert_param({"kind", kind_prefix}) when is_binary(kind_prefix),
    do: {:kind_prefix, kind_prefix}

  defp convert_param(other_param),
    do: raise(ErrInput.Query, value: other_param)

  defp render(state, {{height, _opt_txi_idx}, kind, target_pk, opt_ref_txi_idx} = transfer_key) do
    m_transfer = State.fetch!(state, Model.IntTransferTx, transfer_key)
    amount = Model.int_transfer_tx(m_transfer, :amount)

    {ref_tx_type, ref_tx_hash, ref_block_hash} =
      case opt_ref_txi_idx do
        -1 ->
          {nil, nil, nil}

        ref_txi_idx ->
          {_tx, _inner_tx_type, ref_tx_hash, ref_tx_type, ref_block_hash} =
            DbUtil.read_node_tx_details(state, ref_txi_idx)

          {
            Enc.encode(:micro_block_hash, ref_block_hash),
            Enc.encode(:tx_hash, ref_tx_hash),
            Format.type_to_swagger_name(ref_tx_type)
          }
      end

    %{
      height: height,
      account_id: Enc.encode(:account_pubkey, target_pk),
      amount: amount,
      kind: kind,
      ref_tx_hash: ref_tx_hash,
      ref_tx_type: ref_tx_type,
      ref_block_hash: ref_block_hash
    }
  end

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor({{{gen, txi}, kind, account_pk, ref_txi}, is_reversed?}) do
    account_pk = Base.encode32(account_pk, padding: false)

    {
      Base.hex_encode32("#{gen},#{txi}$#{kind}$#{account_pk}$#{ref_txi}", padding: false),
      is_reversed?
    }
  end
end
