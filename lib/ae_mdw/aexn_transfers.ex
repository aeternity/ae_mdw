defmodule AeMdw.AexnTransfers do
  @moduledoc """
  Fetches indexed AEX-N transfers (from Transfer AEX-9 and AEX-141 events).
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Util

  require Model

  @type aexn_type :: :aex9 | :aex141
  @type amount :: non_neg_integer()
  @type amounts :: map()
  @type token_id :: non_neg_integer()

  @typep txi :: AeMdw.Txs.txi()

  @type transfer_key ::
          {:aex9 | :aex141, pubkey(), txi(), pubkey(), pos_integer(), non_neg_integer()}
  @type pair_transfer_key ::
          {:aex9 | :aex141, pubkey(), pubkey(), txi(), pos_integer(), non_neg_integer()}
  @type contract_transfer_key ::
          {pubkey(), pubkey(), txi(), pubkey(), pos_integer(), non_neg_integer()}

  @type cursor :: binary()
  @type account_paginated_transfers ::
          {cursor() | nil, [transfer_key()], {cursor() | nil, boolean()}}
  @type pair_paginated_transfers ::
          {cursor() | nil, [pair_transfer_key()], {cursor() | nil, boolean()}}
  @type contract_paginated_transfers ::
          {cursor() | nil, [contract_transfer_key()], {cursor() | nil, boolean()}}
  @typep pagination :: Collection.direction_limit()
  @typep pubkey :: AeMdw.Node.Db.pubkey()

  @spec fetch_contract_transfers(
          State.t(),
          AeMdw.Txs.txi(),
          {:from | :to, pubkey() | nil},
          pagination(),
          cursor() | nil
        ) ::
          contract_paginated_transfers()
  def fetch_contract_transfers(state, contract_txi, {filter_by, account_pk}, pagination, cursor) do
    table =
      if filter_by == :from,
        do: Model.AexnContractFromTransfer,
        else: Model.AexnContractToTransfer

    paginate_transfers(
      state,
      contract_txi,
      pagination,
      table,
      cursor,
      account_pk
    )
  end

  @spec fetch_contract_recipient_transfers(
          State.t(),
          AeMdw.Txs.txi(),
          pubkey() | nil,
          pagination(),
          cursor() | nil
        ) ::
          contract_paginated_transfers()
  def fetch_contract_recipient_transfers(state, contract_txi, recipient_pk, pagination, cursor) do
    paginate_transfers(
      state,
      contract_txi,
      pagination,
      Model.AexnContractToTransfer,
      cursor,
      recipient_pk
    )
  end

  @spec fetch_sender_transfers(State.t(), aexn_type(), pubkey(), pagination(), cursor() | nil) ::
          account_paginated_transfers()
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
          account_paginated_transfers()
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
          pair_paginated_transfers()
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
         aexn_type,
         pagination,
         table,
         cursor,
         account_pk_or_pair_pks
       ) do
    cursor_key = deserialize_cursor(cursor)

    do_paginate_transfers(
      state,
      aexn_type,
      pagination,
      table,
      cursor_key,
      account_pk_or_pair_pks
    )
  end

  defp do_paginate_transfers(
         state,
         aexn_type_or_txi,
         pagination,
         table,
         cursor_key,
         params
       ) do
    key_boundary = key_boundary(aexn_type_or_txi, params)

    {prev_cursor_key, transfer_keys, next_cursor_key} =
      state
      |> build_streamer(table, cursor_key, key_boundary)
      |> Collection.paginate(pagination)

    {
      serialize_cursor(prev_cursor_key),
      transfer_keys,
      serialize_cursor(next_cursor_key)
    }
  end

  defp build_streamer(state, table, cursor_key, key_boundary) do
    fn direction ->
      Collection.stream(state, table, direction, key_boundary, cursor_key)
    end
  end

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor({cursor, is_reversed?}),
    do: {cursor |> :erlang.term_to_binary() |> Base.encode64(), is_reversed?}

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(<<cursor_bin64::binary>>) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         cursor_term <- :erlang.binary_to_term(cursor_bin),
         true <-
           (elem(cursor_term, 0) in [:aex9, :aex141] or is_integer(elem(cursor_term, 0))) and
             (match?(
                {_type_or_pk, <<_pk1::256>>, _txi, <<_pk2::256>>, _amount, _idx},
                cursor_term
              ) or
                match?(
                  {_type_or_pk, <<_pk1::256>>, <<_pk2::256>>, _txi, _amount, _idx},
                  cursor_term
                )) do
      cursor_term
    else
      _invalid ->
        raise ErrInput.Cursor, value: cursor_bin64
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
      {type_or_txi, nil, 0, nil, 0, 0},
      {type_or_txi, Util.max_256bit_bin(), nil, nil, 0, 0}
    }
  end

  defp key_boundary(type_or_txi, account_pk) do
    {
      {type_or_txi, account_pk, 0, nil, 0, 0},
      {type_or_txi, account_pk, nil, nil, 0, 0}
    }
  end
end
