defmodule AeMdw.Activities do
  @moduledoc """
  Activities context module.
  """
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Fields
  alias AeMdw.Node
  alias AeMdw.Txs
  alias AeMdw.Validate

  require Model

  @type activity() :: map()

  @typep state() :: State.t()
  @typep pagination() :: Collection.direction_limit()
  @typep range() :: {:gen, Range.t()} | nil
  @typep query() :: map()
  @typep cursor() :: binary() | nil
  @typep txi() :: Txs.txi()
  @typep activity_key() :: {Blocks.height(), txi(), non_neg_integer()}
  @typep activity_value() :: {:field, Node.tx_type(), non_neg_integer() | nil}
  @typep activity_pair() :: {activity_key(), activity_value()}

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

  * `{{10, -1, 0}, :block_mined}` - The first activity belonging to the key block 10.
  * `{{10, 40, 0}, {:field, :spend_tx, 1}}` - The first activity belonging to the transaction with txi 40 (from height 10),
     where the first field of the spend transaction is the account's being queried.

  """
  @spec fetch_account_activities(state(), binary(), pagination(), range(), query(), cursor()) ::
          {:ok, activity() | nil, [activity()], activity() | nil} | {:error, Error.t()}
  def fetch_account_activities(state, account, pagination, range, _query, cursor) do
    with {:ok, account_pk} <- Validate.id(account),
         {:ok, cursor} <- deserialize_cursor(cursor) do
      {prev_cursor, activities_locators_data, next_cursor} =
        fn direction ->
          gens_stream = build_gens_stream(state, direction, account_pk, range, cursor)
          txs_stream = build_txs_stream(state, direction, account_pk, range, cursor)

          Collection.merge([txs_stream, gens_stream], direction)
        end
        |> Collection.paginate(pagination)

      {:ok, serialize_cursor(prev_cursor), Enum.map(activities_locators_data, &render(state, &1)),
       serialize_cursor(next_cursor)}
    end
  end

  defp build_gens_stream(_state, _direction, _account_pk, _range, _cursor) do
    []
  end

  defp build_txs_stream(state, direction, account_pk, range, cursor) do
    {txi_cursor, local_idx_cursor} =
      case cursor do
        {_height, txi, local_idx} -> {txi, local_idx}
        nil -> {nil, nil}
      end

    stream =
      state
      |> Fields.account_fields_stream(account_pk, direction, range, txi_cursor)
      |> Stream.transform({-1, -1, -1}, fn
        {txi, tx_type, tx_field_pos}, {txi, height, local_idx} ->
          {[{{height, txi, local_idx + 1}, {:field, tx_type, tx_field_pos}}],
           {txi, height, local_idx + 1}}

        {txi, tx_type, tx_field_pos}, _acc ->
          Model.tx(block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, txi)

          {[{{height, txi, 0}, {:field, tx_type, tx_field_pos}}], {txi, height, 0}}
      end)

    if local_idx_cursor do
      Stream.drop_while(stream, fn
        {{_height, ^txi_cursor, local_idx}, _data} when direction == :forward ->
          local_idx < local_idx_cursor

        {{_height, ^txi_cursor, local_idx}, _data} when direction == :backward ->
          local_idx > local_idx_cursor

        _activity_pair ->
          false
      end)
    else
      stream
    end
  end

  @spec render(state(), activity_pair()) :: map()
  defp render(state, {{height, txi, _local_idx}, {:field, tx_type, _tx_pos}}) do
    tx = state |> Txs.fetch!(txi) |> Map.delete("tx_index")

    %{
      height: height,
      type: "#{Node.tx_name(tx_type)}Event",
      payload: tx
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
