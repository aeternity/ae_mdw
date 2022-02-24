defmodule AeMdw.Aex9 do
  @moduledoc """
  Context module for dealing with Blocks.
  """

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Error.Input, as: ErrInput

  require Model

  import AeMdw.Util, only: [ok!: 1]

  @type account_transfer_key ::
          {pubkey(), AeMdw.Txs.txi(), pubkey(), pos_integer(), non_neg_integer()}
  @type pair_transfer_key ::
          {pubkey(), pubkey(), AeMdw.Txs.txi(), pos_integer(), non_neg_integer()}

  @type cursor :: binary()
  @type account_paginated_transfers ::
          {cursor() | nil, [account_transfer_key()], {cursor() | nil, boolean()}}
  @type pair_paginated_transfers ::
          {cursor() | nil, [pair_transfer_key()], {cursor() | nil, boolean()}}

  @typep pagination :: Collection.direction_limit()
  @typep pubkey :: AeMdw.Node.Db.pubkey()

  @spec fetch_sender_transfers(pubkey(), pagination(), cursor() | nil) ::
          account_paginated_transfers()
  def fetch_sender_transfers(sender_pk, pagination, cursor) do
    paginate_account_transfers(pagination, Model.Aex9Transfer, sender_pk, cursor)
  end

  @spec fetch_recipient_transfers(pubkey(), pagination(), cursor() | nil) ::
          account_paginated_transfers()
  def fetch_recipient_transfers(recipient_pk, pagination, cursor) do
    paginate_account_transfers(pagination, Model.RevAex9Transfer, recipient_pk, cursor)
  end

  @spec fetch_pair_transfers(pubkey(), pubkey(), pagination(), cursor() | nil) ::
          pair_paginated_transfers()
  def fetch_pair_transfers(
        sender_pk,
        recipient_pk,
        {direction, _is_reversed?, _limit, _has_cursor?} = pagination,
        cursor
      ) do
    cursor_key =
      deserialize_cursor(cursor) || default_pair_cursor(direction, sender_pk, recipient_pk)

    paginate_transfers(
      pagination,
      Model.Aex9PairTransfer,
      fn {s, r, _txi, _amount, _idx} -> s == sender_pk && r == recipient_pk end,
      cursor_key
    )
  end

  #
  # Private functions
  #
  defp paginate_account_transfers(
         {direction, _is_reversed?, _limit, _has_cursor?} = pagination,
         table,
         account_pk,
         cursor
       ) do
    cursor_key = deserialize_cursor(cursor) || default_cursor(direction, table, account_pk)

    paginate_transfers(
      pagination,
      table,
      fn key -> elem(key, 0) == account_pk end,
      cursor_key
    )
  end

  defp paginate_transfers(
         {_direction, _is_reversed?, limit, _has_cursor?} = pagination,
         table,
         key_condition,
         cursor_key
       ) do
    {prev_cursor_key, transfer_keys, next_cursor_key_tuple} =
      table
      |> build_streamer(cursor_key, key_condition, limit)
      |> Collection.paginate(pagination)

    {
      serialize_cursor(prev_cursor_key),
      transfer_keys,
      serialize_cursor(next_cursor_key_tuple)
    }
  end

  defp build_streamer(table, cursor_key, key_condition, limit) do
    fn direction ->
      # take + 1 for the next cursor
      table
      |> Collection.stream(direction, cursor_key)
      |> Stream.take(limit + 1)
      |> Stream.filter(fn key -> key_condition.(key) end)
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
           match?({<<_pk1::256>>, _txi, <<_pk2::256>>, _amount, _idx}, cursor_term) or
             match?({<<_pk1::256>>, <<_pk2::256>>, _txi, _amount, _idx}, cursor_term) do
      cursor_term
    else
      _invalid ->
        raise ErrInput.Cursor, value: cursor_bin64
    end
  end

  defp default_cursor(:forward, table, account_pk),
    do: ok!(Database.next_key(table, {account_pk, 0, nil, 0, 0}))

  defp default_cursor(:backward, table, account_pk),
    do: ok!(Database.prev_key(table, {account_pk, nil, nil, 0, 0}))

  defp default_pair_cursor(:forward, sender_pk, recipient_pk),
    do: ok!(Database.next_key(Model.Aex9PairTransfer, {sender_pk, recipient_pk, 0, 0, 0}))

  defp default_pair_cursor(:backward, sender_pk, recipient_pk),
    do: ok!(Database.prev_key(Model.Aex9PairTransfer, {sender_pk, recipient_pk, nil, 0, 0}))
end
