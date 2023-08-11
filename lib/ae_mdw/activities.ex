defmodule AeMdw.Activities do
  @moduledoc """
  Activities context module.
  """
  alias :aeser_api_encoder, as: Enc
  alias AeMdw.AexnTokens
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Contract
  alias AeMdw.Db.Format
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
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
  alias AeMdwWeb.AexnView

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
           | {:int_transfer, Txs.optional_txi_idx(), IntTransfer.kind(), Txs.optional_txi_idx()}
           | {:claim, Contract.local_idx()}
  @typep activity_type() :: String.t()

  @max_pos 4
  @min_int Util.min_int()
  @max_int Util.max_int()
  @min_bin Util.min_bin()
  @max_bin Util.max_256bit_bin()

  @gen_int_transfer_kinds ~w(accounts_extra_lima accounts_fortuna accounts_genesis accounts_lima accounts_minerva contracts_lima reward_dev reward_block fee_refund_oracle fee_lock_name)
  @txs_int_transfer_kinds ~w(fee_refund_name fee_spend_name reward_oracle fee_lock_name)
  @activity_stream_types %{
    "transactions" => ~w(transactions)a,
    "aexn" => ~w(aex9 aex141)a,
    "aex9" => ~w(aex9)a,
    "aex141" => ~w(aex141)a,
    "contract" => ~w(int_calls ext_calls)a,
    "transfers" => ~w(int_transfers)a,
    "claims" => ~w(claims)a
  }

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
  def fetch_account_activities(state, account, pagination, range, query, cursor) do
    with {:ok, account_pk} <- Validate.id(account),
         {:ok, cursor} <- deserialize_cursor(cursor),
         {:ok, filters} <- convert_params(query) do
      {prev_cursor, activities_locators_data, next_cursor} =
        fn direction ->
          {gen_scope, txi_scope} =
            case range do
              {:gen, first_gen..last_gen} ->
                {
                  {first_gen, last_gen},
                  {DbUtil.first_gen_to_txi(state, first_gen),
                   DbUtil.last_gen_to_txi(state, last_gen)}
                }

              nil ->
                {nil, nil}
            end

          {gen_cursor, txi_cursor, local_idx_cursor} =
            case cursor do
              {height, txi, local_idx} -> {height, txi, local_idx}
              nil -> {nil, nil, nil}
            end

          ownership_only? = Keyword.get(filters, :ownership_only?, false)
          stream_types = Keyword.get(filters, :stream_types)

          gens_stream =
            %{
              :int_transfers =>
                build_gens_int_transfers_stream(
                  state,
                  direction,
                  account_pk,
                  gen_scope,
                  gen_cursor,
                  ownership_only?
                )
            }
            |> filter_by_stream_types(stream_types)
            |> Collection.merge(direction)
            |> Stream.chunk_by(fn {gen, _data} -> gen end)
            |> build_gens_stream(direction)

          txi_stream =
            %{
              :transactions =>
                build_txs_stream(
                  state,
                  direction,
                  account_pk,
                  txi_scope,
                  txi_cursor,
                  ownership_only?
                ),
              :int_calls =>
                build_int_contract_calls_stream(
                  state,
                  direction,
                  account_pk,
                  txi_scope,
                  txi_cursor
                ),
              :ext_calls =>
                build_ext_contract_calls_stream(
                  state,
                  direction,
                  account_pk,
                  txi_scope,
                  txi_cursor,
                  ownership_only?
                ),
              :aex9 =>
                build_aexn_transfers_stream(
                  state,
                  direction,
                  account_pk,
                  :aex9,
                  txi_scope,
                  txi_cursor,
                  ownership_only?
                ),
              :aex141 =>
                build_aexn_transfers_stream(
                  state,
                  direction,
                  account_pk,
                  :aex141,
                  txi_scope,
                  txi_cursor,
                  ownership_only?
                ),
              :int_transfers =>
                build_txs_int_transfers_stream(
                  state,
                  direction,
                  account_pk,
                  gen_scope,
                  gen_cursor,
                  ownership_only?
                ),
              :claims =>
                build_name_claims_stream(state, direction, account_pk, txi_scope, txi_cursor)
            }
            |> filter_by_stream_types(stream_types)
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

      events = render_activities(state, account_pk, activities_locators_data)

      {:ok, serialize_cursor(prev_cursor), events, serialize_cursor(next_cursor)}
    end
  end

  defp filter_by_stream_types(streams_map, nil), do: Map.values(streams_map)

  defp filter_by_stream_types(streams_map, stream_types) do
    streams_map
    |> Enum.filter(fn {stream_type, _stream} -> stream_type in stream_types end)
    |> Enum.map(fn {_stream_type, stream} -> stream end)
  end

  defp render_activities(state, account_pk, activities_locators_data) do
    {activities_locators_data, _acc} =
      Enum.map_reduce(activities_locators_data, nil, fn
        {{_height, txi, _local_idx}, _data} = locator,
        {:txi, txi, enc_mb_hash, block_time} = block_info ->
          {{enc_mb_hash, block_time, locator}, block_info}

        {{height, -1, _local_idx}, _data} = locator,
        {:gen, height, enc_kb_hash, block_time} = block_info ->
          {{enc_kb_hash, block_time, locator}, block_info}

        {{height, -1, _local_idx}, _data} = locator, _block_info ->
          Model.block(hash: kb_hash) = State.fetch!(state, Model.Block, {height, -1})
          enc_kb_hash = Enc.encode(:key_block_hash, kb_hash)
          block_time = Db.get_block_time(kb_hash)

          {{enc_kb_hash, block_time, locator}, {:gen, height, enc_kb_hash, block_time}}

        {{_height, txi, _local_idx}, _data} = locator, _block_info ->
          Model.tx(block_index: block_index) = State.fetch!(state, Model.Tx, txi)
          Model.block(hash: mb_hash) = State.fetch!(state, Model.Block, block_index)
          enc_mb_hash = Enc.encode(:micro_block_hash, mb_hash)
          block_time = Db.get_block_time(mb_hash)

          {{enc_mb_hash, block_time, locator}, {:txi, txi, enc_mb_hash, block_time}}
      end)

    Enum.map(activities_locators_data, fn {block_hash, block_time,
                                           {{height, txi, _local_idx}, data}} ->
      {type, payload} = render_payload(state, account_pk, height, txi, data)

      %{
        height: height,
        block_hash: block_hash,
        block_time: block_time,
        type: type,
        payload: payload
      }
    end)
  end

  defp build_name_claims_stream(state, direction, name_hash, txi_scope, txi_cursor) do
    with {:ok, Model.plain_name(value: plain_name)} <-
           State.get(state, Model.PlainName, name_hash),
         {_record, source} <- Name.locate(state, plain_name) do
      claims =
        case source do
          Model.AuctionBid ->
            Name.stream_nested_resource(state, Model.AuctionBidClaim, plain_name)

          _name_table ->
            Name.stream_nested_resource(state, Model.NameClaim, plain_name)
        end

      claims = Enum.reverse(claims)

      claims =
        case txi_scope do
          nil ->
            claims

          {first_txi, last_txi} ->
            claims
            |> Enum.drop_while(fn {txi, _idx} -> txi < first_txi end)
            |> Enum.take_while(fn {txi, _idx} -> txi < last_txi end)
        end

      claims = if direction == :forward, do: claims, else: Enum.reverse(claims)

      claims =
        case txi_cursor do
          nil ->
            claims

          _txi_cursor ->
            Enum.drop_while(claims, fn
              {txi, _idx} when direction == :forward -> txi < txi_cursor
              {txi, _idx} when direction == :backward -> txi > txi_cursor
            end)
        end

      Stream.map(claims, fn {txi, idx} -> {txi, {:claim, idx}} end)
    else
      :not_found -> []
      nil -> []
    end
  end

  defp build_gens_stream(gen_activities, direction) do
    Stream.flat_map(gen_activities, fn [{height, _data} | _rest] = chunk ->
      gen_events =
        Enum.with_index(chunk, fn {^height, data}, local_idx ->
          {{height, -1, local_idx}, data}
        end)

      if direction == :forward do
        gen_events
      else
        Enum.reverse(gen_events)
      end
    end)
  end

  defp build_gens_int_transfers_stream(
         _state,
         _direction,
         _account_pk,
         _gen_scope,
         _gen_cursor,
         true = _ownership_only?
       ),
       do: []

  defp build_gens_int_transfers_stream(
         state,
         direction,
         account_pk,
         gen_scope,
         gen_cursor,
         false = _ownership_only?
       ) do
    @gen_int_transfer_kinds
    |> Enum.map(fn kind ->
      key_boundary =
        case gen_scope do
          {first_gen, last_gen} ->
            {
              {account_pk, kind, {first_gen, -1}, @min_int},
              {account_pk, kind, {last_gen, @max_int}, {@max_int, @max_int}}
            }

          nil ->
            {
              {account_pk, kind, {@min_int, -1}, @min_int},
              {account_pk, kind, {@max_int, @max_int}, {@max_int, @max_int}}
            }
        end

      cursor =
        case gen_cursor do
          nil -> nil
          gen -> {account_pk, kind, {gen, -1}, -1}
        end

      state
      |> Collection.stream(Model.TargetKindIntTransferTx, direction, key_boundary, cursor)
      |> Stream.filter(&match?({^account_pk, ^kind, {_height, -1}, _opt_ref_txi}, &1))
      |> Stream.map(fn {^account_pk, ^kind, {height, -1}, opt_ref_txi_idx} ->
        {height, {:int_transfer, -1, kind, opt_ref_txi_idx}}
      end)
    end)
    |> Collection.merge(direction)
  end

  defp build_txs_int_transfers_stream(
         _state,
         _direction,
         _account_pk,
         _gen_scope,
         _gen_cursor,
         true = _ownership_only?
       ),
       do: []

  defp build_txs_int_transfers_stream(
         state,
         direction,
         account_pk,
         gen_scope,
         gen_cursor,
         false = _ownership_only?
       ),
       do: build_txs_int_transfers_stream(state, direction, account_pk, gen_scope, gen_cursor)

  defp build_txs_int_transfers_stream(state, direction, account_pk, gen_scope, gen_cursor) do
    @txs_int_transfer_kinds
    |> Enum.map(fn kind ->
      key_boundary =
        case gen_scope do
          {first_gen, last_gen} ->
            {
              {account_pk, kind, {first_gen, 0}, @min_int},
              {account_pk, kind, {last_gen, @max_int}, {@max_int, @max_int}}
            }

          nil ->
            {
              {account_pk, kind, {@min_int, 0}, @min_int},
              {account_pk, kind, {@max_int, {@max_int, @max_int}}, {@max_int, @max_int}}
            }
        end

      cursor =
        case gen_cursor do
          nil ->
            nil

          gen when direction == :forward ->
            {account_pk, kind, {gen, @min_int}, @min_int}

          gen when direction == :backward ->
            {account_pk, kind, {gen, {@max_int, @max_int}}, {@max_int, @max_int}}
        end

      state
      |> Collection.stream(Model.TargetKindIntTransferTx, direction, key_boundary, cursor)
      |> Stream.reject(&match?({^account_pk, ^kind, {_height, -1}, _ref_txi}, &1))
      |> Stream.map(fn {^account_pk, ^kind, {_height, {txi, _idx} = txi_idx}, opt_ref_txi_idx} ->
        {txi, {:int_transfer, txi_idx, kind, opt_ref_txi_idx}}
      end)
    end)
    |> Collection.merge(direction)
  end

  defp build_ext_contract_calls_stream(
         _state,
         _direction,
         _account_pk,
         _txi_scope,
         _txi_cursor,
         true = _ownership_only?
       ),
       do: []

  defp build_ext_contract_calls_stream(
         state,
         direction,
         account_pk,
         txi_scope,
         txi_cursor,
         false = _ownership_only?
       ),
       do: build_ext_contract_calls_stream(state, direction, account_pk, txi_scope, txi_cursor)

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

  defp build_txs_stream(state, direction, account_pk, txi_scope, txi_cursor, ownership_only?) do
    state
    |> Fields.account_fields_stream(account_pk, direction, txi_scope, txi_cursor, ownership_only?)
    |> Stream.dedup_by(fn {txi, _tx_type, _tx_field_pos} -> txi end)
    |> Stream.map(fn {txi, tx_type, tx_field_pos} -> {txi, {:field, tx_type, tx_field_pos}} end)
  end

  defp build_aexn_transfers_stream(
         state,
         direction,
         account_pk,
         aexn_type,
         txi_scope,
         txi_cursor,
         ownership_only?
       ) do
    transfers_stream =
      state
      |> build_aexn_transfer_stream(
        Model.AexnTransfer,
        aexn_type,
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
        aexn_type,
        direction,
        account_pk,
        txi_scope,
        txi_cursor
      )
      |> Stream.map(fn {aexn_type, ^account_pk, txi, from_pk, value, index} ->
        {txi, {:aexn, aexn_type, from_pk, account_pk, value, index}}
      end)

    stream = Collection.merge([transfers_stream, rev_transfers_stream], direction)

    if ownership_only? do
      Stream.filter(stream, fn {txi, _locator} ->
        # if owned by, only allow transactions in which the account of the contractcalltx = account_pk
        account_pk == DbUtil.call_account_pk(state, txi)
      end)
    else
      stream
    end
  end

  defp build_aexn_transfer_stream(
         state,
         table,
         aexn_type,
         direction,
         account_pk,
         txi_scope,
         txi_cursor
       ) do
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
  end

  defp build_txi_stream(txi_activities, state, direction) do
    Stream.flat_map(txi_activities, fn [{txi, _data} | _rest] = chunk ->
      Model.tx(block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, txi)

      txi_events =
        chunk
        |> Enum.sort()
        |> Enum.with_index(fn {^txi, data}, local_idx -> {{height, txi, local_idx}, data} end)

      if direction == :forward do
        txi_events
      else
        Enum.reverse(txi_events)
      end
    end)
  end

  @spec render_payload(state(), Db.pubkey(), height(), txi(), activity_value()) ::
          {activity_type(), map()}
  defp render_payload(state, _account_pk, _height, txi, {:field, tx_type, _tx_pos}) do
    tx = state |> Txs.fetch!(txi) |> Map.delete("tx_index")

    {"#{Node.tx_name(tx_type)}Event", tx}
  end

  defp render_payload(state, _account_pk, _height, txi, {:claim, local_idx}) do
    Model.tx(time: micro_time) = State.fetch!(state, Model.Tx, txi)

    {claim_aetx, :name_claim_tx, tx_hash, tx_type, _block_hash} =
      DbUtil.read_node_tx_details(state, {txi, local_idx})

    payload = %{
      micro_time: micro_time,
      source_tx_hash: Enc.encode(:tx_hash, tx_hash),
      source_tx_type: Format.type_to_swagger_name(tx_type),
      tx: :aens_claim_tx.for_client(claim_aetx)
    }

    {"NameClaimEvent", payload}
  end

  defp render_payload(state, _account_pk, _height, call_txi, {:int_contract_call, local_idx}) do
    payload =
      state
      |> Format.to_map({call_txi, local_idx}, Model.IntContractCall)
      |> Map.drop([:call_txi, :create_txi])

    {"InternalContractCallEvent", payload}
  end

  defp render_payload(
         state,
         account_pk,
         height,
         _txi,
         {:int_transfer, opt_txi_idx, kind, opt_ref_txi_idx}
       ) do
    transfer_key = {{height, opt_txi_idx}, kind, account_pk, opt_ref_txi_idx}
    m_transfer = State.fetch!(state, Model.IntTransferTx, transfer_key)
    amount = Model.int_transfer_tx(m_transfer, :amount)

    ref_tx_hash =
      case opt_ref_txi_idx do
        -1 -> nil
        {txi, _idx} -> Enc.encode(:tx_hash, Txs.txi_to_hash(state, txi))
      end

    payload = %{
      amount: amount,
      kind: kind,
      ref_tx_hash: ref_tx_hash
    }

    {"InternalTransferEvent", payload}
  end

  defp render_payload(
         state,
         _account_pk,
         _height,
         txi,
         {:aexn, :aex9, from_pk, to_pk, value, index}
       ) do
    payload =
      state
      |> AexnView.sender_transfer_to_map({:aex9, from_pk, txi, to_pk, value, index})
      |> Map.delete(:call_txi)
      |> Util.map_rename(:sender, :sender_id)
      |> Util.map_rename(:recipient, :recipient_id)

    {"Aex9TransferEvent", payload}
  end

  defp render_payload(
         state,
         _account_pk,
         _height,
         txi,
         {:aexn, :aex141, from_pk, to_pk, value, index}
       ) do
    payload =
      state
      |> AexnView.sender_transfer_to_map({:aex141, from_pk, txi, to_pk, value, index})
      |> Map.delete(:call_txi)
      |> Util.map_rename(:sender, :sender_id)
      |> Util.map_rename(:recipient, :recipient_id)

    {"Aex141TransferEvent", payload}
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

  defp convert_params(query) do
    Enum.reduce_while(query, {:ok, []}, fn param, {:ok, filters} ->
      case convert_param(param) do
        {:ok, filter} -> {:cont, {:ok, [filter | filters]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp convert_param({"owned_only", val}), do: {:ok, {:ownership_only?, val != "false"}}

  defp convert_param({"type", val}) do
    case Map.fetch(@activity_stream_types, val) do
      {:ok, stream_types} -> {:ok, {:stream_types, stream_types}}
      :error -> {:error, ErrInput.Query.exception(value: "type=#{val}")}
    end
  end

  defp convert_param(other_param), do: {:error, ErrInput.Query.exception(value: other_param)}
end
