defmodule AeMdw.ActiveEntities do
  @moduledoc """
  Context module for dealing with active entities (e.g. active auctions).
  """

  alias AeMdw.Db.Origin
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Error
  alias AeMdw.Error.Input, as: ErrInput
  alias AeMdw.Collection
  alias AeMdw.Node
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

  import AeMdw.Util.Encoding

  @type cursor :: Collection.pagination_cursor()
  @type entity :: term()
  @type query :: %{binary() => binary()}

  @typep pagination :: Collection.direction_limit()
  @typep scope :: {:gen, Range.t()} | {:txi, Range.t()} | nil

  @min_txi 0
  @max_txi Util.max_int()

  @tx_table Model.ActiveEntity
  @contract_table Model.ContractEntity

  @spec fetch_entities(State.t(), pagination(), scope(), query(), cursor()) ::
          {:ok, {cursor(), [entity()], cursor()}} | {:error, Error.t()}
  def fetch_entities(state, pagination, scope, query, cursor) do
    scope = deserialize_scope(state, scope)

    with {:ok, cursor} <- deserialize_cursor(cursor),
         {:ok, filters} <- Util.convert_params(query, &convert_param(state, &1)) do
      paginated_entities =
        filters
        |> build_streamer(state, scope, cursor)
        |> Collection.paginate(pagination, &render(state, &1), &serialize_cursor/1)

      {:ok, paginated_entities}
    end
  end

  defp convert_param(state, {"type", entity}) do
    case State.next(state, Model.ActiveEntity, {entity, @min_txi, @min_txi}) do
      {:ok, {^entity, _txi, _create_txi}} -> {:ok, {:entity, entity}}
      _not_found -> {:error, ErrInput.NotFound.exception(value: entity)}
    end
  end

  defp convert_param(state, {"contract", contract_id}) do
    with {:ok, pubkey} <- Validate.id(contract_id, [:contract_pubkey]) do
      case Origin.tx_index(state, {:contract, pubkey}) do
        {:ok, create_txi} -> {:ok, {:create_txi, create_txi}}
        :not_found -> {:error, ErrInput.NotFound.exception(value: contract_id)}
      end
    end
  end

  defp convert_param(_state, other_param),
    do: {:error, ErrInput.Query.exception(value: other_param)}

  defp build_streamer(
         %{entity: entity, create_txi: create_txi},
         state,
         {first_txi, last_txi},
         cursor
       ) do
    cursor =
      with {^entity, txi, ^create_txi} <- cursor do
        {entity, create_txi, txi}
      end

    boundary = {{entity, create_txi, first_txi}, {entity, create_txi, last_txi}}

    fn direction ->
      state
      |> Collection.stream(@contract_table, direction, boundary, cursor)
      |> Stream.map(fn {^entity, ^create_txi, txi} ->
        {entity, txi, create_txi}
      end)
    end
  end

  defp build_streamer(%{entity: entity}, state, {first_txi, last_txi}, cursor) do
    boundary = {{entity, first_txi, @min_txi}, {entity, last_txi, @max_txi}}

    fn direction ->
      state
      |> Collection.stream(@tx_table, direction, boundary, cursor)
      |> Stream.map(fn {^entity, txi, create_txi} ->
        {entity, txi, create_txi}
      end)
    end
  end

  defp render(state, {_entity, txi, create_txi}) do
    {tx_rec, tx_type, tx_hash, chain_tx_type, block_hash} =
      DbUtil.read_node_tx_details(state, {txi, -1})

    Model.contract_call(fun: entrypoint, args: args) =
      State.fetch!(state, Model.ContractCall, {create_txi, txi})

    Model.tx(block_index: {height, _mbi}) = State.fetch!(state, Model.Tx, txi)

    node_tx = Node.tx_mod(tx_type).for_client(tx_rec)

    %{
      height: height,
      block_hash: encode(:micro_block_hash, block_hash),
      source_tx_hash: encode(:tx_hash, tx_hash),
      source_tx_type: Node.tx_name(chain_tx_type),
      internal_source: chain_tx_type != tx_type,
      tx:
        Map.merge(node_tx, %{
          function: entrypoint,
          arguments: args
        })
    }
  end

  defp deserialize_scope(_state, nil), do: {@min_txi, @max_txi}

  defp deserialize_scope(state, {:gen, first_gen..last_gen//_step}) do
    first = DbUtil.gen_to_txi(state, first_gen)
    last = DbUtil.gen_to_txi(state, last_gen + 1) - 1
    deserialize_scope(state, {:txi, first..last})
  end

  defp deserialize_scope(_state, {:txi, first_txi..last_txi//_step}), do: {first_txi, last_txi}

  defp deserialize_cursor(nil), do: {:ok, nil}

  defp deserialize_cursor(cursor) do
    with {:ok, cursor_bin} <- Base.hex_decode32(cursor, padding: false),
         {entity, txi, create_txi} <- :erlang.binary_to_term(cursor_bin) do
      {:ok, {entity, txi, create_txi}}
    else
      _invalid_cursor ->
        {:error, ErrInput.Cursor.exception(value: cursor)}
    end
  end

  defp serialize_cursor({entity, txi, create_txi}) do
    {entity, txi, create_txi}
    |> :erlang.term_to_binary()
    |> Base.hex_encode32(padding: false)
  end
end
