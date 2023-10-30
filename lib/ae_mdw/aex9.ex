defmodule AeMdw.Aex9 do
  @moduledoc """
  Context module for dealing with Blocks.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.AsyncStore
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Node.Db
  alias AeMdw.Util
  alias AeMdw.Validate

  import AeMdw.Util.Encoding

  require Model

  # This needs to be an actual type like AeMdw.Db.Aex9Token.t()
  @type aex9_token() :: map()
  @type aex9_balance() :: map()
  @type account_balance() :: map()
  @type aex9_balance_history_item() :: map()
  @type amount() :: non_neg_integer()

  @typep txi :: AeMdw.Txs.txi()

  @typep pagination :: Collection.direction_limit()
  @typep pubkey :: AeMdw.Node.Db.pubkey()
  @typep height_hash :: AeMdw.Node.Db.height_hash()
  @typep balances_cursor() :: binary()
  @typep account_balance_cursor() :: binary()
  @typep history_cursor() :: binary()
  @typep range() :: {:gen, Range.t()}
  @typep order_by() :: :pubkey | :amount

  @type amounts :: map()

  @spec fetch_balances(State.t(), pubkey(), boolean()) :: {:ok, amounts()} | {:error, Error.t()}
  def fetch_balances(state, contract_pk, top?) do
    if top? do
      {amounts, _height} = Db.aex9_balances!(contract_pk, true)
      amounts
    else
      state = get_store_state(state, contract_pk)

      state
      |> Collection.stream(Model.Aex9EventBalance, {contract_pk, <<>>})
      |> Stream.take_while(&match?({^contract_pk, _address}, &1))
      |> Stream.map(&State.fetch!(state, Model.Aex9EventBalance, &1))
      |> Map.new(fn Model.aex9_event_balance(index: {_ct_pk, account_pk}, amount: amount) ->
        {{:address, account_pk}, amount}
      end)
      |> case do
        amounts when map_size(amounts) == 0 ->
          {:error,
           ErrInput.Aex9BalanceNotAvailable.exception(
             value: "contract #{encode_contract(contract_pk)}"
           )}

        %{{:address, <<>>} => nil} = amounts when map_size(amounts) == 1 ->
          {:ok, %{}}

        amounts ->
          {:ok, Map.delete(amounts, {:address, <<>>})}
      end
    end
  end

  @spec fetch_event_balances(
          State.t(),
          pubkey(),
          pagination(),
          balances_cursor() | nil,
          order_by()
        ) ::
          {:ok, {balances_cursor() | nil, [{pubkey(), pubkey()}], balances_cursor() | nil}}
          | {:error, Error.t()}
  def fetch_event_balances(state, contract_pk, pagination, cursor, :pubkey) do
    key_boundary = {{contract_pk, <<>>}, {contract_pk, Util.max_256bit_bin()}}

    with {:ok, cursor_key} <- deserialize_event_balances_cursor(contract_pk, cursor) do
      paginated_balances =
        (&Collection.stream(state, Model.Aex9EventBalance, &1, key_boundary, cursor_key))
        |> Collection.paginate(pagination, & &1, &serialize_event_balances_cursor/1)

      {:ok, paginated_balances}
    end
  end

  def fetch_event_balances(state, contract_pk, pagination, cursor, :amount) do
    key_boundary = {{contract_pk, -1, <<>>}, {contract_pk, nil, <<>>}}

    with {:ok, cursor_key} <- deserialize_balance_account_cursor(contract_pk, cursor) do
      paginated_balances =
        (&Collection.stream(state, Model.Aex9BalanceAccount, &1, key_boundary, cursor_key))
        |> Collection.paginate(pagination, & &1, &serialize_balance_account_cursor/1)

      {:ok, paginated_balances}
    end
  end

  @spec fetch_holders_count(State.t(), pubkey()) :: non_neg_integer()
  def fetch_holders_count(state, contract_pk) do
    key_boundary = {{contract_pk, <<>>}, {contract_pk, Util.max_256bit_bin()}}

    state
    |> Collection.stream(Model.Aex9EventBalance, :forward, key_boundary, nil)
    |> Stream.map(&State.fetch!(state, Model.Aex9EventBalance, &1))
    |> Enum.count(fn Model.aex9_event_balance(amount: amount) -> amount > 0 end)
  end

  @spec fetch_balance(pubkey(), pubkey(), height_hash() | nil) ::
          {:ok, aex9_balance()} | {:error, Error.t()}
  def fetch_balance(contract_pk, account_pk, height_hash) do
    case Db.aex9_balance(contract_pk, account_pk, height_hash) do
      {:ok, {amount, _height_hash}} ->
        {:ok, render_balance(contract_pk, {:address, account_pk}, amount)}

      {:error, _reason} ->
        {:error, ErrInput.ContractDryRun.exception(value: encode_contract(contract_pk))}
    end
  end

  @spec fetch_amount(State.t(), pubkey(), pubkey()) ::
          {:ok, {number(), txi()}} | {:error, Error.t()}
  def fetch_amount(state, contract_pk, account_pk) do
    state = get_store_state(state, contract_pk, account_pk)

    case State.get(state, Model.Aex9EventBalance, {contract_pk, account_pk}) do
      {:ok, Model.aex9_event_balance(amount: amount, txi: call_txi)} ->
        {:ok, {amount, call_txi}}

      :not_found ->
        {:error,
         ErrInput.Aex9BalanceNotAvailable.exception(
           value: "{#{encode_contract(contract_pk)}, #{encode_account(account_pk)}}"
         )}
    end
  end

  @spec fetch_amount_and_keyblock(State.t(), pubkey(), pubkey()) ::
          {:ok, {number(), Db.height_hash()}} | {:error, Error.t()}
  def fetch_amount_and_keyblock(state, contract_pk, account_pk) do
    with {:ok, {amount, call_txi}} <- fetch_amount(state, contract_pk, account_pk) do
      kbi = DbUtil.txi_to_gen(state, call_txi)
      Model.block(hash: kb_hash) = State.fetch!(state, Model.Block, {kbi, -1})

      {:ok, {amount, {:key, kbi, kb_hash}}}
    end
  end

  @spec fetch_account_balances(
          State.t(),
          pubkey(),
          account_balance_cursor(),
          pagination()
        ) ::
          {:ok,
           {account_balance_cursor() | nil, [account_balance()], account_balance_cursor() | nil}}
          | {:error, Error.t()}
  def fetch_account_balances(state, account_pk, cursor, pagination) do
    with {:ok, cursor} <- deserialize_account_balance_cursor(cursor) do
      type_height_hash = Db.top_height_hash(true)
      scope = {{account_pk, <<>>}, {account_pk, Util.max_256bit_bin()}}

      paginated_account_balances =
        (&Collection.stream(state, Model.Aex9AccountPresence, &1, scope, cursor))
        |> Collection.paginate(
          pagination,
          &render_account_balance(state, type_height_hash, &1),
          &serialize_account_balance_cursor/1
        )

      {:ok, paginated_account_balances}
    end
  end

  @spec fetch_balance_history(
          State.t(),
          pubkey(),
          pubkey(),
          range(),
          history_cursor(),
          pagination()
        ) ::
          {:ok, {history_cursor() | nil, [aex9_balance_history_item()], history_cursor() | nil}}
          | {:error, Error.t()}
  def fetch_balance_history(state, contract_pk, account_pk, range, cursor, pagination) do
    with {:ok, cursor} <- deserialize_history_cursor(cursor) do
      {first_gen, last_gen} =
        case range do
          {:gen, first..last} -> {first, last}
          nil -> {0, DbUtil.last_gen(state)}
        end

      streamer = fn
        :forward when first_gen <= cursor and cursor <= last_gen -> cursor..last_gen
        :backward when cursor == nil -> last_gen..first_gen
        :backward when first_gen <= cursor and cursor <= last_gen -> cursor..first_gen
        _dir -> first_gen..last_gen
      end

      paginated_history =
        Collection.paginate(
          streamer,
          pagination,
          &render_balance_history_item(contract_pk, account_pk, &1),
          & &1
        )

      {:ok, paginated_history}
    end
  end

  defp serialize_account_balance_cursor(cursor),
    do: cursor |> :erlang.term_to_binary() |> Base.encode64(padding: false)

  defp deserialize_account_balance_cursor(nil), do: {:ok, nil}

  defp deserialize_account_balance_cursor(cursor_bin64) do
    with {:ok, cursor_bin} <- Base.decode64(cursor_bin64, padding: false),
         {<<_pk1::256>>, <<_pk2::256>>} = cursor <- :erlang.binary_to_term(cursor_bin) do
      {:ok, cursor}
    else
      _invalid -> {:error, ErrInput.Cursor.exception(value: cursor_bin64)}
    end
  end

  #
  # Private functions
  #
  defp get_store_state(state, contract_pk, account_pk \\ <<>>) do
    async_state = State.new(AsyncStore.instance())

    case State.next(async_state, Model.Aex9EventBalance, {contract_pk, account_pk}) do
      {:ok, {^contract_pk, _account_pk}} -> async_state
      _other -> state
    end
  end

  defp render_balance(contract_pk, {:address, account_pk}, amount) do
    %{
      contract: encode_contract(contract_pk),
      account: encode_account(account_pk),
      amount: amount
    }
  end

  defp render_balance_history_item(contract_pk, account_pk, gen) do
    type_height_hash = {:key, gen, DbUtil.height_hash(gen)}

    {:ok, {amount_or_nil, _height_hash}} =
      Db.aex9_balance(contract_pk, account_pk, type_height_hash)

    balance = render_balance(contract_pk, {:address, account_pk}, amount_or_nil)

    Map.put(balance, :height, gen)
  end

  defp render_account_balance(state, type_height_hash, {account_pk, contract_pk}) do
    {:ok, {amount, _height_hash}} = Db.aex9_balance(contract_pk, account_pk, type_height_hash)

    Model.aexn_contract(txi_idx: {create_txi, _idx}, meta_info: {name, symbol, dec}) =
      State.fetch!(state, Model.AexnContract, {:aex9, contract_pk})

    Model.aex9_account_presence(txi: call_txi) =
      State.fetch!(state, Model.Aex9AccountPresence, {account_pk, contract_pk})

    Model.tx(id: tx_hash, block_index: {height, _mbi} = block_index) =
      State.fetch!(state, Model.Tx, call_txi)

    Model.block(hash: block_hash) = State.fetch!(state, Model.Block, block_index)

    tx_type = if create_txi == call_txi, do: :contract_create_tx, else: :contract_call_tx

    %{
      contract_id: encode_contract(contract_pk),
      block_hash: encode(:micro_block_hash, block_hash),
      tx_hash: encode(:tx_hash, tx_hash),
      tx_index: call_txi,
      tx_type: tx_type,
      height: height,
      amount: amount,
      decimals: dec,
      token_symbol: symbol,
      token_name: name
    }
  end

  defp deserialize_history_cursor(nil), do: {:ok, nil}

  defp deserialize_history_cursor(cursor) do
    case Util.parse_int(cursor) do
      {:ok, height} -> {:ok, height}
      :error -> {:error, ErrInput.Cursor.exception(value: cursor)}
    end
  end

  defp serialize_event_balances_cursor({_contract_pk, account_pk}), do: encode_account(account_pk)

  defp deserialize_event_balances_cursor(_contract_pk, nil), do: {:ok, nil}

  defp deserialize_event_balances_cursor(contract_pk, account_pk) do
    case Validate.id(account_pk, [:account_pubkey]) do
      {:ok, account_pk} -> {:ok, {contract_pk, account_pk}}
      {:error, _reason} -> {:error, ErrInput.Cursor.exception(value: account_pk)}
    end
  end

  defp serialize_balance_account_cursor({_contract_pk, amount, account_pk}),
    do: "#{amount}|#{encode_account(account_pk)}"

  defp deserialize_balance_account_cursor(_contract_pk, nil), do: {:ok, nil}

  defp deserialize_balance_account_cursor(contract_pk, cursor) do
    with [amount, account_pk] <- String.split(cursor, "|"),
         {amount_int, ""} <- Integer.parse(amount),
         {:ok, account_pk} <- Validate.id(account_pk, [:account_pubkey]) do
      {:ok, {contract_pk, amount_int, account_pk}}
    else
      _error ->
        {:error, ErrInput.Cursor.exception(value: cursor)}
    end
  end
end
