defmodule AeMdwWeb.GraphQL.Resolvers.NameResolver do
  @moduledoc """
  GraphQL resolvers for Names domain (initial subset: names, namesCount, name).

  Roadmap: extend with history, claims, transfers, updates, auctions, search, pointees.
  """
  alias AeMdw.Names
  alias AeMdw.Db.State

  # Internal clamp to avoid excessive loads until complexity limits added
  @max_limit 100

  @type page_tuple :: {String.t() | nil, list(), String.t() | nil}

  @spec names(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def names(_parent, args, %{context: %{state: %State{} = state}}) do
    limit = args |> Map.get(:limit, 20) |> clamp_limit()
    cursor = Map.get(args, :cursor)
    order_by = Map.get(args, :order_by, :expiration)

    query =
      %{}
      |> maybe_put("owned_by", Map.get(args, :owned_by))
      |> maybe_put("state", Map.get(args, :state) && to_string(Map.get(args, :state)))
      |> maybe_put("prefix", Map.get(args, :prefix))

    pagination = {:backward, false, limit, not is_nil(cursor)}

    with {:ok, {prev, list, next}} <- Names.fetch_names(state, pagination, nil, order_by, query, cursor, [{:render_v3?, true}]) do
      {:ok, %{
        prev_cursor: cursor_to_str(prev),
        next_cursor: cursor_to_str(next),
        data: Enum.map(list, &normalize_name/1)
      }}
    else
      {:error, _reason} -> {:error, "invalid_query"}
      _ -> {:error, "unknown_error"}
    end
  end
  def names(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec names_count(any, map(), Absinthe.Resolution.t()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def names_count(_parent, args, %{context: %{state: %State{} = state}}) do
    query =
      %{}
      |> maybe_put("owned_by", Map.get(args, :owned_by))
      |> maybe_put("state", Map.get(args, :state) && to_string(Map.get(args, :state)))
      |> maybe_put("prefix", Map.get(args, :prefix))

    case Names.count_names(state, query) do
      {:ok, count} -> {:ok, count}
      {:error, _} -> {:error, "invalid_query"}
    end
  end
  def names_count(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec name(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def name(_parent, %{id: id}, %{context: %{state: %State{} = state}}) do
    # Accept plain name or name hash; backend handles
    case Names.fetch_name(state, id, [{:render_v3?, true}]) do
      {:ok, name_map} -> {:ok, normalize_name(name_map)}
      {:error, _} -> {:error, "name_not_found"}
    end
  end
  def name(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec name_history(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def name_history(_parent, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = args |> Map.get(:limit, 20) |> clamp_limit()
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}
    with {:ok, {prev, list, next}} <- Names.fetch_name_history(state, pagination, id, cursor) do
      data = Enum.map(list, &history_item_to_graphql/1)
      {:ok, %{prev_cursor: cursor_to_str(prev), next_cursor: cursor_to_str(next), data: data}}
    else
      {:error, _} -> {:error, "name_not_found"}
      _ -> {:error, "unknown_error"}
    end
  end
  def name_history(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec name_claims(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def name_claims(_parent, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = args |> Map.get(:limit, 20) |> clamp_limit()
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}
    with {:ok, {prev, list, next}} <- Names.fetch_name_claims(state, id, pagination, nil, cursor) do
      data = Enum.map(list, &history_item_to_graphql/1)
      {:ok, %{prev_cursor: cursor_to_str(prev), next_cursor: cursor_to_str(next), data: data}}
    else
      {:error, _} -> {:error, "name_not_found"}
      _ -> {:error, "unknown_error"}
    end
  end
  def name_claims(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec name_updates(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def name_updates(_parent, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = args |> Map.get(:limit, 20) |> clamp_limit()
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}
    with {:ok, {prev, list, next}} <- Names.fetch_name_updates(state, id, pagination, nil, cursor) do
      data = Enum.map(list, &history_item_to_graphql/1)
      {:ok, %{prev_cursor: cursor_to_str(prev), next_cursor: cursor_to_str(next), data: data}}
    else
      {:error, _} -> {:error, "name_not_found"}
      _ -> {:error, "unknown_error"}
    end
  end
  def name_updates(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec name_transfers(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def name_transfers(_parent, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = args |> Map.get(:limit, 20) |> clamp_limit()
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}
    with {:ok, {prev, list, next}} <- Names.fetch_name_transfers(state, id, pagination, nil, cursor) do
      data = Enum.map(list, &history_item_to_graphql/1)
      {:ok, %{prev_cursor: cursor_to_str(prev), next_cursor: cursor_to_str(next), data: data}}
    else
      {:error, _} -> {:error, "name_not_found"}
      _ -> {:error, "unknown_error"}
    end
  end
  def name_transfers(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec auction(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def auction(_parent, %{id: id}, %{context: %{state: %State{} = state}}) do
    case AeMdw.AuctionBids.fetch_auction(state, id, [{:render_v3?, true}]) do
      {:ok, auc} -> {:ok, auction_to_graphql(auc)}
      {:error, _} -> {:error, "auction_not_found"}
    end
  end
  def auction(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec auctions(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def auctions(_parent, args, %{context: %{state: %State{} = state}}) do
    limit = args |> Map.get(:limit, 20) |> clamp_limit()
    cursor = Map.get(args, :cursor)
    order_by = Map.get(args, :order_by, :expiration)
    pagination = {:backward, false, limit, not is_nil(cursor)}
    with {:ok, {prev, list, next}} <- AeMdw.AuctionBids.fetch_auctions(state, pagination, order_by, cursor, [{:render_v3?, true}]) do
      data = Enum.map(list, &auction_to_graphql/1)
      {:ok, %{prev_cursor: cursor_to_str(prev), next_cursor: cursor_to_str(next), data: data}}
    else
      {:error, _} -> {:error, "invalid_query"}
    end
  end
  def auctions(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec search_names(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def search_names(_p, args, %{context: %{state: %State{} = state}}) do
    prefix = Map.get(args, :prefix, "")
    only = Map.get(args, :only, []) |> Enum.map(&String.to_atom/1)
    limit = args |> Map.get(:limit, 20) |> clamp_limit()
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}
    case Names.search_names(state, only, prefix, pagination, cursor, [{:render_v3?, true}]) do
      {:ok, {prev, list, next}} ->
        data = Enum.map(list, &search_entry_to_graphql/1)
        {:ok, %{prev_cursor: cursor_to_str(prev), next_cursor: cursor_to_str(next), data: data}}
      {:error, _} ->
        {:error, "invalid_query"}
      other ->
        # Treat unexpected shapes as empty result rather than crashing
        _ = other
        {:ok, %{prev_cursor: nil, next_cursor: nil, data: []}}
    end
  end
  def search_names(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec account_pointees(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def account_pointees(_p, %{id: id} = args, %{context: %{state: %State{} = state}}) do
    limit = args |> Map.get(:limit, 20) |> clamp_limit()
    cursor = Map.get(args, :cursor)
    pagination = {:backward, false, limit, not is_nil(cursor)}
    # scope not yet supported via GraphQL (future: gen range)
    case Names.fetch_pointees(state, id, pagination, nil, cursor) do
      {:ok, {prev, list, next}} ->
        data = Enum.map(list, &pointee_to_graphql/1)
        {:ok, %{prev_cursor: cursor_to_str(prev), next_cursor: cursor_to_str(next), data: data}}
      {:error, _} -> {:error, "invalid_account"}
    end
  end
  def account_pointees(_, _args, _), do: {:error, "partial_state_unavailable"}

  @spec name_pointees(any, map(), Absinthe.Resolution.t()) :: {:ok, map()} | {:error, String.t()}
  def name_pointees(_p, %{id: id}, %{context: %{state: %State{} = state}}) do
    with {:ok, name_hash} <- AeMdw.Validate.name_id(id) do
      {active, inactive} = AeMdw.Db.Name.pointees(state, name_hash)
      {:ok, %{
        active: map_pointee_set(active),
        inactive: map_pointee_set(inactive)
      }}
    else
      _ -> {:error, "invalid_name"}
    end
  end
  def name_pointees(_, _args, _), do: {:error, "partial_state_unavailable"}

  # -- helpers --
  defp clamp_limit(l) when is_integer(l) and l > @max_limit, do: @max_limit
  defp clamp_limit(l) when is_integer(l) and l > 0, do: l
  defp clamp_limit(_), do: 20

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, _k, ""), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  # The REST layer returns snake_case keys already; ensure expected optional keys exist
  defp normalize_name(name_map) do
    name_map
    |> Map.put_new(:claims_count, Map.get(name_map, :claims_count) || Map.get(name_map, "claims_count"))
  end

  defp cursor_to_str(nil), do: nil
  defp cursor_to_str({val, _rev?}) when is_binary(val), do: val
  defp cursor_to_str(other) when is_binary(other), do: other
  defp cursor_to_str(_), do: nil

  defp history_item_to_graphql(item) do
    # Convert map keys & encode tx if present
    tx = Map.get(item, :tx) || Map.get(item, "tx")
    tx_json = if is_map(tx), do: Jason.encode!(tx), else: nil
    %{
      active_from: Map.get(item, :active_from) || Map.get(item, "active_from"),
      expired_at: Map.get(item, :expired_at) || Map.get(item, "expired_at"),
      height: Map.get(item, :height) || Map.get(item, "height"),
      block_hash: Map.get(item, :block_hash) || Map.get(item, "block_hash"),
      source_tx_hash: Map.get(item, :source_tx_hash) || Map.get(item, "source_tx_hash"),
      source_tx_type: Map.get(item, :source_tx_type) || Map.get(item, "source_tx_type"),
      internal_source: Map.get(item, :internal_source) || Map.get(item, "internal_source"),
      tx: tx_json
    }
  end

  defp auction_to_graphql(auc) do
    # auc already a map with atom/string keys
    %{
      name: Map.get(auc, :name) || Map.get(auc, "name"),
      activation_time: Map.get(auc, :activation_time) || Map.get(auc, "activation_time"),
      auction_end: Map.get(auc, :auction_end) || Map.get(auc, "auction_end"),
      approximate_expire_time: Map.get(auc, :approximate_expire_time) || Map.get(auc, "approximate_expire_time"),
      name_fee: Map.get(auc, :name_fee) || Map.get(auc, "name_fee"),
      claims_count: Map.get(auc, :claims_count) || Map.get(auc, "claims_count"),
      last_bid: (Map.get(auc, :last_bid) || Map.get(auc, "last_bid")) |> encode_tx_json()
    }
  end

  defp search_entry_to_graphql(%{"type" => "auction", "payload" => auc}), do: %{type: "auction", auction: auction_to_graphql(auc), name: Map.get(auc, :name) || Map.get(auc, "name")}
  defp search_entry_to_graphql(%{"type" => "name", "payload" => name}), do: %{type: "name", name: Map.get(name, :name) || Map.get(name, "name"), active: Map.get(name, :active) || Map.get(name, "active")}

  defp encode_tx_json(nil), do: nil
  defp encode_tx_json(map) when is_map(map), do: Jason.encode!(map)
  defp encode_tx_json(other), do: other

  defp pointee_to_graphql(p) do
    %{
      name: Map.get(p, :name) || Map.get(p, "name"),
      active: Map.get(p, :active) || Map.get(p, "active"),
      key: Map.get(p, :key) || Map.get(p, "key"),
      block_height: Map.get(p, :block_height) || Map.get(p, "block_height"),
      block_hash: Map.get(p, :block_hash) || Map.get(p, "block_hash"),
      block_time: Map.get(p, :block_time) || Map.get(p, "block_time"),
      source_tx_hash: Map.get(p, :source_tx_hash) || Map.get(p, "source_tx_hash"),
      source_tx_type: Map.get(p, :source_tx_type) || Map.get(p, "source_tx_type"),
      tx: (Map.get(p, :tx) || Map.get(p, "tx")) |> encode_tx_json()
    }
  end

  defp map_pointee_set(raw_map) when is_map(raw_map) do
    Enum.map(raw_map, fn {k, v} -> %{key: k, id: AeMdw.Db.Format.to_json(v)} end)
  end
  defp map_pointee_set(_), do: []
end
