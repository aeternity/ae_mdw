defmodule AeMdw.Txs do
  @moduledoc """
  Context module for dealing with Transactions.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Model.Field
  alias AeMdw.Db.Model.IdCount
  alias AeMdw.Db.Model.Tx
  alias AeMdw.Db.Model.Type
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Mnesia
  alias AeMdw.Node
  alias AeMdw.Node.Db

  require Model

  @type txi :: non_neg_integer()
  # This needs to be an actual type like AeMdw.Db.Tx.t()
  @type tx :: term()
  @type cursor :: binary()
  @type query :: %{
          types: term(),
          ids: term()
        }

  @typep reason :: binary()
  @typep direction :: Mnesia.direction()
  @typep limit :: Mnesia.limit()

  @table Tx
  @type_table Type
  @field_table Field
  @id_count_table IdCount

  @create_tx_types [:contract_create_tx, :channel_create_tx, :oracle_register_tx, :name_claim_tx]

  @spec fetch_txs(direction(), query(), cursor() | nil, limit()) ::
          {:ok, [tx()], cursor() | nil} | {:error, reason()}
  def fetch_txs(direction, query, cursor, limit) do
    ids = query |> Map.get(:ids, MapSet.new()) |> MapSet.to_list()
    types = query |> Map.get(:types, MapSet.new()) |> MapSet.to_list()
    cursor = deserialize_cursor(cursor)

    try do
      txis_streams = build_streams(ids, types, cursor, direction)

      {txis, next_cursor} = Collection.merge_streams(txis_streams, direction, limit)

      {:ok, Enum.map(txis, &fetch!/1), serialize_cursor(next_cursor)}
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  # The purpose of this function is to generate the streams that will be then used as input for
  # Collection.merge_streams/3 function. The function is divided into three clauses. There's an
  # explanation before each.
  #
  # When no filters are provided, all transactions are displayed, which means that we only need to
  # use the Txs table, without any filters.
  defp build_streams([], [], cursor, direction) do
    [
      Collection.stream(@table, direction, cursor)
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
  defp build_streams([], types, cursor, direction) do
    Enum.map(types, fn tx_type ->
      initial_key = if direction == :forward, do: {tx_type, cursor || 0}, else: {tx_type, cursor}

      @type_table
      |> Collection.stream(direction, initial_key)
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
  #              Mnesia.exists?(Field, {:spend_tx, 1, A, txi})
  #        - For {:spend_tx, 2}:
  #            initial_key = {:spend_tx, 2, B, 0}
  #            Only take txis while it matches the {:spend_tx, 2, B, _tx_index} tuple
  #            Only take txis where A has a spend_tx transaction  (as a sender) too:
  #              Mnesia.exists?(Field, {:spend_tx, 1, A, txi})
  #        - Same thing for oracle_query_tx fields
  #   4. All of the streams are returned for Collection.merge_streams/3 to take, which will merge
  #      the keys {:spend_tx, 1, B, X} and {:spend_tx, 2, B, X}, {:oracle_query_tx, 1, B, X} and
  #      {:oracle_query_tx, 3, B, X} for any value of X, filtering out all those transactions that
  #      do not include A in them.
  defp build_streams(ids, types, cursor, direction) do
    extract_txi = fn {_tx_type, _field_pos, _id, tx_index} -> tx_index end
    initial_cursor = if direction == :backward, do: cursor, else: cursor || 0

    ids_fields =
      Enum.map(ids, fn {field, id} ->
        {id, extract_transaction_by(String.split(field, "."))}
      end)

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
          count_txs_for_account(id, fields, tx_type)
        end)

      rest_accounts = Enum.reject(ids_fields, &match?({^min_account_id, ^min_fields}, &1))

      min_fields
      |> Enum.filter(&match?({^tx_type, _pos}, &1))
      |> Enum.map(fn {^tx_type, field_pos} ->
        @field_table
        |> Collection.stream(direction, {tx_type, field_pos, min_account_id, initial_cursor})
        |> Stream.take_while(&match?({^tx_type, ^field_pos, ^min_account_id, _tx_index}, &1))
        |> Stream.map(extract_txi)
        |> Stream.filter(&all_accounts_have_tx?(tx_type, &1, rest_accounts))
      end)
    end)
  end

  defp all_accounts_have_tx?(tx_type, tx_index, rest_accounts) do
    Enum.all?(rest_accounts, fn {id, fields} ->
      Enum.any?(fields, fn
        {^tx_type, pos} -> Mnesia.exists?(@field_table, {tx_type, pos, id, tx_index})
        {_tx_type, _pos} -> false
      end)
    end)
  end

  defp extract_transaction_by([]), do: []

  defp extract_transaction_by([type]) when type in ~w(account contract channel oracle name) do
    tx_types =
      if type == "account" do
        Node.tx_types()
      else
        Node.tx_group(String.to_existing_atom(type))
      end

    Enum.flat_map(tx_types, fn tx_type ->
      poss = tx_type |> Node.tx_ids() |> Map.values() |> Enum.map(&{tx_type, &1})
      # nil - for link
      if tx_type in @create_tx_types, do: [{tx_type, nil} | poss], else: poss
    end)
  end

  defp extract_transaction_by([field]) do
    if field in Node.id_fields() do
      field = String.to_existing_atom(field)

      Enum.map(field_types(field), fn tx_type ->
        {tx_type, Node.tx_ids(tx_type)[field]}
      end)
    else
      raise ErrInput.TxField, value: ":#{field}"
    end
  end

  defp extract_transaction_by([type_prefix, field]) do
    cond do
      type_prefix in Node.tx_prefixes() && field in Node.id_fields() ->
        tx_type = String.to_existing_atom("#{type_prefix}_tx")
        tx_field = String.to_existing_atom(field)

        # credo:disable-for-next-line
        if MapSet.member?(field_types(tx_field), tx_type) do
          [{tx_type, Node.tx_ids(tx_type)[tx_field]}]
        else
          raise ErrInput.TxField, value: ":#{field}"
        end

      type_prefix not in Node.tx_prefixes() ->
        raise ErrInput.TxType, value: type_prefix

      true ->
        raise ErrInput.TxField, value: ":#{type_prefix}"
    end
  end

  defp extract_transaction_by(invalid_field) do
    raise ErrInput.TxField, value: ":#{Enum.join(invalid_field, ".")}"
  end

  @spec fetch!(txi()) :: tx()
  def fetch!(txi) do
    {:ok, tx} = fetch(txi)

    tx
  end

  @spec fetch(txi()) :: {:ok, tx()} | :not_found
  def fetch(txi) do
    case Mnesia.fetch(@table, txi) do
      {:ok, tx} -> {:ok, render(tx)}
      :not_found -> :not_found
    end
  end

  defp render(Model.tx(id: tx_hash) = tx) do
    {block_hash, type, signed_tx, tx_rec} = Db.get_tx_data(tx_hash)

    Format.to_map(tx, {block_hash, type, signed_tx, tx_rec})
  end

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor(txi), do: Integer.to_string(txi)

  defp deserialize_cursor(nil), do: nil

  defp deserialize_cursor(cursor_bin) do
    case Integer.parse(cursor_bin) do
      {n, ""} -> n
      {_n, _rest} -> nil
      :error -> nil
    end
  end

  defp count_txs_for_account(id, fields, tx_type) do
    Enum.reduce(fields, 0, fn
      {^tx_type, pos}, acc ->
        case Mnesia.fetch(@id_count_table, {tx_type, pos, id}) do
          {:ok, Model.id_count(count: count)} -> acc + count
          :not_found -> acc
        end

      {_tx_type, _pos}, acc ->
        acc
    end)
  end

  defp field_types(field) do
    base_types = Node.tx_field_types(field)

    case field do
      :contract_id -> MapSet.put(base_types, :contract_create_tx)
      :channel_id -> MapSet.put(base_types, :channel_create_tx)
      :oracle_id -> MapSet.put(base_types, :oracle_register_tx)
      :name_id -> MapSet.put(base_types, :name_claim_tx)
      _other_field -> base_types
    end
  end
end
