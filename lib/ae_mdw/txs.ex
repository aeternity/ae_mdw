defmodule AeMdw.Txs do
  @moduledoc """
  Context module for dealing with Transactions.
  """

  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Database
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Model.Field
  alias AeMdw.Db.Model.IdCount
  alias AeMdw.Db.Model.Tx
  alias AeMdw.Db.Model.Type
  alias AeMdw.Db.Name
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Log
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Validate

  require Logger
  require Model

  @type tx :: map()
  @type txi :: non_neg_integer()
  @type tx_hash() :: binary()
  @type cursor :: binary()
  @type query :: %{
          types: term(),
          ids: term()
        }
  @type add_spendtx_details?() :: boolean()

  @typep reason :: binary()
  @typep pagination :: Collection.direction_limit()
  @typep range :: {:gen, Range.t()} | {:txi, Range.t()} | nil

  @table Tx
  @type_table Type
  @field_table Field
  @id_count_table IdCount

  @create_tx_types ~w(contract_create_tx channel_create_tx oracle_register_tx name_claim_tx ga_attach_tx)a

  @type_spend_tx "SpendTx"

  @spec fetch_txs(pagination(), range(), query(), cursor() | nil, add_spendtx_details?()) ::
          {:ok, cursor() | nil, [tx()], cursor() | nil} | {:error, reason()}
  def fetch_txs(pagination, range, query, cursor, add_spendtx_details?) do
    ids = query |> Map.get(:ids, MapSet.new()) |> MapSet.to_list()
    types = query |> Map.get(:types, MapSet.new()) |> MapSet.to_list()
    cursor = deserialize_cursor(cursor)

    try do
      {prev_cursor, txis, next_cursor} =
        fn direction ->
          scope =
            case range do
              {:gen, %Range{first: first_gen, last: last_gen}} ->
                {first_gen_to_txi(first_gen, direction), last_gen_to_txi(last_gen, direction)}

              {:txi, %Range{first: first_txi, last: last_txi}} ->
                {first_txi, last_txi}

              nil ->
                nil
            end

          ids
          |> build_streams(types, scope, cursor, direction)
          |> Collection.merge(direction)
        end
        |> Collection.paginate(pagination)

      txs = Enum.map(txis, &fetch!(&1, add_spendtx_details?))

      {:ok, serialize_cursor(prev_cursor), txs, serialize_cursor(next_cursor)}
    rescue
      e in ErrInput ->
        {:error, e.message}
    end
  end

  defp first_gen_to_txi(first_gen, :forward), do: DbUtil.gen_to_txi(first_gen)
  defp first_gen_to_txi(first_gen, :backward), do: DbUtil.gen_to_txi(first_gen + 1) - 1
  defp last_gen_to_txi(last_gen, :forward), do: DbUtil.gen_to_txi(last_gen + 1) - 1
  defp last_gen_to_txi(last_gen, :backward), do: DbUtil.gen_to_txi(last_gen)

  # The purpose of this function is to generate the streams that will be then used as input for
  # Collection.merge/2 function. The function is divided into three clauses. There's an explanation
  # before each.
  #
  # When no filters are provided, all transactions are displayed, which means that we only need to
  # use the Txs table, without any filters.
  defp build_streams([], [], scope, cursor, direction) do
    [
      Collection.stream(@table, direction, scope, cursor)
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
  defp build_streams([], types, scope, cursor, direction) do
    Enum.map(types, fn tx_type ->
      initial_key = if direction == :forward, do: {tx_type, cursor || 0}, else: {tx_type, cursor}

      scope =
        case scope do
          nil -> nil
          {first, last} -> {{tx_type, first}, {tx_type, last}}
        end

      @type_table
      |> Collection.stream(direction, scope, initial_key)
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
  #              Database.exists?(Field, {:spend_tx, 1, A, txi})
  #        - For {:spend_tx, 2}:
  #            initial_key = {:spend_tx, 2, B, 0}
  #            Only take txis while it matches the {:spend_tx, 2, B, _tx_index} tuple
  #            Only take txis where A has a spend_tx transaction  (as a sender) too:
  #              Database.exists?(Field, {:spend_tx, 1, A, txi})
  #        - Same thing for oracle_query_tx fields
  #   4. All of the streams are returned for Collection.merge/2 to take, which will merge
  #      the keys {:spend_tx, 1, B, X} and {:spend_tx, 2, B, X}, {:oracle_query_tx, 1, B, X} and
  #      {:oracle_query_tx, 3, B, X} for any value of X, filtering out all those transactions that
  #      do not include A in them.
  defp build_streams(ids, types, scope, cursor, direction) do
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
        field_scope = scope && field_scope(scope, tx_type, field_pos, min_account_id)
        initial_key = {tx_type, field_pos, min_account_id, initial_cursor}

        @field_table
        |> Collection.stream(direction, field_scope, initial_key)
        |> Stream.take_while(&match?({^tx_type, ^field_pos, ^min_account_id, _tx_index}, &1))
        |> Stream.map(extract_txi)
        |> Stream.filter(&all_accounts_have_tx?(tx_type, &1, rest_accounts))
      end)
    end)
  end

  defp field_scope({first, last}, tx_type, field_pos, account_id) do
    {{tx_type, field_pos, account_id, first}, {tx_type, field_pos, account_id, last}}
  end

  defp all_accounts_have_tx?(tx_type, tx_index, rest_accounts) do
    Enum.all?(rest_accounts, fn {id, fields} ->
      Enum.any?(fields, fn
        {^tx_type, pos} -> Database.exists?(@field_table, {tx_type, pos, id, tx_index})
        {_tx_type, _pos} -> false
      end)
    end)
  end

  defp extract_transaction_by([]), do: []

  defp extract_transaction_by([type]) when type in ~w(account contract channel oracle name) do
    tx_types =
      case type do
        "account" ->
          Node.tx_types()

        "contract" ->
          # less common at the end and called once
          Node.tx_group(:contract) ++ [:ga_attach_tx]

        _other ->
          Node.tx_group(String.to_existing_atom(type))
      end

    Enum.flat_map(tx_types, fn tx_type ->
      poss = tx_type |> Node.tx_ids() |> Map.values() |> Enum.map(&{tx_type, &1})
      # nil - for link
      poss = if tx_type in @create_tx_types, do: [{tx_type, nil} | poss], else: poss

      if tx_type == :contract_create_tx, do: [{:contract_call_tx, nil} | poss], else: poss
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

  @spec fetch!(txi(), add_spendtx_details?()) :: tx()
  def fetch!(txi, add_spendtx_details? \\ false) do
    {:ok, tx} = fetch(txi, add_spendtx_details?)

    tx
  end

  @spec fetch(txi() | tx_hash(), add_spendtx_details?()) :: {:ok, tx()} | {:error, Error.t()}
  def fetch(tx_hash, add_spendtx_details? \\ true)

  def fetch(tx_hash, add_spendtx_details?) when is_binary(tx_hash) do
    mb_hash = :aec_db.find_tx_location(tx_hash)

    case :aec_chain.get_header(mb_hash) do
      {:ok, mb_header} ->
        mb_header
        |> :aec_headers.height()
        |> Blocks.fetch_txis_from_gen()
        |> Stream.map(&Database.fetch!(@table, &1))
        |> Enum.find_value(
          {:error, ErrInput.NotFound.exception(value: tx_hash)},
          fn
            Model.tx(id: ^tx_hash) = tx -> {:ok, render(tx, add_spendtx_details?)}
            _tx -> nil
          end
        )

      :not_found ->
        {:error, ErrInput.NotFound.exception(value: tx_hash)}
    end
  end

  def fetch(txi, add_spendtx_details?) do
    case Database.fetch(@table, txi) do
      {:ok, tx} -> {:ok, render(tx, add_spendtx_details?)}
      :not_found -> {:error, ErrInput.NotFound.exception(value: txi)}
    end
  end

  defp render(Model.tx(id: tx_hash) = tx, add_spendtx_details?) do
    {block_hash, type, signed_tx, tx_rec} = Db.get_tx_data(tx_hash)

    rendered_tx = Format.to_map(tx, {block_hash, type, signed_tx, tx_rec})

    if add_spendtx_details? do
      maybe_add_spendtx_details(rendered_tx)
    else
      rendered_tx
    end
  end

  defp maybe_add_spendtx_details(%{"tx" => block_tx, "tx_index" => tx_index} = block) do
    recipient_id = block_tx["recipient_id"] || ""

    if block_tx["type"] == @type_spend_tx and String.starts_with?(recipient_id, "nm_") do
      update_in(block, ["tx"], fn block_tx ->
        Map.merge(block_tx, get_recipient(recipient_id, tx_index))
      end)
    else
      block
    end
  end

  defp get_recipient(spend_tx_recipient_nm, spend_txi) do
    with {:ok, plain_name} <- Validate.plain_name(spend_tx_recipient_nm),
         {:ok, pointee_pk} <- Name.account_pointer_at(plain_name, spend_txi) do
      recipient_account = :aeser_api_encoder.encode(:account_pubkey, pointee_pk)
      %{"recipient" => %{"name" => plain_name, "account" => recipient_account}}
    else
      {:error, reason} ->
        Log.warn("missing pointee for reason: #{inspect(reason)}")
        %{}
    end
  end

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor({txi, is_reversed?}), do: {Integer.to_string(txi), is_reversed?}

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
        case Database.fetch(@id_count_table, {tx_type, pos, id}) do
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
      :contract_id ->
        base_types
        |> MapSet.put(:contract_create_tx)
        |> MapSet.put(:ga_attach_tx)

      :channel_id ->
        MapSet.put(base_types, :channel_create_tx)

      :oracle_id ->
        MapSet.put(base_types, :oracle_register_tx)

      :name_id ->
        MapSet.put(base_types, :name_claim_tx)

      _other_field ->
        base_types
    end
  end
end
