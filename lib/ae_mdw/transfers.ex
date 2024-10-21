defmodule AeMdw.Transfers do
  @moduledoc """
  Context module for dealing with Transfers.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Collection
  alias AeMdw.Node
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

  @type cursor :: Collection.pagination_cursor()
  @type transfer :: term()
  @type query :: %{binary() => binary()}

  @typep pagination :: Collection.direction_limit()
  @typep range :: {:gen, Range.t()} | {:txi, Range.t()} | nil

  @hardforks_accounts ~w(accounts_genesis accounts_minerva accounts_fortuna accounts_lima)
  @kinds ~w(fee_lock_name fee_refund_name fee_spend_name reward_block reward_dev reward_oracle) ++
           @hardforks_accounts

  @int_transfer_table Model.IntTransferTx
  @target_kind_int_transfer_tx_table Model.TargetKindIntTransferTx
  @kind_int_transfer_tx_table Model.KindIntTransferTx

  @spec fetch_transfers(State.t(), pagination(), range(), query(), cursor()) ::
          {:ok, {cursor(), [transfer()], cursor()}} | {:error, Error.t()}
  def fetch_transfers(state, pagination, range, query, cursor) do
    cursor = deserialize_cursor(cursor)
    scope = deserialize_scope(state, range)

    with {:ok, filters} <- Util.convert_params(query, &convert_param/1) do
      paginated_transfers =
        filters
        |> build_streamer(state, scope, cursor)
        |> Collection.paginate(pagination, &render(state, &1), &serialize_cursor/1)

      {:ok, paginated_transfers}
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

  defp deserialize_scope(_state, {:gen, first_gen..last_gen//_step}) do
    {{{first_gen, Util.min_int()}, Util.min_bin(), Util.min_bin(), Util.min_int()},
     {{last_gen, Util.max_int()}, Util.max_256bit_bin(), Util.max_256bit_bin(), Util.max_int()}}
  end

  defp deserialize_scope(state, {:txi, first_txi..last_txi//_step}) do
    first_gen = DbUtil.txi_to_gen(state, first_txi)
    last_gen = DbUtil.txi_to_gen(state, last_txi)
    deserialize_scope(state, {:gen, first_gen..last_gen})
  end

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(cursor) do
    with {:ok, decoded_cursor} <- Base.hex_decode32(cursor, padding: false),
         [gen_txi_idx_bin, kind_bin, account_pk_bin, ref_txi_idx_bin] <-
           String.split(decoded_cursor, "$"),
         {:ok, gen_txi} <- deserialize_cursor_gen_txi_idx(gen_txi_idx_bin),
         {:ok, kind} <- deserialize_cursor_kind(kind_bin),
         {:ok, account_pk} <- deserialize_cursor_account_pk(account_pk_bin),
         {:ok, ref_txi_idx} <- deserialize_opt_txi_idx(ref_txi_idx_bin) do
      {gen_txi, kind, account_pk, ref_txi_idx}
    else
      _invalid_cursor -> nil
    end
  end

  defp deserialize_cursor_gen_txi_idx(gen_txi_idx_bin) do
    with [gen_bin, opt_txi_idx_bin] <- String.split(gen_txi_idx_bin, ","),
         {gen, ""} <- Integer.parse(gen_bin),
         {:ok, opt_txi_idx} <- deserialize_opt_txi_idx(opt_txi_idx_bin) do
      {:ok, {gen, opt_txi_idx}}
    else
      _error -> :error
    end
  end

  defp deserialize_cursor_kind(kind_bin), do: {:ok, kind_bin}

  defp deserialize_cursor_account_pk(account_pk_bin),
    do: Base.decode32(account_pk_bin, padding: false)

  defp convert_param({"account", account_id}) when is_binary(account_id) do
    with {:ok, pubkey} <- Validate.id(account_id, [:account_pubkey]) do
      {:ok, {:account_pk, pubkey}}
    end
  end

  defp convert_param({"kind", kind_prefix}) when is_binary(kind_prefix),
    do: {:ok, {:kind_prefix, kind_prefix}}

  defp convert_param(other_param),
    do: {:error, ErrInput.Query.exception(value: other_param)}

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
            Node.tx_name(ref_tx_type)
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

  defp serialize_cursor({{gen, opt_txi_idx}, kind, account_pk, opt_ref_txi_idx}) do
    account_pk = Base.encode32(account_pk, padding: false)
    txi_idx_bin = serialize_opt_txi_idx(opt_txi_idx)
    ref_txi_idx_bin = serialize_opt_txi_idx(opt_ref_txi_idx)

    Base.hex_encode32("#{gen},#{txi_idx_bin}$#{kind}$#{account_pk}$#{ref_txi_idx_bin}",
      padding: false
    )
  end

  defp serialize_opt_txi_idx(-1), do: ""

  defp serialize_opt_txi_idx({txi, idx}), do: "#{txi + 1}x#{idx + 1}"

  defp deserialize_opt_txi_idx(""), do: {:ok, -1}

  defp deserialize_opt_txi_idx(opt_txi_idx_bin) do
    with [txi_bin, idx_bin] <- String.split(opt_txi_idx_bin, "x"),
         {txi, ""} <- Integer.parse(txi_bin),
         {idx, ""} <- Integer.parse(idx_bin) do
      {:ok, {txi - 1, idx - 1}}
    else
      _error -> :error
    end
  end
end
