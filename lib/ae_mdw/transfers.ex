defmodule AeMdw.Transfers do
  @moduledoc """
  Context module for dealing with Transfers.
  """

  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Collection
  alias AeMdw.Mnesia
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

  @int_transfer_table Model.IntTransferTx
  @target_int_transfer_tx Model.TargetIntTransferTx
  @kind_int_transfer_tx Model.KindIntTransferTx

  @spec fetch_transfers(direction(), range(), query(), cursor() | nil, limit()) ::
          {:ok, [transfer()], cursor() | nil} | {:error, reason()}
  def fetch_transfers(direction, range, query, cursor, limit) do
    cursor = deserialize_cursor(cursor)

    try do
      scope = deserialize_scope(range, direction)

      {transfers, next_cursor} =
        query
        |> Map.drop(@pagination_params)
        |> Enum.sort()
        |> Enum.map(&convert_param/1)
        |> Map.new()
        |> build_stream(scope, cursor, direction)
        |> Collection.paginate(limit)

      {:ok, Enum.map(transfers, &render/1), serialize_cursor(next_cursor)}
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  # Retrieves transfers within the {account, kind_prefix_*, gen_txi, X} range
  # and then takes transfers until one outside of the scope is reached.
  defp build_stream(%{account_pk: account_pk, kind_prefix: kind_prefix}, scope, cursor, direction) do
    {{first_gen_txi, first_kind, _first_account_pk, _first_ref_txi},
     {last_gen_txi, last_kind, _last_account_pk, _last_ref_txi}} = scope

    scope =
      {{account_pk, first_gen_txi, first_kind, nil}, {account_pk, last_gen_txi, last_kind, nil}}

    cursor =
      case cursor do
        nil -> nil
        {gen_txi, kind, account_pk, ref_txi} -> {account_pk, gen_txi, kind, ref_txi}
      end

    @target_int_transfer_tx
    |> Collection.stream(direction, scope, cursor)
    |> Stream.take_while(fn {_account_pk, _gen_txi, kind, _ref_txi} ->
      String.starts_with?(kind, kind_prefix)
    end)
    |> Stream.map(fn {account_pk, gen_txi, kind, ref_txi} ->
      {gen_txi, kind, account_pk, ref_txi}
    end)
  end

  # Retrieves transfers within the {account, gen_txi, X, Y} range.
  defp build_stream(%{account_pk: account_pk}, scope, cursor, direction) do
    {{first_gen_txi, first_kind, _first_account_pk, _first_ref_txi},
     {last_gen_txi, last_kind, _last_account_pk, _last_ref_txi}} = scope

    scope =
      {{account_pk, first_gen_txi, first_kind, nil}, {account_pk, last_gen_txi, last_kind, nil}}

    cursor =
      case cursor do
        nil -> nil
        {gen_txi, kind, account_pk, ref_txi} -> {account_pk, gen_txi, kind, ref_txi}
      end

    @target_int_transfer_tx
    |> Collection.stream(direction, scope, cursor)
    |> Stream.map(fn {account_pk, gen_txi, kind, ref_txi} ->
      {gen_txi, kind, account_pk, ref_txi}
    end)
  end

  # Retrieves transfers within the {kind_prefix_*, gen_txi, account, X} range
  # and then takes transfers until one outside of the scope is reached.
  defp build_stream(%{kind_prefix: kind_prefix}, scope, cursor, direction) do
    {{first_gen_txi, first_kind_prefix, first_account_pk, _first_ref_txi},
     {last_gen_txi, last_kind_prefix, last_account_pk, _last_ref_txi}} = scope

    scope =
      {{kind_prefix <> first_kind_prefix, first_gen_txi, first_account_pk, nil},
       {kind_prefix <> last_kind_prefix, last_gen_txi, last_account_pk, nil}}

    cursor =
      case cursor do
        nil -> nil
        {gen_txi, kind, account_pk, ref_txi} -> {kind, gen_txi, account_pk, ref_txi}
      end

    @kind_int_transfer_tx
    |> Collection.stream(direction, scope, cursor)
    |> Stream.take_while(fn {_kind, gen_txi, _account_pk, _ref_txi} ->
      first_gen_txi <= gen_txi and gen_txi <= last_gen_txi
    end)
    |> Stream.map(fn {kind, gen_txi, account_pk, ref_txi} ->
      {gen_txi, kind, account_pk, ref_txi}
    end)
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

  defp deserialize_scope({:txi, %Range{first: _first_txi, last: _last_txi}}, :forward) do
    raise ErrInput.Scope, value: "txi"
  end

  defp deserialize_scope({:txi, %Range{first: _first_txi, last: _last_txi}}, :backward) do
    raise ErrInput.Scope, value: "txi"
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
