defmodule AeMdw.Db.Stream.Name do
  alias AeMdw.Node, as: AE
  alias AeMdw.Validate
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Db.Model
  alias AeMdw.Db.Format

  require Model

  import AeMdw.{Util, Db.Util}

  ##########

  def all_names(:backward, format),
    do: all_names({:txi, last_txi()..0}, format)

  def all_names({:txi, %Range{}} = scope, format)
      when format in [:raw, :json] do
    current_height = current_height()

    reducer =
      skip_seen(fn tx, seen ->
        name_info = name_info(tx, current_height)
        {:cont, MapSet.put(seen, tx.tx.name), name_info}
      end)

    DBS.map(scope, :raw, type: :name_claim)
    |> reduce_skip_while(MapSet.new(), reducer)
    |> Stream.map(mapper(:name_info, format))
  end

  def active_names(:backward, format),
    do: active_names({:txi, last_txi()..0}, format)

  def active_names({:txi, %Range{first: from}}, format)
      when format in [:raw, :json] do
    current_height = current_height()
    min_height = current_height - :aec_governance.name_claim_max_expiration()

    cond do
      from > min_height ->
        reducer =
          skip_seen(fn tx, seen ->
            case name_info(tx, current_height) do
              %{claimed: false} ->
                {:next, seen}

              name_info ->
                {:cont, MapSet.put(seen, tx.tx.name), name_info}
            end
          end)

        DBS.map({:txi, from..min_height}, :raw, type: :name_claim)
        |> reduce_skip_while(MapSet.new(), reducer)
        |> Stream.map(mapper(:name_info, format))

      true ->
        DBS.Resource.Util.empty_resource()
    end
  end

  def active_auctions(format),
    do: active_auctions(format, current_height())

  def active_auctions(format, current_height)
      when format in [:raw, :json] do
    alias DBS.Resource.Util, as: RU
    init_key = {current_height + 1, <<>>}
    advance = RU.advance_fn(&next/2, fn _ -> true end)
    mapper = &auction_info(&1, format, current_height)
    RU.simple_resource({init_key, advance}, Model.NameAuction, mapper)
  end

  def name_info(%{} = claim_tx),
    do: name_info(claim_tx, current_height())

  def name_info(%{} = claim_tx, current_height) do
    %{
      block_height: last_claim_height,
      tx_index: claim_txi,
      tx: %{name: plain_name, name_id: name_hash, account_id: claimant}
    } = claim_tx

    expiration_height = expiration_height(plain_name, last_claim_height)
    {revoked_height?, revoked_txi?} = revoke_status(name_hash, claim_txi)
    pointers = pointers(name_hash, claim_txi, revoked_txi?)
    {original_owner, current_owner} = ownership(name_hash, claimant, claim_txi)

    %{
      plain_name => %{
        name_id: name_hash,
        claimant: original_owner,
        owner: current_owner,
        claim_height: last_claim_height,
        expiration_height: expiration_height,
        revoked_height: revoked_height?,
        claimed: is_nil(revoked_txi?) && current_height < expiration_height,
        pointers: pointers
      }
    }
  end

  def auction_info(m_auction, format),
    do: auction_info(m_auction, format, current_height())

  def auction_info(m_auction, format, current_height)
      when format in [:raw, :json] do
    {expiration_height, name_hash} = Model.name_auction(m_auction, :index)
    m_name = Model.name_auction(m_auction, :name_rec)
    plain_name = Model.name(m_name, :name)
    bid_txis = Model.name(m_name, :auction)

    {key_format, name_id_format, tx_format} =
      case format do
        :raw -> {& &1, &:aeser_id.create(:name, &1), &Format.tx_to_raw_map/1}
        :json -> {&to_string/1, &:aeser_api_encoder.encode(:name, &1), &Format.tx_to_map/1}
      end

    %{
      plain_name => %{
        key_format.(:name_id) => name_id_format.(name_hash),
        key_format.(:expiration_height) => expiration_height,
        key_format.(:active) => expiration_height > current_height,
        key_format.(:bids) => Enum.map(bid_txis, compose(tx_format, &read_tx!/1))
      }
    }
  end

  def pointers_info(m_name, format),
    do: pointers_info(m_name, format, current_height())

  def pointers_info(m_name, format, current_height)
      when format in [:raw, :json] do
    {name_hash, claim_height} = Model.name(m_name, :index)

    with nil <- Model.name(m_name, :revoke),
         true <- Model.name(m_name, :expire) > current_height,
         [u] <- Enum.take(DBS.map(:backward, :raw, type: :name_update, name_id: name_hash), 1),
         true <- u.block_height >= claim_height do
      id_format = id_format(format)

      u.tx.pointers
      |> Stream.map(&pointer_kv/1)
      |> Enum.reduce(%{}, fn {key, id}, acc -> Map.put(acc, key, id_format.(id)) end)
    else
      _ -> %{}
    end
  end

  def pointees_info(pubkey, format),
    do: pointees_info(pubkey, format, current_height())

  def pointees_info(pubkey, format, current_height)
      when format in [:raw, :json] do
    alias AeMdw.Db.Name

    {name_id_path, key_format, tx_format} =
      case format do
        :raw -> {[:tx, :name_id], & &1, &Format.tx_to_raw_map/1}
        :json -> {["tx", "name_id"], &to_string/1, &Format.tx_to_map/1}
      end

    for m_ptee <- Name.pointees(pubkey), reduce: %{} do
      acc ->
        {^pubkey, update_txi, pointer_key} = Model.name_pointee(m_ptee, :index)
        update_tx = tx_format.(read_tx!(update_txi))
        name_id = get_in(update_tx, name_id_path)
        m_name = Name.last_name!(Validate.id!(name_id))
        expire = Model.name(m_name, :expire)
        revoke = Model.name(m_name, :revoke)

        case is_nil(revoke) && current_height < expire do
          true ->
            plain_name = Model.name(m_name, :name)

            Map.put(acc, plain_name, %{
              key_format.(:pointer_key) => pointer_key,
              key_format.(:update_tx) => update_tx
            })

          false ->
            acc
        end
    end
  end

  ##########

  def id_format(:raw), do: & &1
  def id_format(:json), do: &:aeser_api_encoder.encode(:id_hash, &1)

  def skip_seen(fun) do
    fn %{tx: %{name: name}} = raw_tx, seen ->
      case name in seen do
        true ->
          {:next, seen}

        false ->
          fun.(raw_tx, seen)
      end
    end
  end

  def ownership(name_hash, claimant, claim_txi) do
    case last_transfer_tx(name_hash) do
      [%{tx_index: transfer_txi, tx: %{recipient_id: new_owner}}]
      when transfer_txi > claim_txi ->
        {claimant, new_owner}

      _ ->
        {claimant, claimant}
    end
  end

  def pointers(name_hash, claim_txi, revoke_txi?) do
    case last_update_tx(name_hash) do
      [%{tx_index: update_txi, tx: %{pointers: pointers}}]
      when update_txi > claim_txi and is_nil(revoke_txi?) ->
        pointers_to_map(pointers)

      _ ->
        %{}
    end
  end

  def pointer_kv(ptr),
    do: {:aens_pointer.key(ptr), :aens_pointer.id(ptr)}

  def pointers_to_map(pointers) when is_list(pointers) do
    pointers
    |> Enum.map(&pointer_kv/1)
    |> Enum.into(%{})
  end

  def current_height(),
    do: :aec_blocks.height(ok!(:aec_chain.top_key_block()))

  def expiration_height(plain_name, last_claim_height) do
    proto_vsn = (last_claim_height >= AE.lima_height() && AE.lima_vsn()) || 0
    bid_ttl = :aec_governance.name_claim_bid_timeout(plain_name, proto_vsn)
    delta_ttl = :aec_governance.name_claim_max_expiration()
    last_claim_height + bid_ttl + delta_ttl
  end

  def revoke_status(name_hash, claim_txi) do
    case last_revoke_tx(name_hash) do
      [%{tx_index: revoke_txi} = x] when revoke_txi > claim_txi ->
        {x.block_height, revoke_txi}

      _ ->
        {nil, nil}
    end
  end

  def mapper(:name_info, :raw), do: fn x -> x end
  def mapper(:name_info, :json), do: &Format.name_info_to_map/1

  def last_update_tx(name_id),
    do: DBS.map(:backward, :raw, type: :name_update, name_id: name_id) |> Enum.take(1)

  def last_transfer_tx(name_id),
    do: DBS.map(:backward, :raw, type: :name_transfer, name_id: name_id) |> Enum.take(1)

  def last_revoke_tx(name_id),
    do: DBS.map(:backward, :raw, type: :name_revoke, name_id: name_id) |> Enum.take(1)
end
