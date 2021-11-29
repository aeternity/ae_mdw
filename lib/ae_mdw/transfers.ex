defmodule AeMdw.Transfers do
  @moduledoc """
  Context module for dealing with Transfers.
  """

  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Collection
  alias AeMdw.Mnesia
  alias AeMdw.Txs
  alias AeMdw.Validate

  @type cursor :: binary()
  @type transfer :: term()
  @type query :: %{binary() => binary()}

  @typep limit :: Mnesia.limit()
  @typep direction :: Mnesia.direction()
  @typep range :: {:gen, Range.t()} | {:txi, Range.t()} | nil
  @typep reason :: binary()

  @max_256bit_int 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
  @max_256bit_bin <<@max_256bit_int::256>>
  @min_int -100
  @min_binary <<>>

  @pagination_params ~w(limit cursor)

  @kinds ~w(fee_lock_name fee_refund_name fee_spend_name reward_block reward_dev reward_oracle)

  @int_transfer_table Model.IntTransferTx
  @target_kind_int_transfer_tx_table Model.TargetKindIntTransferTx
  @kind_int_transfer_tx_table Model.KindIntTransferTx

  @spec fetch_transfers(direction(), range(), query(), cursor() | nil, limit()) ::
          {:ok, [transfer()], cursor() | nil} | {:error, reason()}
  def fetch_transfers(direction, range, query, cursor, limit) do
    cursor = deserialize_cursor(cursor)
    scope = deserialize_scope(range, direction)

    try do
      {transfers, next_cursor} =
        query
        |> Map.drop(@pagination_params)
        |> Enum.sort()
        |> Enum.map(&convert_param/1)
        |> Map.new()
        |> build_stream(scope, cursor, direction)
        |> Stream.drop_while(&(not inside_txi_range?(range, &1)))
        |> Stream.take_while(&inside_txi_range?(range, &1))
        |> Collection.paginate(limit)

      {:ok, Enum.map(transfers, &render/1), serialize_cursor(next_cursor)}
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  defp inside_txi_range?(
         {:txi, %Range{first: first_txi, last: last_txi}},
         {_gen_txi, _kind, _account_pk, ref_txi}
       )
       when first_txi < last_txi,
       do: not is_nil(ref_txi) and first_txi <= ref_txi and ref_txi <= last_txi

  defp inside_txi_range?(
         {:txi, %Range{last: last_txi, first: first_txi}},
         {_gen_txi, _kind, _account_pk, ref_txi}
       ),
       do: not is_nil(ref_txi) and last_txi <= ref_txi and ref_txi <= first_txi

  defp inside_txi_range?(_range, _ref_txi), do: true

  # Retrieves transfers within the {account, kind_prefix_*, gen_txi, X} range.
  defp build_stream(%{account_pk: account_pk, kind_prefix: kind_prefix}, scope, cursor, direction) do
    {{first_gen_txi, _first_kind, _first_account_pk, _first_ref_txi},
     {last_gen_txi, _last_kind, _last_account_pk, _last_ref_txi}} = scope

    @kinds
    |> Enum.filter(&String.starts_with?(&1, kind_prefix))
    |> Enum.map(fn kind ->
      scope = {{account_pk, kind, first_gen_txi, nil}, {account_pk, kind, last_gen_txi, nil}}

      cursor =
        case cursor do
          nil -> nil
          {gen_txi, _kind, account_pk, ref_txi} -> {account_pk, kind, gen_txi, ref_txi}
        end

      @target_kind_int_transfer_tx_table
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(fn {account_pk, kind, gen_txi, ref_txi} ->
        {gen_txi, kind, account_pk, ref_txi}
      end)
    end)
    |> Collection.merge(direction)
  end

  # Retrieves transfers within the {account, gen_txi, X, Y} range.
  defp build_stream(%{account_pk: account_pk}, scope, cursor, direction) do
    build_stream(%{account_pk: account_pk, kind_prefix: ""}, scope, cursor, direction)
  end

  # Retrieves transfers within the {kind_prefix_*, gen_txi, account, X} range.
  defp build_stream(%{kind_prefix: kind_prefix}, scope, cursor, direction) do
    {{first_gen_txi, _first_kind, first_account_pk, _first_ref_txi},
     {last_gen_txi, _last_kind, last_account_pk, _last_ref_txi}} = scope

    @kinds
    |> Enum.filter(&String.starts_with?(&1, kind_prefix))
    |> Enum.map(fn kind ->
      scope =
        {{kind, first_gen_txi, first_account_pk, nil}, {kind, last_gen_txi, last_account_pk, nil}}

      cursor =
        case cursor do
          nil -> nil
          {gen_txi, _kind, account_pk, ref_txi} -> {kind, gen_txi, account_pk, ref_txi}
        end

      @kind_int_transfer_tx_table
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(fn {kind, gen_txi, account_pk, ref_txi} ->
        {gen_txi, kind, account_pk, ref_txi}
      end)
    end)
    |> Collection.merge(direction)
  end

  defp build_stream(_query, scope, cursor, direction) do
    Collection.stream(@int_transfer_table, direction, scope, cursor)
  end

  defp deserialize_scope(nil, :forward) do
    {{{@min_int, @min_int}, @min_binary, @min_binary, @min_int},
     {{@max_256bit_int, @max_256bit_int}, @max_256bit_bin, @max_256bit_bin, @max_256bit_int}}
  end

  defp deserialize_scope(nil, :backward) do
    {first, last} = deserialize_scope(nil, :forward)

    {last, first}
  end

  defp deserialize_scope({:gen, %Range{first: first_gen, last: last_gen}}, :forward) do
    {{{first_gen, @min_int}, @min_binary, @min_binary, @min_int},
     {{last_gen, @max_256bit_int}, @max_256bit_bin, @max_256bit_bin, @max_256bit_int}}
  end

  defp deserialize_scope({:gen, %Range{first: first_gen, last: last_gen}}, :backward) do
    {first, last} = deserialize_scope({:gen, %Range{first: last_gen, last: first_gen}}, :forward)

    {last, first}
  end

  defp deserialize_scope({:txi, %Range{first: first_txi, last: last_txi}}, direction) do
    deserialize_scope(
      {:gen, %Range{first: txi_to_gen(first_txi), last: txi_to_gen(last_txi)}},
      direction
    )
  end

  defp txi_to_gen(txi) do
    %{"block_height" => block_gen} = Txs.fetch!(txi)

    block_gen
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

  defp deserialize_cursor_account_pk(account_pk_bin), do: {:ok, account_pk_bin}

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

  defp render(transfer_key) do
    Format.to_map(transfer_key, @int_transfer_table)
  end

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor({{gen, txi}, kind, account_pk, ref_txi}) do
    Base.hex_encode32("#{gen},#{txi}$#{kind}$#{account_pk}$#{ref_txi}", padding: false)
  end
end
