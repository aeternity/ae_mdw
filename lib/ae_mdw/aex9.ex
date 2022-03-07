defmodule AeMdw.Aex9 do
  @moduledoc """
  Context module for dealing with Blocks.
  """

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Model
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db
  alias AeMdw.Util

  require Model

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
  @type amounts :: map()

  @spec fetch_balances(pubkey(), boolean()) :: amounts()
  def fetch_balances(contract_pk, top?) do
    if top? do
      {amounts, _height} = Db.aex9_balances!(contract_pk)
      amounts
    else
      Model.Aex9Balance
      |> Collection.stream(
        :forward,
        {{contract_pk, <<>>}, {contract_pk, Util.max_256bit_bin()}},
        nil
      )
      |> Stream.map(&Database.fetch!(Model.Aex9Balance, &1))
      |> Enum.into(%{}, fn Model.aex9_balance(index: {_ct_pk, account_pk}, amount: amount) = m_bal ->
        if amount == nil do
          {amount, _key_height_hash} = Db.aex9_balance(contract_pk, account_pk)
          Database.dirty_write(Model.Aex9Balance, Model.aex9_balance(m_bal, amount: amount))
          {{:address, account_pk}, amount}
        else
          {{:address, account_pk}, amount}
        end
      end)
    end
  end

  @spec fetch_sender_transfers(pubkey(), pagination(), cursor() | nil) ::
          account_paginated_transfers()
  def fetch_sender_transfers(sender_pk, pagination, cursor) do
    paginate_account_transfers(pagination, Model.Aex9Transfer, cursor, sender_pk)
  end

  @spec fetch_recipient_transfers(pubkey(), pagination(), cursor() | nil) ::
          account_paginated_transfers()
  def fetch_recipient_transfers(recipient_pk, pagination, cursor) do
    paginate_account_transfers(pagination, Model.RevAex9Transfer, cursor, recipient_pk)
  end

  @spec fetch_pair_transfers(pubkey(), pubkey(), pagination(), cursor() | nil) ::
          pair_paginated_transfers()
  def fetch_pair_transfers(
        sender_pk,
        recipient_pk,
        pagination,
        cursor
      ) do
    cursor_key = deserialize_cursor(cursor)

    paginate_transfers(
      pagination,
      Model.Aex9PairTransfer,
      cursor_key,
      {sender_pk, recipient_pk}
    )
  end

  #
  # Private functions
  #
  defp paginate_account_transfers(
         pagination,
         table,
         cursor,
         account_pk
       ) do
    cursor_key = deserialize_cursor(cursor)

    paginate_transfers(
      pagination,
      table,
      cursor_key,
      account_pk
    )
  end

  defp paginate_transfers(
         pagination,
         table,
         cursor_key,
         params
       ) do
    key_boundary = key_boundary(params)

    {prev_cursor_key, transfer_keys, next_cursor_key_tuple} =
      table
      |> build_streamer(cursor_key, key_boundary)
      |> Collection.paginate(pagination)

    {
      serialize_cursor(prev_cursor_key),
      transfer_keys,
      serialize_cursor(next_cursor_key_tuple)
    }
  end

  defp build_streamer(table, cursor_key, key_boundary) do
    fn direction ->
      Collection.stream(table, direction, key_boundary, cursor_key)
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

  defp key_boundary({sender_pk, recipient_pk}) do
    {
      {sender_pk, recipient_pk, 0, 0, 0},
      {sender_pk, recipient_pk, nil, 0, 0}
    }
  end

  defp key_boundary(account_pk) do
    {
      {account_pk, 0, nil, 0, 0},
      {account_pk, nil, nil, 0, 0}
    }
  end
end
