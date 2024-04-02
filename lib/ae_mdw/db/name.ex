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
  alias AeMdw.Util
  alias AeMdw.Validate

  require Model

  @typep direction :: :forward | :backward
  @typep pubkey :: Db.pubkey()
  @typep plain_name :: Names.plain_name()
  @typep height :: Blocks.height()
  @typep txi_idx :: AeMdw.Txs.txi_idx()
  @typep state :: State.t()

  @typep nested_table ::
           Model.NameClaim
           | Model.NameTransfer
           | Model.NameUpdate
           | Model.NameExpired
           | Model.NameRevoke
           | Model.AuctionBidClaim

  @min_int Util.min_int()
  @max_int Util.max_int()

  @spec plain_name(State.t(), binary()) :: {:ok, String.t()} | nil
  def plain_name(state, name_hash) do
    case State.get(state, Model.PlainName, name_hash) do
      {:ok, Model.plain_name(value: value)} -> {:ok, value}
      :not_found -> nil
    end
  end

  @spec plain_name!(State.t(), binary()) :: String.t()
  def plain_name!(state, name_hash) do
    Model.plain_name(value: plain_name) = State.fetch!(state, Model.PlainName, name_hash)
    plain_name
  end

  @spec ptr_resolve(state(), Blocks.block_index(), binary(), binary()) ::
          {:ok, binary()} | {:error, :name_revoked}
  def ptr_resolve(state, block_index, name_hash, pointer_key) do
    with {:ok, id} <-
           :aens.resolve_hash(pointer_key, name_hash, ns_tree!(state, block_index)) do
      Validate.id(id)
    end
  end

  @spec ptr_resolve(Blocks.block_hash(), binary(), binary()) ::
          {:ok, binary()} | {:error, :name_revoked}
  def ptr_resolve(block_hash, name_hash, pointer_key) do
    with {:ok, id} <-
           :aens.resolve_hash(pointer_key, name_hash, ns_tree!(block_hash)) do
      Validate.id(id)
    end
  end

  @spec last_update_pointee_pubkey(state(), binary()) :: binary()
  def last_update_pointee_pubkey(state, name_id) do
    with {:ok, name_hash} <- Validate.id(name_id),
         {:ok, Model.plain_name(value: plain_name)} <-
           State.get(state, Model.PlainName, name_hash),
         {m_name, _source} <- locate(state, plain_name) do
      state
      |> pointers(m_name)
      |> case do
        %{"account_pubkey" => account_id} -> account_id
        map -> map |> Map.to_list() |> hd() |> elem(1)
      end
      |> Validate.id!()
    end
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

  @spec stream_nested_resource(state(), nested_table(), plain_name()) :: Enumerable.t()
  def stream_nested_resource(state, table, plain_name) do
    key_boundary = {
      {plain_name, @min_int, {@min_int, @min_int}},
      {plain_name, @max_int, {@max_int, @max_int}}
    }

    state
    |> Collection.stream(table, :backward, key_boundary, nil)
    |> Stream.map(fn {^plain_name, _height, txi_idx} -> txi_idx end)
  end

  @spec stream_nested_resource(state(), nested_table(), plain_name(), height()) :: Enumerable.t()
  def stream_nested_resource(state, table, plain_name, height) do
    key_boundary = {
      {plain_name, height, {@min_int, @min_int}},
      {plain_name, height, {@max_int, @max_int}}
    }

    state
    |> Collection.stream(table, :backward, key_boundary, nil)
    |> Stream.map(fn {^plain_name, ^height, txi_idx} -> txi_idx end)
  end

  @spec stream_nested_resource(
          state(),
          nested_table(),
          direction(),
          plain_name(),
          {plain_name(), height(), txi_idx()} | nil
        ) :: Enumerable.t()
  def stream_nested_resource(state, table, direction, plain_name, cursor) do
    key_boundary = {
      {plain_name, @min_int, {@min_int, @min_int}},
      {plain_name, @max_int, {@max_int, @max_int}}
    }

    state
    |> Collection.stream(table, direction, key_boundary, cursor)
    |> Stream.map(fn {^plain_name, height, txi_idx} -> {height, txi_idx, table} end)
  end

  @spec pointers(state(), Model.name()) :: map()
  def pointers(state, Model.name(index: plain_name, active: active)) do
    case last_update(state, plain_name, active) do
      nil ->
        %{}

      txi_idx ->
        state
        |> DbUtil.read_node_tx(txi_idx)
        |> :aens_update_tx.pointers()
        |> Map.new(&pointer_kv_raw/1)
        |> Format.encode_pointers()
    end
  end

  @spec ownership(state(), Model.name()) :: %{
          current: Format.aeser_id(),
          original: Format.aeser_id()
        }
  def ownership(state, Model.name(index: plain_name, active: active, owner: owner)) do
    max_txi_idx = {@max_int, @max_int}

    case last_transfer(state, plain_name, active) do
      nil ->
        pubkey = :aeser_id.create(:account, owner)

        %{original: pubkey, current: pubkey}

      _transfer_txi_idx ->
        {:ok, {^plain_name, ^active, last_claim_txi_idx}} =
          State.prev(state, Model.NameClaim, {plain_name, active, max_txi_idx})

        orig_owner =
          state
          |> DbUtil.read_node_tx(last_claim_txi_idx)
          |> :aens_claim_tx.account_id()

        %{original: orig_owner, current: :aeser_id.create(:account, owner)}
    end
  end

  @spec account_pointer_at(state(), Names.plain_name(), AeMdw.Txs.txi()) ::
          {:error, :name_not_found | {:pointee_not_found, any, any}} | {:ok, any}
  def account_pointer_at(state, plain_name, time_reference_txi) do
    case locate(state, plain_name) do
      nil ->
        {:error, :name_not_found}

      {_m_name, _module} ->
        update_txi_idx =
          state
          |> stream_nested_resource(Model.NameUpdate, plain_name)
          |> Stream.drop_while(&match?({txi, _idx} when txi > time_reference_txi, &1))
          |> Enum.at(0)

        if update_txi_idx do
          {:ok, fetch_account_pointee(state, update_txi_idx)}
        else
          {:error, {:pointee_not_found, plain_name, time_reference_txi}}
        end
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
    push = fn place, m_name, {update_bi, {update_txi, _idx}, ptr_k} ->
      pointee = %{
        name: Model.name(m_name, :index),
        active_from: Model.name(m_name, :active),
        expire_height: Names.revoke_or_expire_height(m_name),
        update: Format.to_raw_map(state, {update_bi, update_txi})
      }

      Map.update(place, ptr_k, [pointee], fn pointees -> [pointee | pointees] end)
    end

    for {_bi, txi_idx, _ptr_k} = p_keys <- pointee_keys(state, pk), reduce: {%{}, %{}} do
      {active, inactive} ->
        {name_update_tx, _inner_tx_type, _tx_hash, _tx_type, _block_hash} =
          DbUtil.read_node_tx_details(state, txi_idx)

        name_hash = :aens_update_tx.name_hash(name_update_tx)
        plain_name = plain_name!(state, name_hash)

        case locate(state, plain_name) do
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
    |> Enum.map(fn {_key, val} -> val end)
  end

  defp ns_tree!(state, block_index) do
    state
    |> State.fetch!(Model.Block, block_index)
    |> Model.block(:hash)
    |> ns_tree!()
  end

  defp ns_tree!(block_hash) do
    block_hash
    |> :aec_db.get_block_state()
    |> :aec_trees.ns()
  end

  defp fetch_account_pointee(state, update_txi_idx) do
    {update_aetx, :name_update_tx, _tx_hash, _tx_type, _update_block_hash} =
      DbUtil.read_node_tx_details(state, update_txi_idx)

    update_aetx
    |> :aens_update_tx.pointers()
    |> Enum.find_value(fn pointer ->
      if :aens_pointer.key(pointer) == "account_pubkey" do
        :aeser_api_encoder.encode(:id_hash, :aens_pointer.id(pointer))
      end
    end)
  end

  defp last_update(state, plain_name, height) do
    state
    |> stream_nested_resource(Model.NameUpdate, plain_name, height)
    |> Enum.at(0)
  end

  defp last_transfer(state, plain_name, height) do
    state
    |> stream_nested_resource(Model.NameTransfer, plain_name, height)
    |> Enum.at(0)
  end
end
