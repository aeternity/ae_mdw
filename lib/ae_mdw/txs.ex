defmodule AeMdw.Txs do
  @moduledoc """
  Context module for dealing with Transactions.
  """

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Contract
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Model.Field
  alias AeMdw.Db.Model.IdCount
  alias AeMdw.Db.Model.Tx
  alias AeMdw.Db.Model.Type
  alias AeMdw.Db.Name
  alias AeMdw.Db.NodeStore
  alias AeMdw.Db.State
  alias AeMdw.Db.Stream.Query.Parser
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Log
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Util
  alias AeMdw.Validate

  require Logger
  require Model

  @type tx :: map()
  @type txi :: non_neg_integer()
  @type txi_idx() :: {txi(), Contract.local_idx() | -1}
  @type optional_txi_idx() :: txi_idx() | -1
  @type tx_hash() :: <<_::256>>
  @type cursor :: binary()
  @type query ::
          %{
            types: term(),
            ids: term()
          }
          | %{}
  @type opt() :: {:add_spendtx_details?, boolean()} | {:render_v3?, boolean()}
  @type opts() :: [opt()]

  @typep state() :: State.t()
  @typep pagination :: Collection.direction_limit()
  @typep range :: {:gen, Range.t()} | {:txi, Range.t()} | nil
  @typep page_cursor() :: Collection.pagination_cursor()
  @typep pubkey :: Db.pubkey()
  @typep tx_type :: Node.tx_type()

  @table Tx
  @type_table Type
  @field_table Field
  @id_count_table IdCount
  @pending_txs_table Model.Mempool

  @create_tx_types ~w(contract_create_tx channel_create_tx oracle_register_tx name_claim_tx ga_attach_tx)a

  @type_spend_tx "SpendTx"

  @spec count(state(), range(), map()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def count(state, nil, %{"tx_type" => tx_type} = params) do
    params =
      params
      |> Map.delete("tx_type")
      |> Map.put("type", tx_type)

    count(state, nil, params)
  end

  def count(state, nil, %{"id" => id, "type" => tx_type}) do
    with {:ok, address} <- Validate.id(id),
         {:ok, tx_type} <- Validate.tx_type(tx_type) do
      {:ok, count_id_type(state, address, tx_type)}
    end
  end

  def count(state, nil, %{"type_group" => type_group} = params) do
    params = Map.delete(params, "type_group")

    case Validate.tx_group(type_group) do
      {:ok, type_group} ->
        tx_types = Node.tx_group(type_group)

        sum_tx_types(state, tx_types, params)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def count(state, nil, %{"type" => tx_type}) do
    with {:ok, tx_type} <- Validate.tx_type(tx_type) do
      case State.get(state, Model.TypeCount, tx_type) do
        {:ok, Model.type_count(count: count)} -> {:ok, count}
        :not_found -> {:ok, 0}
      end
    end
  end

  def count(state, nil, %{"id" => id}) do
    with {:ok, address} <- Validate.id(id) do
      total_count =
        Node.tx_types()
        |> Enum.map(fn tx_type ->
          count_id_type(state, address, tx_type)
        end)
        |> Enum.sum()

      {:ok, total_count}
    end
  end

  def count(state, nil, params) when map_size(params) == 0 do
    case DbUtil.last_txi(state) do
      {:ok, count} -> {:ok, count}
      :none -> {:ok, 0}
    end
  end

  def count(_state, {:txi, first_txi..last_txi//_step}, params) when map_size(params) == 0,
    do: {:ok, last_txi - first_txi + 1}

  def count(state, {:gen, first_gen..last_gen//_step}, params) when map_size(params) == 0,
    do: {:ok, DbUtil.gen_to_txi(state, last_gen + 1) - DbUtil.gen_to_txi(state, first_gen)}

  def count(_state, _range, _params),
    do:
      {:error,
       ErrInput.Query.exception(value: "can't query by multiple filters and/or invalid filters")}

  @spec count_id_type(State.t(), pubkey(), tx_type()) :: non_neg_integer()
  def count_id_type(state, pubkey, tx_type) do
    {count, repeated_count} =
      tx_type
      |> Node.tx_ids_positions()
      |> Enum.reduce({0, 0}, fn field_pos, {count_acc, repeated_acc} ->
        case State.get(state, Model.IdCount, {tx_type, field_pos, pubkey}) do
          :not_found ->
            {count_acc, repeated_acc}

          {:ok, Model.id_count(count: count)} ->
            repeated_count = repeated_count(state, tx_type, field_pos, pubkey)

            {count_acc + count, repeated_acc + repeated_count}
        end
      end)

    count - div(repeated_count, 2)
  end

  @spec count_id_type_group(State.t(), pubkey(), tx_type()) :: non_neg_integer()
  def count_id_type_group(state, pubkey, tx_type_group) do
    tx_type_group
    |> Node.tx_group()
    |> Stream.map(&count_id_type(state, pubkey, &1))
    |> Enum.sum()
  end

  @spec id_counts(State.t(), pubkey()) :: %{tx_type() => non_neg_integer()}
  def id_counts(state, pubkey) do
    Enum.reduce(Node.tx_types(), %{total: 0}, fn tx_type, %{total: total} = counts ->
      field_counts = tx_count_per_field(state, tx_type, pubkey)

      if map_size(field_counts) == 0 do
        counts
      else
        counts
        |> Map.put(tx_type, field_counts)
        |> Map.put(:total, field_counts |> Map.values() |> Enum.sum() |> Kernel.+(total))
      end
    end)
  end

  @spec fetch_txs(
          State.t(),
          pagination(),
          range(),
          query(),
          cursor() | nil,
          opts()
        ) :: {:ok, {page_cursor(), [tx()], page_cursor()}} | {:error, Error.t()}
  def fetch_txs(state, pagination, range, query, cursor, opts) do
    with {:ok, streamer} <- txs_streamer(state, range, query, cursor) do
      {:ok, paginate_txs(state, streamer, pagination, opts)}
    end
  end

  @spec count_micro_block_txs(state(), binary(), query()) ::
          {:ok, non_neg_integer()} | {:error, Error.t()}
  def count_micro_block_txs(state, hash, query) do
    with {:ok, streamer} <- micro_block_txs_streamer(state, hash, query) do
      {:ok, Enum.count(streamer.(:forward))}
    end
  end

  @spec fetch_micro_block_txs(state(), binary(), query(), pagination(), cursor() | nil, opts()) ::
          {:ok, {page_cursor(), [tx()], page_cursor()}} | {:error, Error.t()}
  def fetch_micro_block_txs(state, hash, query, pagination, cursor, opts \\ []) do
    with {:ok, streamer} <- micro_block_txs_streamer(state, hash, query, cursor) do
      {:ok, paginate_txs(state, streamer, pagination, opts)}
    end
  end

  @spec txi_to_hash(state(), txi()) :: tx_hash()
  def txi_to_hash(state, txi) do
    Model.tx(id: tx_hash) = State.fetch!(state, @table, txi)

    tx_hash
  end

  @spec fetch_pending_txs(state(), pagination(), range(), cursor(), opts()) ::
          {:ok, {page_cursor(), [tx()], page_cursor()}} | {:error, Error.t()}
  def fetch_pending_txs(node_state, pagination, scope, cursor, opts) do
    cursor = deserialize_pending_tx_cursor(cursor)

    fn direction ->
      Collection.stream(node_state, @pending_txs_table, direction, scope, cursor)
    end
    |> Collection.paginate(
      pagination,
      &render_pending_tx(node_state, &1, opts),
      &serialize_pending_tx_cursor/1
    )
    |> then(&{:ok, &1})
  end

  #
  # Streams txs of a microblock
  #
  defp paginate_txs(state, streamer, pagination, opts),
    do: Collection.paginate(streamer, pagination, &fetch!(state, &1, opts), &serialize_cursor/1)

  defp micro_block_txs_streamer(state, hash, query, cursor \\ nil) do
    with {:ok, height, mbi} <- DbUtil.micro_block_height_index(state, hash),
         {:ok, Model.block(tx_index: first_txi)} <- State.get(state, Model.Block, {height, mbi}) do
      last_txi =
        case State.next(state, Model.Block, {height, mbi}) do
          {:ok, next_key} ->
            Model.block(tx_index: next_txi) = State.fetch!(state, Model.Block, next_key)
            next_txi - 1

          :none ->
            {:ok, last_txi} = State.prev(state, Model.Tx, nil)
            last_txi
        end

      txs_streamer(state, {:txi, first_txi..last_txi}, query, cursor)
    else
      {:error, reason} -> {:error, reason}
      :not_found -> {:error, ErrInput.NotFound.exception(value: hash)}
    end
  end

  #
  # Streams txs on a range satisfying the criteria from the query filters
  #
  defp txs_streamer(_state, {:txi, first..last//_step}, _query, _cursor) when first > last,
    do: {:ok, fn _direction -> [] end}

  defp txs_streamer(state, range, query, cursor) do
    with {:ok, ids_fields} <- extract_ids_fields(query) do
      types = query |> Map.get(:types, MapSet.new()) |> MapSet.to_list()
      cursor = deserialize_cursor(cursor)
      ids_fields = Enum.to_list(ids_fields)

      scope =
        case range do
          {:gen, first_gen..last_gen//_step} ->
            {DbUtil.first_gen_to_txi(state, first_gen), DbUtil.last_gen_to_txi(state, last_gen)}

          {:txi, first_txi..last_txi//_step} ->
            {first_txi, last_txi}

          nil ->
            nil
        end

      streamer = fn direction ->
        state
        |> build_streams(ids_fields, types, scope, cursor, direction)
        |> Collection.merge(direction)
      end

      {:ok, streamer}
    end
  end

  # The purpose of this function is to generate the streams that will be then used as input for
  # Collection.merge/2 function. The function is divided into three clauses. There's an explanation
  # before each.
  #
  # When no filters are provided, all transactions are displayed, which means that we only need to
  # use the Txs table, without any filters.
  defp build_streams(state, [], [], scope, cursor, direction) do
    [
      Collection.stream(state, @table, direction, scope, cursor)
    ]
  end

  # When only tx type filters are provided, then we only need to use the Type table to extract all
  # the transactions for each of these types. For this case, all keys are valid (we don't want to
  # skip any), and we are supposed to take all of the transactions up to the point where the type is
  # different.
  #
  # Examples
  #   Given types = [:paying_for_tx, :spend_tx]
  #
  #    the result of this function (with cursor = nil and direction = forward) will be two streams:
  #    - A stream on the Type table that will go from {:paying_for_tx, 0} forward, until a different
  #      type is found
  #    - A stream on the Type table that will go from {:spend_tx, 0} forward, until a different type
  #      is found.
  defp build_streams(state, [], types, scope, cursor, direction) do
    Enum.map(types, fn tx_type ->
      initial_key = if direction == :forward, do: {tx_type, cursor || 0}, else: {tx_type, cursor}

      scope =
        case scope do
          nil -> nil
          {first, last} -> {{tx_type, first}, {tx_type, last}}
        end

      state
      |> Collection.stream(@type_table, direction, scope, initial_key)
      |> Stream.take_while(&match?({^tx_type, _txi}, &1))
      |> Stream.map(fn {_tx_type, tx_index} -> tx_index end)
    end)
  end

  # This is the most complex case, and happens when there's at least one filter by id. E.g.
  #   - account=ak_29Xc6bmHMNQAaTEdUVQvqcCpmx6cWLNevZAfXaRSjZRgypYa6b
  #   - sender_id=ak_29Xc6bmHMNQAaTEdUVQvqcCpmx6cWLNevZAfXaRSjZRgypYa6b
  #   - oracle=ok_24jcHLTZQfsou7NvomRJ1hKEnjyNqbYSq2Az7DmyrAyUHPq8uR
  #
  # Each of these filters has at least one tx type and tx field position associated with them
  # (fields). The result of this function should find all the transactions where ALL of these ids
  # are present in them, including only the transaction types in the `types` list (or all if types
  # is an empty list)
  #
  # Examples
  #
  #   Given ids = [{"sender_id", A}, {"account", B}]
  #   and types = [:spend_tx, :oracle_query_tx]
  #
  #   we would like all transactions of type spend_tx or oracle_query_tx that contain both account B
  #   in any field and account A as the sender.
  #
  #   This means that the fields for each account are the following:
  #     fields = [
  #       {A, [
  #         {:oracle_query_tx, 1},
  #         {:spend_tx, 1}]},
  #       {B, [
  #         {:channel_close_mutual_tx, 1},
  #         {:channel_close_mutual_tx, 2},
  #         ...
  #         {:oracle_query_tx, 3},
  #         {:oracle_query_tx, 1},
  #         {:spend_tx, 2},
  #         {:spend_tx, 1}]}
  #     ]
  #
  # Since ALL accounts need to be present in the transactions listed, we find the intersection of
  # transactions between all accounts. Thus, for this example, we end up with :oracle_query_tx and
  # :spend_tx, which are the only types present in both (`intersection_of_types`). Then we apply the
  # types intersection, and filter out any transactions types that we do not want to return, which,
  # in this case remains the same (`MapSet<[:oracle_query_tx, :spend_tx]>`).
  #
  # Finally, for each transaction type we generate a list of results, using the following algorithm:
  #   1. For efficiency purposes, we find the account with the minimum amount of transactions of
  #      this type, for all of the fields involved. We extract this data from the IdCount table.
  #      E.g. for the spend_tx we count:
  #        - A => count(spend_tx, 1, A)
  #        - B => count(spend_tx, 1, B) + count(spend_tx, 2, B)
  #   2. We grab the account with the least amount of transactions. E.g. if it's B then:
  #        min_account_id = B
  #        min_fields = [
  #          {:oracle_query_tx, 1},
  #          {:oracle_query_tx, 3},
  #          {:spend_tx, 1},
  #          {:spend_tx, 2}]}
  #        ]
  #        rest_accounts = [{A, [{:oracle_query_tx, 1}, {:spend_tx, 1}], MapSet<...>}]
  #   3. We filter out the fields that don't belong to this tx_type and for each of these fields
  #      a new table_key tuple is built (the input of Collection.merge_with_keys/3):
  #        - For {:spend_tx, 1}:
  #            initial_key = {:spend_tx, 1, B, 0}
  #            Only take txis while it matches the {:spend_tx, 1, B, _tx_index} tuple
  #            Only take txis where A has a spend_tx transaction (as a sender) too:
  #              State.exists?(Field, {:spend_tx, 1, A, txi})
  #        - For {:spend_tx, 2}:
  #            initial_key = {:spend_tx, 2, B, 0}
  #            Only take txis while it matches the {:spend_tx, 2, B, _tx_index} tuple
  #            Only take txis where A has a spend_tx transaction  (as a sender) too:
  #              State.exists?(Field, {:spend_tx, 1, A, txi})
  #        - Same thing for oracle_query_tx fields
  #   4. All of the streams are returned for Collection.merge/2 to take, which will merge
  #      the keys {:spend_tx, 1, B, X} and {:spend_tx, 2, B, X}, {:oracle_query_tx, 1, B, X} and
  #      {:oracle_query_tx, 3, B, X} for any value of X, filtering out all those transactions that
  #      do not include A in them.
  defp build_streams(state, ids_fields, types, scope, cursor, direction) do
    extract_txi = fn {_tx_type, _field_pos, _id, tx_index} -> tx_index end
    initial_cursor = if direction == :backward, do: cursor, else: cursor || 0

    {[{_id, initial_fields}], ids_fields_rest} = Enum.split(ids_fields, 1)

    initial_tx_types =
      initial_fields |> Enum.map(fn {tx_type, _pos} -> tx_type end) |> MapSet.new()

    intersection_of_tx_types =
      Enum.reduce(ids_fields_rest, initial_tx_types, fn {_id, fields}, acc ->
        fields
        |> Enum.map(fn {tx_type, _pos} -> tx_type end)
        |> MapSet.new()
        |> MapSet.intersection(acc)
      end)

    intersection_of_tx_types =
      case types do
        [] -> intersection_of_tx_types
        _types -> MapSet.intersection(intersection_of_tx_types, MapSet.new(types))
      end

    Enum.flat_map(intersection_of_tx_types, fn tx_type ->
      {min_account_id, min_fields} =
        Enum.min_by(ids_fields, fn {id, fields} ->
          count_txs_for_account(state, id, fields, tx_type)
        end)

      rest_accounts = Enum.reject(ids_fields, &match?({^min_account_id, ^min_fields}, &1))

      min_fields
      |> Enum.filter(&match?({^tx_type, _pos}, &1))
      |> Enum.map(fn {^tx_type, field_pos} ->
        field_scope = scope && field_scope(scope, tx_type, field_pos, min_account_id)
        initial_key = {tx_type, field_pos, min_account_id, initial_cursor}

        state
        |> Collection.stream(@field_table, direction, field_scope, initial_key)
        |> Stream.take_while(&match?({^tx_type, ^field_pos, ^min_account_id, _tx_index}, &1))
        |> Stream.map(extract_txi)
        |> Stream.filter(&all_accounts_have_tx?(state, tx_type, &1, rest_accounts))
      end)
    end)
  end

  defp field_scope({first, last}, tx_type, field_pos, account_id) do
    {{tx_type, field_pos, account_id, first}, {tx_type, field_pos, account_id, last}}
  end

  defp all_accounts_have_tx?(state, tx_type, tx_index, rest_accounts) do
    Enum.all?(rest_accounts, fn {id, fields} ->
      Enum.any?(fields, fn
        {^tx_type, pos} -> State.exists?(state, @field_table, {tx_type, pos, id, tx_index})
        {_tx_type, _pos} -> false
      end)
    end)
  end

  defp extract_transaction_by([type]) when type in ~w(account contract channel oracle name) do
    tx_types =
      case type do
        "account" ->
          Node.tx_types()

        "contract" ->
          # less common at the end and called once
          [:ga_attach_tx | Node.tx_group(:contract)]

        _other ->
          Node.tx_group(String.to_existing_atom(type))
      end

    {:ok,
     Enum.flat_map(tx_types, fn tx_type ->
       poss = tx_type |> Node.tx_ids_positions() |> Enum.map(&{tx_type, &1})
       # nil - for link
       poss = if tx_type in @create_tx_types, do: [{tx_type, nil} | poss], else: poss

       if tx_type == :contract_create_tx, do: [{:contract_call_tx, nil} | poss], else: poss
     end)}
  end

  defp extract_transaction_by(["entrypoint"]) do
    {:ok, [{:contract_call_tx, AeMdw.Fields.mdw_field_pos("entrypoint")}]}
  end

  defp extract_transaction_by([field]) do
    if field in Node.id_fields() do
      field = String.to_existing_atom(field)

      field_types =
        Enum.map(Parser.field_types(field), fn tx_type ->
          {tx_type, Node.tx_ids(tx_type)[field]}
        end)

      {:ok, wrapping_tx_field_positions(:ga_meta_tx, field) ++ field_types}
    else
      {:error, ErrInput.TxField.exception(value: ":#{field}")}
    end
  end

  defp extract_transaction_by([type_prefix, field])
       when type_prefix in ["ga_meta", "paying_for"] do
    if field in Node.id_fields() do
      {:ok,
       "#{type_prefix}_tx"
       |> String.to_existing_atom()
       |> wrapping_tx_field_positions(String.to_existing_atom(field))}
    else
      {:error, ErrInput.TxField.exception(value: ":#{field}")}
    end
  end

  defp extract_transaction_by([type_prefix, field]) do
    cond do
      type_prefix in Node.tx_prefixes() && field in Node.id_fields() ->
        tx_type = String.to_existing_atom("#{type_prefix}_tx")
        tx_field = String.to_existing_atom(field)

        if MapSet.member?(Parser.field_types(tx_field), tx_type) do
          {:ok, [{tx_type, Node.tx_ids(tx_type)[tx_field]}]}
        else
          {:error, ErrInput.TxField.exception(value: ":#{field}")}
        end

      type_prefix not in Node.tx_prefixes() ->
        {:error, ErrInput.TxType.exception(value: type_prefix)}

      true ->
        {:error, ErrInput.TxField.exception(value: ":#{type_prefix}")}
    end
  end

  defp extract_transaction_by(invalid_field) do
    {:error, ErrInput.TxField.exception(value: ":#{Enum.join(invalid_field, ".")}")}
  end

  @spec fetch!(State.t(), txi(), opts()) :: tx()
  def fetch!(state, txi, opts \\ []) do
    {:ok, tx} = fetch(state, txi, opts)

    tx
  end

  @spec fetch(State.t(), txi() | tx_hash(), opts()) :: {:ok, tx()} | {:error, Error.t()}
  def fetch(state, tx_hash, opts) when is_binary(tx_hash) do
    encoded_tx_hash = :aeser_api_encoder.encode(:tx_hash, tx_hash)

    with mb_hash when is_binary(mb_hash) <- :aec_db.find_tx_location(tx_hash),
         {:ok, mb_height} <- Db.find_block_height(mb_hash) do
      state
      |> Blocks.fetch_txis_from_gen(mb_height)
      |> Stream.map(&State.fetch!(state, @table, &1))
      |> Enum.find_value(
        {:error, ErrInput.NotFound.exception(value: encoded_tx_hash)},
        fn
          Model.tx(id: ^tx_hash) = tx -> {:ok, render(state, tx, opts)}
          _tx -> nil
        end
      )
    else
      _no_block_or_header ->
        {:error, ErrInput.NotFound.exception(value: encoded_tx_hash)}
    end
  end

  def fetch(state, txi, opts) do
    case State.get(state, @table, txi) do
      {:ok, tx} -> {:ok, render(state, tx, opts)}
      :not_found -> {:error, ErrInput.NotFound.exception(value: txi)}
    end
  end

  defp render(state, tx, opts) do
    if Keyword.get(opts, :render_v3?, false) do
      render_v3(state, tx)
    else
      render_v2(state, tx, opts)
    end
  end

  defp render_v2(state, tx, opts) do
    rendered_tx = Format.to_map(state, tx)

    if Keyword.get(opts, :add_spendtx_details?, false) do
      maybe_add_spendtx_details(state, rendered_tx)
    else
      rendered_tx
    end
  end

  defp render_v3(state, tx) do
    state
    |> render_v2(tx, add_spendtx_details?: true)
    |> Map.delete("tx_index")
  end

  defp maybe_add_spendtx_details(state, %{"tx" => block_tx, "tx_index" => tx_index} = block) do
    recipient_id = block_tx["recipient_id"] || ""

    if block_tx["type"] == @type_spend_tx and String.starts_with?(recipient_id, "nm_") do
      update_in(block, ["tx"], fn block_tx ->
        Map.merge(block_tx, get_recipient(state, recipient_id, tx_index))
      end)
    else
      block
    end
  end

  defp get_recipient(state, spend_tx_recipient_nm, spend_txi) do
    with {:ok, plain_name} <- Validate.plain_name(state, spend_tx_recipient_nm),
         {:ok, recipient_account} <- Name.account_pointer_at(state, plain_name, spend_txi) do
      %{"recipient" => %{"name" => plain_name, "account" => recipient_account}}
    else
      {:error, reason} ->
        Log.warn("missing pointee for reason: #{inspect(reason)}")
        %{}
    end
  end

  defp serialize_cursor(txi), do: Integer.to_string(txi)

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(cursor_bin) do
    case Integer.parse(cursor_bin) do
      {n, ""} -> n
      {_n, _rest} -> nil
      :error -> nil
    end
  end

  defp count_txs_for_account(state, id, fields, tx_type) do
    Enum.reduce(fields, 0, fn
      {^tx_type, pos}, acc ->
        case State.get(state, @id_count_table, {tx_type, pos, id}) do
          {:ok, Model.id_count(count: count)} -> acc + count
          :not_found -> acc
        end

      {_tx_type, _pos}, acc ->
        acc
    end)
  end

  defp tx_count_per_field(state, tx_type, pubkey) do
    tx_type
    |> Node.tx_ids()
    |> Enum.reduce(%{}, fn {field, pos}, tx_counts ->
      case State.get(state, Model.IdCount, {tx_type, pos, pubkey}) do
        :not_found -> tx_counts
        {:ok, Model.id_count(count: count)} -> Map.put(tx_counts, field, count)
      end
    end)
  end

  defp wrapping_tx_field_positions(tx_type, field) do
    field
    |> Node.inner_field_positions()
    |> Enum.map(&{tx_type, &1})
  end

  defp repeated_count(state, tx_type, field_pos, pubkey) do
    case State.get(state, Model.DupIdCount, {tx_type, field_pos, pubkey}) do
      {:ok, Model.id_count(count: repeated_count)} -> repeated_count
      :not_found -> 0
    end
  end

  defp extract_ids_fields(query) do
    query
    |> Map.get(:ids, MapSet.new())
    |> Util.convert_params(fn {field, id} ->
      case extract_transaction_by(String.split(field, ".")) do
        {:ok, fields} -> {:ok, {id, fields}}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp sum_tx_types(state, tx_types, params) do
    Enum.reduce_while(tx_types, {:ok, 0}, fn tx_type, {:ok, acc} ->
      case count(state, nil, Map.put(params, "type", tx_type)) do
        {:ok, count} -> {:cont, {:ok, count + acc}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp serialize_pending_tx_cursor(tx) do
    tx
    |> :erlang.term_to_binary()
    |> Base.encode64()
  end

  defp deserialize_pending_tx_cursor(nil), do: nil

  defp deserialize_pending_tx_cursor(bin) do
    cursor =
      bin
      |> Base.decode64!()
      |> :erlang.binary_to_term()

    case match?({_neg_fee, _neg_gas_price, <<_::256>>, _nonce, <<_::256>>}, cursor) do
      true -> cursor
      false -> nil
    end
  end

  defp render_pending_tx(%State{store: node_store}, mempool_key, _opts) do
    node_store
    |> NodeStore.get(@pending_txs_table, mempool_key)
    |> case do
      Model.mempool_tx(signed_tx: signed_tx, failures: failures) ->
        signed_tx
        |> :aetx_sign.serialize_for_client_pending()
        |> Map.put("failures", failures)
    end
  end
end
