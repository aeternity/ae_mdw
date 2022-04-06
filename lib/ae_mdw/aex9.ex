defmodule AeMdw.Aex9 do
  @moduledoc """
  Context module for dealing with Blocks.
  """

  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db
  alias AeMdw.Util
  alias AeMdw.Validate

  import AeMdwWeb.Helpers.Aex9Helper, only: [enc_ct: 1]

  require Model

  # This needs to be an actual type like AeMdw.Db.Aex9Token.t()
  @type aex9_token() :: map()
  @type aex9_balance() :: map()
  @type account_balance() :: map()
  @type aex9_balance_history_item() :: map()

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
  @typep order_by() :: :name | :symbol
  @typep query :: %{binary() => binary()}
  @typep balances_cursor() :: binary()
  @typep account_balance_cursor() :: binary()
  @typep history_cursor() :: binary()
  @typep range() :: {:gen, Range.t()}

  @type amounts :: map()

  @pagination_params ~w(limit cursor rev direction by scope)

  @aex9_contract_table Model.Aex9Contract
  @aex9_contract_symbol_table Model.Aex9ContractSymbol

  @spec fetch_balances(pubkey(), boolean()) :: amounts()
  def fetch_balances(contract_pk, top?) do
    if top? do
      {amounts, _height} = Db.aex9_balances!(contract_pk, true)
      amounts
    else
      Model.Aex9Balance
      |> Collection.stream(
        :forward,
        {{contract_pk, <<>>}, {contract_pk, Util.max_256bit_bin()}},
        nil
      )
      |> Stream.map(&Database.fetch!(Model.Aex9Balance, &1))
      |> Enum.into(%{}, fn Model.aex9_balance(index: {_ct_pk, account_pk}, amount: amount) ->
        {{:address, account_pk}, amount}
      end)
      |> case do
        amounts when map_size(amounts) == 0 ->
          raise ErrInput.Aex9BalanceNotAvailable, value: "contract #{enc_ct(contract_pk)}"

        %{{:address, <<>>} => nil} ->
          %{}

        amounts ->
          Map.delete(amounts, {:address, <<>>})
      end
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

  @spec fetch_tokens(pagination(), query(), order_by(), cursor() | nil) ::
          {:ok, cursor() | nil, [aex9_token()], cursor() | nil} | {:error, Error.t()}
  def fetch_tokens(pagination, query, order_by, cursor) do
    try do
      case deserialize_aex9_cursor(cursor) do
        {:ok, cursor} ->
          {prev_cursor, aex9_keys, next_cursor} =
            query
            |> Map.drop(@pagination_params)
            |> Enum.map(&convert_param/1)
            |> Map.new()
            |> build_tokens_streamer(order_by, cursor)
            |> Collection.paginate(pagination)

          aex9_tokens = Enum.map(aex9_keys, &render/1)

          {:ok, serialize_aex9_cursor(prev_cursor), aex9_tokens,
           serialize_aex9_cursor(next_cursor)}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e in ErrInput -> {:error, e}
    end
  end

  @spec fetch_token(pubkey()) :: {:ok, aex9_token()} | {:error, Error.t()}
  def fetch_token(contract_pk) do
    case Database.fetch(Model.Aex9ContractPubkey, contract_pk) do
      {:ok, Model.aex9_contract_pubkey(txi: txi)} ->
        {:ok, {^txi, name, symbol, decimals}} =
          Database.next_key(Model.RevAex9Contract, {txi, <<>>, nil, nil})

        {:ok, render({name, symbol, txi, decimals})}

      :not_found ->
        {:error,
         ErrInput.NotFound.exception(
           value: :aeser_api_encoder.encode(:contract_pubkey, contract_pk)
         )}
    end
  end

  @spec fetch_balances(pubkey(), pagination(), balances_cursor() | nil) ::
          {:ok, balances_cursor() | nil, [aex9_balance()], balances_cursor() | nil}
          | {:error, Error.t()}
  def fetch_balances(contract_pk, pagination, cursor) do
    if AeMdw.Contract.is_aex9?(contract_pk) do
      {amounts, _height_hash} = Db.aex9_balances!(contract_pk)
      accounts_pks = amounts |> Map.keys() |> Enum.sort()
      cursor = deserialize_balances_cursor(cursor)

      {prev_cursor, accounts, next_cursor} =
        fn direction ->
          accounts_pks =
            if direction == :forward, do: accounts_pks, else: Enum.reverse(accounts_pks)

          if cursor do
            Enum.drop_while(accounts_pks, &(not match?(^cursor, &1)))
          else
            accounts_pks
          end
        end
        |> Collection.paginate(pagination)

      balances = Enum.map(accounts, &render_balance(contract_pk, &1, Map.fetch!(amounts, &1)))

      {:ok, serialize_balances_cursor(prev_cursor), balances,
       serialize_balances_cursor(next_cursor)}
    else
      {:error,
       ErrInput.NotAex9.exception(value: :aeser_api_encoder.encode(:contract_pubkey, contract_pk))}
    end
  end

  @spec fetch_balance(pubkey(), pubkey()) :: {:ok, aex9_balance()} | {:error, Error.t()}
  def fetch_balance(contract_pk, account_pk) do
    case validate_aex9(contract_pk) do
      :ok ->
        {amount_or_nil, _height_hash} = Db.aex9_balance(contract_pk, account_pk)

        {:ok, render_balance(contract_pk, {:address, account_pk}, amount_or_nil)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec fetch_account_balances(pubkey(), account_balance_cursor(), pagination()) ::
          {:ok, account_balance_cursor() | nil, [account_balance()],
           account_balance_cursor() | nil}
          | {:error, Error.t()}
  def fetch_account_balances(account_pk, cursor, pagination) do
    last_gen = DbUtil.last_gen()
    type_height_hash = {:key, last_gen, DbUtil.height_hash(last_gen)}

    case deserialize_account_balance_cursor(cursor) do
      {:ok, cursor} ->
        scope = {{account_pk, Util.min_int(), nil}, {account_pk, Util.max_256bit_int(), nil}}

        {prev_cursor, account_presence_keys, next_cursor} =
          (&Collection.stream(Model.Aex9AccountPresence, &1, scope, cursor))
          |> Collection.paginate(pagination)

        account_presences =
          Enum.map(account_presence_keys, fn {^account_pk, call_txi, contract_pk} ->
            {amount, _height_hash} = Db.aex9_balance(contract_pk, account_pk, type_height_hash)
            create_txi = Origin.tx_index!({:contract, contract_pk})
            tx_idx = DbUtil.read_tx!(call_txi)
            info = Format.to_raw_map(tx_idx)

            {^create_txi, name, symbol, _decimals} =
              DbUtil.next(Model.RevAex9Contract, {create_txi, nil, nil, nil})

            %{
              contract_id: :aeser_api_encoder.encode(:contract_pubkey, contract_pk),
              block_hash: :aeser_api_encoder.encode(:micro_block_hash, info.block_hash),
              tx_hash: :aeser_api_encoder.encode(:tx_hash, info.hash),
              tx_index: call_txi,
              tx_type: info.tx.type,
              height: info.block_height,
              amount: amount,
              token_symbol: symbol,
              token_name: name
            }
          end)

        {:ok, serialize_account_balance_cursor(prev_cursor), account_presences,
         serialize_account_balance_cursor(next_cursor)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec fetch_balance_history(pubkey(), pubkey(), range(), history_cursor(), pagination()) ::
          {:ok, history_cursor() | nil, [aex9_balance_history_item()], history_cursor() | nil}
          | {:error, Error.t()}
  def fetch_balance_history(contract_pk, account_pk, range, cursor, pagination) do
    with :ok <- validate_aex9(contract_pk),
         {:ok, cursor} <- deserialize_history_cursor(cursor) do
      {first_gen, last_gen} =
        case range do
          {:gen, %Range{first: first, last: last}} -> {first, last}
          nil -> {0, DbUtil.last_gen()}
        end

      streamer = fn
        :forward when first_gen <= cursor and cursor <= last_gen -> cursor..last_gen
        :backward when cursor == nil -> last_gen..first_gen
        :backward when first_gen <= cursor and cursor <= last_gen -> cursor..first_gen
        _dir -> first_gen..last_gen
      end

      {prev_cursor, gens, next_cursor} = Collection.paginate(streamer, pagination)

      balance_items = Enum.map(gens, &render_balance_history_item(contract_pk, account_pk, &1))

      {:ok, prev_cursor, balance_items, next_cursor}
    end
  end

  defp serialize_account_balance_cursor(nil), do: nil

  defp serialize_account_balance_cursor({cursor, is_reversed?}),
    do: {cursor |> :erlang.term_to_binary() |> Base.encode64(), is_reversed?}

  defp deserialize_account_balance_cursor(nil), do: {:ok, nil}

  defp deserialize_account_balance_cursor(cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         {<<_pk1::256>>, txi, <<_pk2::256>>} = cursor when is_integer(txi) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor}
    else
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
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

  defp build_tokens_streamer(query, :symbol, cursor) do
    prefix = Map.get(query, :prefix, "")

    scope = {
      {prefix <> Util.min_bin(), nil, nil, nil},
      {prefix <> Util.max_256bit_bin(), nil, nil, nil}
    }

    fn direction ->
      @aex9_contract_symbol_table
      |> Collection.stream(direction, scope, cursor)
      |> Stream.map(fn {symbol, name, txi, decimals} -> {name, symbol, txi, decimals} end)
    end
  end

  defp build_tokens_streamer(query, :name, cursor) do
    prefix = Map.get(query, :prefix, "")

    scope = {
      {prefix <> Util.min_bin(), nil, nil, nil},
      {prefix <> Util.max_256bit_bin(), nil, nil, nil}
    }

    &Collection.stream(@aex9_contract_table, &1, scope, cursor)
  end

  defp render({name, symbol, txi, decimals}) do
    contract_pk = Origin.pubkey!({:contract, txi})
    contract_id = :aeser_api_encoder.encode(:contract_pubkey, contract_pk)

    %{
      name: name,
      symbol: symbol,
      decimals: decimals,
      contract_txi: txi,
      contract_id: contract_id
    }
  end

  defp render_balance(contract_pk, {:address, account_pk}, amount) do
    %{
      contract: :aeser_api_encoder.encode(:contract_pubkey, contract_pk),
      account: :aeser_api_encoder.encode(:account_pubkey, account_pk),
      amount: amount
    }
  end

  defp render_balance_history_item(contract_pk, account_pk, gen) do
    type_height_hash = {:key, gen, DbUtil.height_hash(gen)}

    {amount_or_nil, _height_hash} = Db.aex9_balance(contract_pk, account_pk, type_height_hash)

    balance = render_balance(contract_pk, {:address, account_pk}, amount_or_nil)

    Map.put(balance, :height, gen)
  end

  defp deserialize_history_cursor(nil), do: {:ok, nil}

  defp deserialize_history_cursor(cursor) do
    case Util.parse_int(cursor) do
      {:ok, height} -> {:ok, height}
      :error -> {:error, ErrInput.Cursor.exception(value: cursor)}
    end
  end

  defp serialize_balances_cursor(nil), do: nil

  defp serialize_balances_cursor({{:address, account_pk}, is_reversed?}) do
    {:aeser_api_encoder.encode(:account_pubkey, account_pk), is_reversed?}
  end

  defp deserialize_balances_cursor(nil), do: nil

  defp deserialize_balances_cursor(account_pk) do
    case Validate.id(account_pk, [:account_pubkey]) do
      {:ok, account_pk} -> {:address, account_pk}
      {:error, _reason} -> nil
    end
  end

  defp convert_param({"prefix", prefix}) when is_binary(prefix), do: {:prefix, prefix}

  defp convert_param(other_param),
    do: raise(ErrInput.Query, value: other_param)

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

  defp serialize_aex9_cursor(nil), do: nil

  defp serialize_aex9_cursor({cursor, is_reversed?}),
    do: {cursor |> :erlang.term_to_binary() |> Base.encode64(), is_reversed?}

  defp deserialize_aex9_cursor(nil), do: {:ok, nil}

  defp deserialize_aex9_cursor(cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64),
         {symbol, name, txi, decimals} = cursor_term
         when is_binary(symbol) and is_binary(name) and is_integer(txi) and is_integer(decimals) <-
           :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor_term}
    else
      _invalid ->
        {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  rescue
    ArgumentError -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
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

  defp validate_aex9(contract_pk) do
    if AeMdw.Contract.is_aex9?(contract_pk) do
      :ok
    else
      {:error,
       ErrInput.NotAex9.exception(value: :aeser_api_encoder.encode(:contract_pubkey, contract_pk))}
    end
  end
end
