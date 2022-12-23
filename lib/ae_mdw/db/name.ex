defmodule AeMdw.Db.Name do
  @moduledoc """
  Retrieves name information from database in regards to:
    - name state
    - expiration
    - plain_name
    - owner
    - pointee
    - auction_bid

  All name related data models are read and written by cache through operations.
  """
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Node.Db
  alias AeMdw.Db.Model
  alias AeMdw.Db.Format
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Names
  alias AeMdw.Validate

  require Model

  import AeMdw.Util

  @typep pubkey :: Db.pubkey()
  @typep state() :: State.t()

  @spec plain_name(State.t(), binary()) :: {:ok, String.t()} | nil
  def plain_name(state, name_hash) do
    case State.get(state, Model.PlainName, name_hash) do
      {:ok, Model.plain_name(value: value)} -> {:ok, value}
      :not_found -> nil
    end
  end

  @spec plain_name!(State.t(), binary()) :: String.t()
  def plain_name!(state, name_hash),
    do: Model.plain_name(State.fetch!(state, Model.PlainName, name_hash), :value)

  @spec ptr_resolve!(state(), Blocks.block_index(), binary(), String.t()) :: binary()
  def ptr_resolve!(state, block_index, name_hash, key) do
    key
    |> :aens.resolve_hash(name_hash, ns_tree!(state, block_index))
    |> map_ok!(&Validate.id!/1)
  end

  @spec owned_by(state(), owner_pk :: pubkey(), active? :: boolean()) :: %{
          :names => list(),
          :top_bids => list()
        }
  def owned_by(state, owner_pk, true) do
    %{
      names: collect_vals(state, Model.ActiveNameOwner, owner_pk),
      top_bids: collect_vals(state, Model.AuctionOwner, owner_pk)
    }
  end

  def owned_by(state, owner_pk, false) do
    %{
      names: collect_vals(state, Model.InactiveNameOwner, owner_pk)
    }
  end

  @doc """
  Returns a stream of Names.plain_name()
  """
  @spec list_inactivated_at(state(), Blocks.height()) :: Enumerable.t()
  def list_inactivated_at(state, height) do
    state
    |> Collection.stream(
      Model.InactiveNameExpiration,
      :forward,
      {{height, <<>>}, {height + 1, <<>>}},
      nil
    )
    |> Stream.map(fn {_height, plain_name} -> plain_name end)
  end

  @spec source(AeMdw.Db.Model.ActiveName | AeMdw.Db.Model.InactiveName, :expiration | :name) ::
          AeMdw.Db.Model.ActiveName
          | AeMdw.Db.Model.ActiveNameExpiration
          | AeMdw.Db.Model.InactiveName
          | AeMdw.Db.Model.InactiveNameExpiration
  def source(Model.ActiveName, :name), do: Model.ActiveName
  def source(Model.ActiveName, :expiration), do: Model.ActiveNameExpiration
  def source(Model.InactiveName, :name), do: Model.InactiveName
  def source(Model.InactiveName, :expiration), do: Model.InactiveNameExpiration

  @spec locate_bid(state(), Names.plain_name()) :: Model.auction_bid() | nil
  def locate_bid(state, plain_name) do
    case State.get(state, Model.AuctionBid, plain_name) do
      {:ok, auction_bid} -> auction_bid
      :not_found -> nil
    end
  end

  @spec locate(state(), Names.plain_name()) ::
          {Model.name(), Model.ActiveName | Model.InactiveName}
          | {Model.auction_bid(), Model.AuctionBid}
          | nil
  def locate(state, plain_name) do
    with {:active, :not_found} <- {:active, State.get(state, Model.ActiveName, plain_name)},
         {:inactive, :not_found} <- {:inactive, State.get(state, Model.InactiveName, plain_name)},
         {:auction_bid, nil} <- {:auction_bid, locate_bid(state, plain_name)} do
      nil
    else
      {:active, {:ok, active_name}} -> {active_name, Model.ActiveName}
      {:inactive, {:ok, inactive_name}} -> {inactive_name, Model.InactiveName}
      {:auction_bid, auction} -> {auction, Model.AuctionBid}
    end
  end

  @spec pointers(state(), Model.name()) :: map()
  def pointers(_state, Model.name(updates: [])), do: %{}

  def pointers(state, Model.name(updates: [{_block_index, txi_idx} | _rest_updates])) do
    state
    |> DbUtil.read_node_tx(txi_idx)
    |> :aens_update_tx.pointers()
    |> Enum.into(%{}, &pointer_kv_raw/1)
    |> Format.encode_pointers()
  end

  @spec ownership(state(), Model.name()) :: %{
          current: Format.aeser_id(),
          original: Format.aeser_id()
        }
  def ownership(_state, Model.name(transfers: [], owner: owner)) do
    pubkey = :aeser_id.create(:account, owner)

    %{original: pubkey, current: pubkey}
  end

  def ownership(
        state,
        Model.name(
          claims: [{_block_index, last_claim_txi_idx} | _rest_claims],
          owner: owner
        )
      ) do
    orig_owner =
      state
      |> DbUtil.read_node_tx(last_claim_txi_idx)
      |> :aens_claim_tx.account_id()

    %{original: orig_owner, current: :aeser_id.create(:account, owner)}
  end

  @spec account_pointer_at(state(), Names.plain_name(), AeMdw.Txs.txi()) ::
          {:error, :name_not_found | {:pointee_not_found, any, any}} | {:ok, any}
  def account_pointer_at(state, plain_name, time_reference_txi) do
    case locate(state, plain_name) do
      nil ->
        {:error, :name_not_found}

      {m_name, _module} ->
        pointee_at(state, m_name, time_reference_txi)
    end
  end

  @spec pointee_keys(State.t(), pubkey()) :: list
  defp pointee_keys(state, pk) do
    state
    |> Collection.stream(Model.Pointee, {pk, nil, nil})
    |> Stream.take_while(fn
      {^pk, _bi_txi, _pointee} -> true
      _other_key -> false
    end)
    |> Enum.map(fn {^pk, {bi, txi}, pointee} -> {bi, txi, pointee} end)
  end

  @spec pointees(state(), pubkey()) :: {map(), map()}
  def pointees(state, pk) do
    push = fn place, m_name, {update_bi, update_txi, ptr_k} ->
      pointee = %{
        name: Model.name(m_name, :index),
        active_from: Model.name(m_name, :active),
        expire_height: Names.revoke_or_expire_height(m_name),
        update: Format.to_raw_map(state, {update_bi, update_txi})
      }

      Map.update(place, ptr_k, [pointee], fn pointees -> [pointee | pointees] end)
    end

    for {_bi, txi, _ptr_k} = p_keys <- pointee_keys(state, pk), reduce: {%{}, %{}} do
      {active, inactive} ->
        %{tx: %{name: plain}} = Format.to_raw_map(state, DbUtil.read_tx!(state, txi))

        case locate(state, plain) do
          {_bid_key, Model.AuctionBid} ->
            {active, inactive}

          {m_name, Model.ActiveName} ->
            {push.(active, m_name, p_keys), inactive}

          {m_name, Model.InactiveName} ->
            {active, push.(inactive, m_name, p_keys)}
        end
    end
  end

  defp pointer_kv_raw(ptr),
    do: {:aens_pointer.key(ptr), :aens_pointer.id(ptr)}

  defp collect_vals(state, tab, key) do
    state
    |> Collection.stream(tab, {key, ""})
    |> Stream.take_while(&match?({^key, _val}, &1))
    |> Stream.map(fn {_key, val} -> val end)
    |> Enum.to_list()
  end

  defp ns_tree!(state, block_index) do
    state
    |> State.fetch!(Model.Block, block_index)
    |> Model.block(:hash)
    |> :aec_db.get_block_state()
    |> :aec_trees.ns()
  end

  defp pointee_at(state, Model.name(index: name, updates: updates), ref_txi) do
    updates
    |> find_update_txi_before(ref_txi)
    |> case do
      nil ->
        {:error, {:pointee_not_found, name, ref_txi}}

      update_txi ->
        {:ok, fetch_account_pointee(state, update_txi)}
    end
  end

  defp find_update_txi_before(updates, ref_txi) do
    Enum.find_value(updates, fn {_block_height, update_txi} ->
      if update_txi <= ref_txi, do: update_txi
    end)
  end

  defp fetch_account_pointee(state, update_txi) do
    state
    |> Format.to_raw_map(DbUtil.read_tx!(state, update_txi))
    |> get_in([:tx, :pointers])
    |> Enum.find_value(fn %{key: key, id: pointee_id} ->
      if key == "account_pubkey", do: pointee_id
    end)
  end
end
