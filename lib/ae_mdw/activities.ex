defmodule AeMdw.Activities do
  @moduledoc """
  Activities context module.
  """
  alias :aeser_api_encoder, as: Enc
  alias AeMdw.AexnTokens
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Format
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Fields
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

  @type activity() :: map()

  @typep state() :: State.t()
  @typep pagination() :: Collection.direction_limit()
  @typep range() :: {:gen, Range.t()} | nil
  @typep query() :: map()
  @typep cursor() :: binary() | nil
  @typep height() :: Blocks.height()
  @typep txi() :: Txs.txi()
  @typep activity_value() ::
           {:field, Node.tx_type(), non_neg_integer() | nil}
           | {:int_contract_call, non_neg_integer()}
           | {:aexn, AexnTokens.aexn_type(), Db.pubkey(), Db.pubkey(), non_neg_integer(),
              non_neg_integer()}
           | {:int_transfer, IntTransfer.kind(), Txs.txi()}

  @max_pos 4
  @min_int Util.min_int()
  @max_int Util.max_int()
  @min_bin Util.min_bin()
  @max_bin Util.max_256bit_bin()

  @aexn_types ~w(aex9 aex141)a
  @kinds ~w(accounts_extra_lima accounts_fortuna accounts_genesis accounts_lima accounts_minerva contracts_lima reward_dev reward_block)

  @doc """
  Activities related to an account are those that affect the account in any way.

  The paginated activities returned follow the transactions order, and include the following:

  * Key blocks
    * Block mined {gen, -1, 0}
    * Miner rewards {gen, -1, 1..X}
    * Micro blocks
      * Block mined {gen, -1, X+1..}
      * Transactions
        * If spend_tx, oracle, channels, etc include all senders/recipient's info {gen, A, 0..X}
        * If contract_create or contract_call include:
          * All remote calls recusively {gen, A, X+1..Y}
          * All internal events {gen, A, Y+1..}

  Internally an activity is identified by the tuple {height, txi, local_idx}:

    * `height` - The key block height
    * `txi` - If the activity belongs to a transaction
    * `local_idx` - If there's more than one activity per txi, then this index is used, starting from 0.

  These are a few examples of different activities that the build_*_stream functions would return:

  * `{{5, 40, 0}, {:field, :spend_tx, 1}}` - The first activity belonging to the transaction with txi 40 (from height 10),
     where the first field of the spend transaction is the account's being queried.
  * `{{10, 20, 20}, {:int_contract_call, pos}}` - Where `pos` is the field position for the address of the internal contract call.
  * `{{20, 14, 30}, {:aexn, type, <<address-1>>, <<address-2>>, value, index}}` - Where a aexn token of type `type` was send from address-1 to address-2 with the given `value` and `index`.
  * `{{30, -1, 2}, {:int_transfer, address, kind, ref_txi}}` - Where an internal transfer of kind `kind` ocurred to the given `address`.
  """
  @spec fetch_account_activities(state(), binary(), pagination(), range(), query(), cursor()) ::
          {:ok, activity() | nil, [activity()], activity() | nil} | {:error, Error.t()}
  def fetch_account_activities(state, account, pagination, range, _query, cursor) do
    with {:ok, account_pk} <- Validate.id(account),
         {:ok, cursor} <- deserialize_cursor(cursor) do
      {prev_cursor, activities_locators_data, next_cursor} =
        fn direction ->
          {gen_scope, txi_scope} =
            case range do
              {:gen, first_gen..last_gen} ->
                {
                  {first_gen, last_gen},
                  {DbUtil.first_gen_to_txi(state, first_gen, direction),
                   DbUtil.last_gen_to_txi(state, last_gen, direction)}
                }

              nil ->
                {nil, nil}
            end

          {gen_cursor, txi_cursor, local_idx_cursor} =
            case cursor do
              {height, txi, local_idx} -> {height, txi, local_idx}
              nil -> {nil, nil, nil}
            end

          gens_stream =
            state
            |> build_int_transfers_stream(direction, account_pk, gen_scope, gen_cursor)
            |> Stream.chunk_by(fn {gen, _data} -> gen end)
            |> build_gens_stream(direction)

          txi_stream =
            [
              build_txs_stream(state, direction, account_pk, txi_scope, txi_cursor),
              build_int_contract_calls_stream(
                state,
                direction,
                account_pk,
                txi_scope,
                txi_cursor
              ),
              build_ext_contract_calls_stream(
                state,
                direction,
                account_pk,
                txi_scope,
                txi_cursor
              ),
              build_aexn_transfers_stream(state, direction, account_pk, txi_scope, txi_cursor)
            ]
            |> Collection.merge(direction)
            |> Stream.chunk_by(fn {txi, _data} -> txi end)
            |> build_txi_stream(state, direction)

          stream = Collection.merge([gens_stream, txi_stream], direction)

          if local_idx_cursor do
            Stream.drop_while(stream, fn
              {{^gen_cursor, txi, _local_idx}, _data} when direction == :forward ->
                txi < txi_cursor

              {{^gen_cursor, ^txi_cursor, local_idx}, _data} when direction == :forward ->
                local_idx < local_idx_cursor

              {{^gen_cursor, txi, _local_idx}, _data} when direction == :backward ->
                txi > txi_cursor

              {{^gen_cursor, ^txi_cursor, local_idx}, _data} when direction == :backward ->
                local_idx > local_idx_cursor

              _activity_pair ->
                false
            end)
          else
            stream
          end
        end
        |> Collection.paginate(pagination)

      events =
        Enum.map(activities_locators_data, fn {{height, txi, _local_idx}, data} ->
          render(state, account_pk, height, txi, data)
        end)

      {:ok, serialize_cursor(prev_cursor), events, serialize_cursor(next_cursor)}
    end
  end

  defp build_gens_stream(gen_activities, direction) do
    Stream.flat_map(gen_activities, fn [{height, _data} | _rest] = chunk ->
      gen_events =
        chunk
        |> Enum.with_index()
        |> Enum.map(fn {{^height, data}, local_idx} -> {{height, -1, local_idx}, data} end)

      if direction == :forward do
        gen_events
      else
        Enum.reverse(gen_events)
      end
    end)
  end

  defp build_int_transfers_stream(state, direction, account_pk, gen_scope, gen_cursor) do
    @kinds
    |> Enum.map(fn kind ->
      key_boundary =
        case gen_scope do
          {first_gen, last_gen} ->
            {
              {account_pk, kind, {first_gen, -1}, @min_int},
              {account_pk, kind, {last_gen, -1}, @max_int}
            }

          nil ->
            {
              {account_pk, kind, {@min_int, -1}, @min_int},
              {account_pk, kind, {@max_int, -1}, @max_int}
            }
        end

      cursor =
        case gen_cursor do
          nil -> nil
          gen -> {account_pk, kind, {gen, -1}, -1}
        end

      state
      |> Collection.stream(Model.TargetKindIntTransferTx, direction, key_boundary, cursor)
      |> Stream.filter(&match?({^account_pk, ^kind, {_height, -1}, _ref_txi}, &1))
      |> Stream.map(fn {^account_pk, ^kind, {height, -1}, ref_txi} ->
        {height, {:int_transfer, account_pk, kind, ref_txi}}
      end)
    end)
    |> Collection.merge(direction)
  end

  defp build_ext_contract_calls_stream(state, direction, account_pk, txi_scope, txi_cursor) do
    0..@max_pos
    |> Enum.map(fn pos ->
      key_boundary =
        case txi_scope do
          {first_txi, last_txi} ->
            {{account_pk, pos, first_txi, @min_int}, {account_pk, pos, last_txi, @max_int}}

          nil ->
            {{account_pk, pos, @min_int, nil}, {account_pk, pos, @max_int, nil}}
        end

      cursor =
        case txi_cursor do
          nil -> nil
          txi_cursor when direction == :forward -> {account_pk, pos, txi_cursor, @min_int}
          txi_cursor when direction == :backward -> {account_pk, pos, txi_cursor, @max_int}
        end

      state
      |> Collection.stream(Model.IdIntContractCall, direction, key_boundary, cursor)
      |> Stream.map(fn {^account_pk, ^pos, txi, local_idx} ->
        {txi, {:int_contract_call, local_idx}}
      end)
    end)
    |> Collection.merge(direction)
    |> Stream.dedup_by(fn {txi, {:int_contract_call, local_idx}} -> {txi, local_idx} end)
  end

  defp build_int_contract_calls_stream(state, direction, account_pk, txi_scope, txi_cursor) do
    case Origin.tx_index(state, {:contract, account_pk}) do
      {:ok, create_txi} ->
        key_boundary =
          case txi_scope do
            {first_txi, last_txi} ->
              {{create_txi, first_txi, @min_int}, {create_txi, last_txi, @max_int}}

            nil ->
              {{create_txi, @min_int, @min_int}, {create_txi, @max_int, @max_int}}
          end

        cursor =
          case txi_cursor do
            nil -> nil
            txi_cursor when direction == :forward -> {create_txi, txi_cursor, @min_int}
            txi_cursor when direction == :backward -> {create_txi, txi_cursor, @max_int}
          end

        state
        |> Collection.stream(Model.GrpIntContractCall, direction, key_boundary, cursor)
        |> Stream.map(fn {^create_txi, txi, local_idx} ->
          {txi, {:int_contract_call, local_idx}}
        end)

      :not_found ->
        []
    end
  end

  defp build_txs_stream(state, direction, account_pk, txi_scope, txi_cursor) do
    state
    |> Fields.account_fields_stream(account_pk, direction, txi_scope, txi_cursor)
    |> Stream.map(fn {txi, tx_type, tx_field_pos} -> {txi, {:field, tx_type, tx_field_pos}} end)
  end

  defp build_aexn_transfers_stream(state, direction, account_pk, txi_scope, txi_cursor) do
    transfers_stream =
      state
      |> build_aexn_transfer_stream(
        Model.AexnTransfer,
        direction,
        account_pk,
        txi_scope,
        txi_cursor
      )
      |> Stream.map(fn {aexn_type, ^account_pk, txi, to_pk, value, index} ->
        {txi, {:aexn, aexn_type, account_pk, to_pk, value, index}}
      end)

    rev_transfers_stream =
      state
      |> build_aexn_transfer_stream(
        Model.RevAexnTransfer,
        direction,
        account_pk,
        txi_scope,
        txi_cursor
      )
      |> Stream.map(fn {aexn_type, ^account_pk, txi, from_pk, value, index} ->
        {txi, {:aexn, aexn_type, from_pk, account_pk, value, index}}
      end)

    Collection.merge([transfers_stream, rev_transfers_stream], direction)
  end

  defp build_aexn_transfer_stream(state, table, direction, account_pk, txi_scope, txi_cursor) do
    @aexn_types
    |> Enum.map(fn aexn_type ->
      key_boundary =
        case txi_scope do
          nil ->
            {
              {aexn_type, account_pk, @min_int, @min_bin, @min_int, @min_int},
              {aexn_type, account_pk, @max_int, @max_bin, @max_int, @max_int}
            }

          {first_txi, last_txi} ->
            {
              {aexn_type, account_pk, first_txi, @min_bin, @min_int, @min_int},
              {aexn_type, account_pk, last_txi, @max_bin, @max_int, @max_int}
            }
        end

      cursor =
        case txi_cursor do
          nil ->
            nil

          txi when direction == :forward ->
            {aexn_type, account_pk, txi, @min_bin, @min_int, @min_int}

          txi when direction == :backward ->
            {aexn_type, account_pk, txi, @max_bin, @max_int, @max_int}
        end

      Collection.stream(state, table, direction, key_boundary, cursor)
    end)
    |> Collection.merge(direction)
  end

  defp build_txi_stream(txi_activities, state, direction) do
    Stream.flat_map(txi_activities, fn [{txi, _data} | _rest] = chunk ->
      Model.tx(block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, txi)

      txi_events =
        chunk
        |> Enum.sort()
        |> Enum.with_index()
        |> Enum.map(fn {{^txi, data}, local_idx} -> {{height, txi, local_idx}, data} end)

      if direction == :forward do
        txi_events
      else
        Enum.reverse(txi_events)
      end
    end)
  end

  @spec render(state(), Db.pubkey(), height(), txi(), activity_value()) :: map()
  defp render(state, _account_pk, height, txi, {:field, tx_type, _tx_pos}) do
    tx = state |> Txs.fetch!(txi) |> Map.delete("tx_index")

    %{
      height: height,
      type: "#{Node.tx_name(tx_type)}Event",
      payload: tx
    }
  end

  defp render(state, _account_pk, height, call_txi, {:int_contract_call, local_idx}) do
    payload =
      state
      |> Format.to_map({call_txi, local_idx}, Model.IntContractCall)
      |> Map.drop([:call_txi, :create_txi])

    %{
      height: height,
      type: "InternalContractCallEvent",
      payload: payload
    }
  end

  defp render(state, _account_pk, height, txi, {:aexn, :aex9, from_pk, to_pk, value, index}) do
    %{
      height: height,
      type: "Aex9TransferEvent",
      payload: render_aexn_payload(state, txi, from_pk, to_pk, value, index)
    }
  end

  defp render(state, account_pk, height, txi, {:int_transfer, kind, ref_txi}) do
    transfer_key = {{height, txi}, kind, account_pk, ref_txi}
    m_transfer = State.fetch!(state, Model.IntTransferTx, transfer_key)
    amount = Model.int_transfer_tx(m_transfer, :amount)
    ref_tx_hash = if ref_txi >= 0, do: Enc.encode(:tx_hash, Txs.txi_to_hash(state, ref_txi))

    %{
      height: height,
      type: "InternalTransferEvent",
      payload: %{
        amount: amount,
        kind: kind,
        ref_tx_hash: ref_tx_hash
      }
    }
  end

  defp render(state, _account_pk, height, txi, {:aexn, :aex141, from_pk, to_pk, value, index}) do
    %{
      height: height,
      type: "Aex141TransferEvent",
      payload: render_aexn_payload(state, txi, from_pk, to_pk, value, index)
    }
  end

  defp render_aexn_payload(state, txi, from_pk, to_pk, value, index) do
    %{
      from: Enc.encode(:account_pubkey, from_pk),
      to: Enc.encode(:account_pubkey, to_pk),
      value: value,
      log_index: index,
      tx_hash: Enc.encode(:tx_hash, Txs.txi_to_hash(state, txi))
    }
  end

  defp serialize_cursor(nil), do: nil

  defp serialize_cursor({{{height, txi, local_idx}, _data}, is_reversed?}),
    do: {"#{height}-#{txi + 1}-#{local_idx}", is_reversed?}

  defp deserialize_cursor(nil), do: {:ok, nil}

  defp deserialize_cursor(cursor) do
    case Regex.run(~r/\A(\d+)-(\d+)-(\d+)\z/, cursor, capture: :all_but_first) do
      [height, txi, local_idx] ->
        {:ok,
         {String.to_integer(height), String.to_integer(txi) - 1, String.to_integer(local_idx)}}

      nil ->
        {:error, ErrInput.Cursor.exception(value: cursor)}
    end
  end
end
