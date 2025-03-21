defmodule AeMdw.AexnTransfers do
  @moduledoc """
  Fetches indexed AEX-N transfers (from Transfer AEX-9 and AEX-141 events).
  """

  alias AeMdw.Collection
  alias AeMdw.Contract
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util
  alias AeMdw.Validate

  import AeMdw.Util.Encoding, only: [encode_contract: 1]

  require Model

  @type aexn_type :: :aex9 | :aex141
  @type amount :: non_neg_integer()
  @type amounts :: map()
  @type token_id :: non_neg_integer()

  @typep txi() :: Txs.txi()
  @typep log_idx() :: Contract.local_idx()

  @type transfer_key ::
          {:aex9 | :aex141, pubkey(), txi(), log_idx(), pubkey(), pos_integer()}
  @type pair_transfer_key ::
          {:aex9 | :aex141, pubkey(), pubkey(), txi(), log_idx(), pos_integer()}
  @type contract_transfer_key ::
          {txi(), txi(), log_idx(), pubkey(), pubkey(), pos_integer()}

  @type cursor :: binary()
  @typep page_cursor :: Collection.pagination_cursor()
  @type account_paginated_transfers ::
          {page_cursor(), [transfer_key()], page_cursor()}
  @type pair_paginated_transfers ::
          {page_cursor(), [pair_transfer_key()], page_cursor()}
  @type contract_paginated_transfers ::
          {page_cursor(), [contract_transfer_key()], page_cursor()}
  @typep pagination() :: Collection.direction_limit()
  @typep pubkey() :: Db.pubkey()

  @spec fetch_aex141_transfers(State.t(), pagination(), cursor() | nil, map()) ::
          {:ok, pair_paginated_transfers()} | {:error, Error.t()}
  def fetch_aex141_transfers(state, pagination, cursor, query) do
    with {:ok, cursor} <- deserialize_cursor(cursor),
         {:ok, {from, to}} <- resolve_from_to_filters(query) do
      key_boundary = {
        {:aex141, from || <<>>, to || <<>>, Util.min_int(), 0, 0},
        {:aex141, from || Util.max_256bit_bin(), to || Util.max_256bit_bin(), Util.max_int(), nil,
         nil}
      }

      state
      |> build_streamer(Model.AexnPairTransfer, cursor, key_boundary)
      |> Collection.paginate(pagination, & &1, &serialize_cursor/1)
      |> then(&{:ok, &1})
    end
  end

  defp resolve_from_to_filters(query) do
    filters =
      query
      |> Map.take(~w(from to))
      |> Enum.reduce_while({:ok, %{}}, fn {key, account_id}, {:ok, filters} ->
        case Validate.id(account_id) do
          {:ok, account_pk} -> {:cont, {:ok, Map.put(filters, key, account_pk)}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    with {:ok, filters} <- filters do
      filters
      |> Map.new()
      |> case do
        %{"from" => from, "to" => to} ->
          {:ok, {from, to}}

        %{"to" => _to} ->
          {:error, ErrInput.Query.exception(value: "need to provide both `from` and `to`")}

        %{"from" => from} ->
          {:ok, {from, nil}}

        _filters ->
          {:ok, {nil, nil}}
      end
    end
  end

  @spec fetch_contract_transfers(
          State.t(),
          pubkey(),
          {:from | :to | nil, pubkey()},
          pagination(),
          cursor() | nil
        ) ::
          {:ok, contract_paginated_transfers()} | {:error, Error.t()}
  def fetch_contract_transfers(state, contract_pk, {nil, account_pk}, pagination, cursor) do
    case Origin.tx_index(state, {:contract, contract_pk}) do
      {:ok, create_txi} ->
        with {:ok, cursors} <- deserialize_account_cursors(state, cursor, account_pk) do
          key_boundary = key_boundary(create_txi, account_pk)

          state
          |> build_streamer(cursors, key_boundary)
          |> Collection.paginate(pagination, & &1, &serialize_cursor/1)
          |> then(&{:ok, &1})
        end

      :not_found ->
        {:error, ErrInput.NotFound.exception(value: encode_contract(contract_pk))}
    end
  end

  def fetch_contract_transfers(state, contract_pk, {filter_by, account_pk}, pagination, cursor) do
    case Origin.tx_index(state, {:contract, contract_pk}) do
      {:ok, create_txi} ->
        table =
          if filter_by == :from,
            do: Model.AexnContractFromTransfer,
            else: Model.AexnContractToTransfer

        paginate_transfers(
          state,
          create_txi,
          pagination,
          table,
          cursor,
          account_pk
        )

      :not_found ->
        {:error, ErrInput.NotFound.exception(value: encode_contract(contract_pk))}
    end
  end

  @spec fetch_sender_transfers(State.t(), aexn_type(), pubkey(), pagination(), cursor() | nil) ::
          {:ok, account_paginated_transfers()} | {:error, Error.t()}
  def fetch_sender_transfers(state, aexn_type, sender_pk, pagination, cursor) do
    paginate_transfers(
      state,
      aexn_type,
      pagination,
      Model.AexnTransfer,
      cursor,
      sender_pk
    )
  end

  @spec fetch_recipient_transfers(State.t(), aexn_type(), pubkey(), pagination(), cursor() | nil) ::
          {:ok, account_paginated_transfers()} | {:error, Error.t()}
  def fetch_recipient_transfers(state, aexn_type, recipient_pk, pagination, cursor) do
    paginate_transfers(
      state,
      aexn_type,
      pagination,
      Model.RevAexnTransfer,
      cursor,
      recipient_pk
    )
  end

  @spec fetch_pair_transfers(
          State.t(),
          aexn_type(),
          pubkey(),
          pubkey(),
          pagination(),
          cursor() | nil
        ) ::
          {:ok, pair_paginated_transfers()} | {:error, Error.t()}
  def fetch_pair_transfers(
        state,
        aexn_type,
        sender_pk,
        recipient_pk,
        pagination,
        cursor
      ) do
    paginate_transfers(
      state,
      aexn_type,
      pagination,
      Model.AexnPairTransfer,
      cursor,
      {sender_pk, recipient_pk}
    )
  end

  #
  # Private functions
  #
  defp paginate_transfers(
         state,
         aexn_type_or_txi,
         pagination,
         table,
         cursor,
         account_pk_or_pair_pks
       ) do
    with {:ok, cursor_key} <- deserialize_cursor(cursor) do
      key_boundary = key_boundary(aexn_type_or_txi, account_pk_or_pair_pks)

      state
      |> build_streamer(table, cursor_key, key_boundary)
      |> Collection.paginate(pagination, & &1, &serialize_cursor/1)
      |> then(&{:ok, &1})
    end
  end

  defp build_streamer(state, {from_cursor_key, to_cursor_key}, key_boundary) do
    fn direction ->
      Collection.merge(
        [
          state
          |> Collection.stream(
            Model.AexnContractFromTransfer,
            direction,
            key_boundary,
            from_cursor_key
          )
          |> Stream.map(fn {create_txi, sender_pk, call_txi, log_idx, recipient_pk, value} ->
            {create_txi, call_txi, log_idx, sender_pk, recipient_pk, value}
          end),
          state
          |> Collection.stream(
            Model.AexnContractToTransfer,
            direction,
            key_boundary,
            to_cursor_key
          )
          |> Stream.map(fn {create_txi, recipient_pk, call_txi, log_idx, sender_pk, value} ->
            {create_txi, call_txi, log_idx, sender_pk, recipient_pk, value}
          end)
        ],
        direction
      )
    end
  end

  defp build_streamer(state, table, cursor_key, key_boundary) do
    fn direction ->
      Collection.stream(state, table, direction, key_boundary, cursor_key)
    end
  end

  defp serialize_cursor(cursor), do: cursor |> :erlang.term_to_binary() |> Base.encode64()

  defp deserialize_cursor(nil), do: {:ok, nil}

  defp deserialize_cursor(<<cursor_bin64::binary>>) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         cursor_term <- :erlang.binary_to_term(cursor_bin),
         true <-
           (elem(cursor_term, 0) in [:aex9, :aex141] or is_integer(elem(cursor_term, 0))) and
             (match?(
                {_type_or_pk, <<_pk1::256>>, _txi, _idx, <<_pk2::256>>, _amount},
                cursor_term
              ) or
                match?(
                  {_type_or_pk, <<_pk1::256>>, <<_pk2::256>>, _txi, _idx, _amount},
                  cursor_term
                ) or
                match?(
                  {_type_or_pk, _txi, _idx, <<_pk1::256>>, <<_pk2::256>>, _amount},
                  cursor_term
                )) do
      {:ok, cursor_term}
    else
      _invalid ->
        {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  end

  defp deserialize_account_cursors(_state, nil, _account_pk), do: {:ok, {nil, nil}}

  defp deserialize_account_cursors(_state, cursor_bin, account_pk) do
    with {:ok, cursor} <- deserialize_cursor(cursor_bin) do
      {create_txi, call_txi, log_idx, pk1, pk2, token_id} = cursor

      cursor =
        case account_pk do
          ^pk1 -> {create_txi, pk1, call_txi, log_idx, pk2, token_id}
          ^pk2 -> {create_txi, pk2, call_txi, log_idx, pk1, token_id}
        end

      {:ok, {cursor, cursor}}
    end
  end

  defp key_boundary(aexn_type, {sender_pk, recipient_pk}) do
    {
      {aexn_type, sender_pk, recipient_pk, 0, 0, 0},
      {aexn_type, sender_pk, recipient_pk, nil, 0, 0}
    }
  end

  defp key_boundary(type_or_txi, nil) do
    {
      {type_or_txi, <<>>, 0, <<>>, 0, 0},
      {type_or_txi, Util.max_256bit_bin(), nil, <<>>, 0, 0}
    }
  end

  defp key_boundary(type_or_txi, account_pk) do
    {
      {type_or_txi, account_pk, 0, <<>>, 0, 0},
      {type_or_txi, account_pk, nil, <<>>, 0, 0}
    }
  end
end
