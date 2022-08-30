defmodule AeMdw.Fields do
  @moduledoc """
  A simple fields querying API to filter transactions by type and/or ID.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Node
  alias AeMdw.Node.Db
  alias AeMdw.Txs
  alias AeMdw.Util

  @typep state() :: State.t()
  @typep pubkey() :: Db.pubkey()
  @typep direction() :: Collection.direction()
  @typep range() :: {:gen, Range.t()} | nil
  @typep cursor() :: Txs.tx() | nil

  @create_tx_types ~w(contract_create_tx channel_create_tx oracle_register_tx name_claim_tx ga_attach_tx)a

  @spec account_fields_stream(state(), pubkey(), direction(), range(), cursor()) :: Enumerable.t()
  def account_fields_stream(state, account_pk, direction, range, cursor) do
    scope =
      case range do
        {:gen, %Range{first: first_gen, last: last_gen}} ->
          {DbUtil.first_gen_to_txi(state, first_gen, direction),
           DbUtil.last_gen_to_txi(state, last_gen, direction)}

        nil ->
          nil
      end

    Node.tx_types()
    |> Enum.flat_map(fn tx_type ->
      types_pos =
        tx_type
        |> Node.tx_ids()
        |> Enum.map(fn {_field, pos} -> {tx_type, pos} end)

      if tx_type in @create_tx_types do
        [{tx_type, nil} | types_pos]
      else
        types_pos
      end
    end)
    |> Enum.map(fn {tx_type, tx_field_pos} ->
      scope =
        case scope do
          {first_txi, last_txi} ->
            {{tx_type, tx_field_pos, account_pk, first_txi},
             {tx_type, tx_field_pos, account_pk, last_txi}}

          nil ->
            {{tx_type, tx_field_pos, account_pk, Util.min_int()},
             {tx_type, tx_field_pos, account_pk, Util.max_256bit_int()}}
        end

      cursor = if cursor, do: {tx_type, tx_field_pos, account_pk, cursor}

      state
      |> Collection.stream(Model.Field, direction, scope, cursor)
      |> Stream.map(fn {^tx_type, ^tx_field_pos, ^account_pk, txi} ->
        {txi, tx_type, tx_field_pos}
      end)
    end)
    |> Collection.merge(direction)
  end
end
