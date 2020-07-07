defmodule AeMdw.Db.Sync.Name.Cache do
  @moduledoc """
  Name.Cache needs to exist because we sync by generation, but name TXs (update) can refer to names in the same generation (thus - not synced yet).

  There are 2 different caches used in this module as well - their purpose is to keep last claim/update TXs cached to speed up sync (to avoid read from DB while syncing)
  """

  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Node, as: AE
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Validate
  alias AeMdw.EtsCache

  require Model

  import AeMdw.{Util, Db.Util}

  ##########

  defstruct claim: %{}, update: %{}, revoke: %{}

  ##########

  def claim(%__MODULE__{claim: cs} = cache, name, name_hash, tx, txi, {height, _mb_index}) do
    salt = tx_val(tx, :name_claim_tx, :name_salt)
    proto_vsn = (height >= AE.lima_height() && AE.lima_vsn()) || 0

    case :aec_governance.name_claim_bid_timeout(name, proto_vsn) do
      # no auction
      0 ->
        expire = height + :aec_governance.name_claim_max_expiration()
        m_name = m_name(name, name_hash, height, expire, nil)
        EtsCache.put(:last_name_claim, name_hash, %{block_height: height, tx_index: txi})
        %{cache | claim: Map.put(cs, name_hash, {height, txi, {m_name, nil}})}

      timeout ->
        # of auction
        expire = height + timeout
        m_name = m_name(name, name_hash, height, expire, [{expire, txi, salt}])
        wrap_n = fn m_n -> {height, txi, {m_n, salt}} end

        merger = fn {_height0, _txi0, {m_name0, _}} ->
          [_ | _] = prev_exp_txi_salts = Model.name(m_name0, :auction)

          wrap_n.(
            Model.name(m_name0,
              expire: expire,
              auction: [{expire, txi, salt} | prev_exp_txi_salts]
            )
          )
        end

        is_integer(salt) && salt != 0 &&
          EtsCache.put(:last_name_claim, name_hash, %{block_height: height, tx_index: txi})

        %{cache | claim: Map.update(cs, name_hash, wrap_n.(m_name), merger)}
    end
  end

  def update(%__MODULE__{update: us} = cache, name_hash, tx, txi, {height, _mb_index}) do
    [_ttl, pointers] = ttl_ptrs = gets(tx, :aens_update_tx, [:name_ttl, :pointers])
    u = {height, txi, ttl_ptrs}

    EtsCache.put(:last_name_update, name_hash, %{
      block_height: height,
      tx_index: txi,
      tx: %{pointers: pointers}
    })

    %{cache | update: Map.put(us, name_hash, u)}
  end

  def revoke(%__MODULE__{revoke: rs} = cache, name_hash, _tx, txi, {height, _mb_index}),
    do: %{cache | revoke: Map.put(rs, name_hash, {height, txi})}

  ##########

  def diff(%__MODULE__{claim: cs, update: us, revoke: rs}) do
    get = fn ns, h -> List.wrap(Map.get(ns, h, [])) end

    [cs, us, rs]
    |> Enum.map(&:gb_sets.from_list(Map.keys(&1)))
    |> :gb_sets.union()
    |> :gb_sets.to_list()
    |> Enum.reduce({%{}, %{}}, fn hash, {dels, writes} ->
      [c?, u?, r?] = Enum.map([cs, us, rs], &get.(&1, hash))

      cur =
        [
          map_one_nil(c?, &[{:c, &1}]) || [],
          map_one_nil(u?, &[{:u, &1}]) || [],
          map_one_nil(r?, &[{:r, &1}]) || []
        ]
        |> Enum.flat_map(& &1)

      {h_dels, h_writes} = name_diff(hash, cur)

      {merge_maps([dels, h_dels], &concat_tagged_list/3),
       merge_maps([writes, h_writes], &concat_tagged_list/3)}
    end)
  end

  def persist!(%__MODULE__{claim: cs, update: us, revoke: rs} = cache) do
    case Enum.map([cs, us, rs], &map_size/1) do
      [0, 0, 0] ->
        :nop

      [cs_, us_, rs_] ->
        AeMdw.Log.info("name_cache: computing diff - [cs: #{cs_}, us: #{us_}, rs: #{rs_}]")
        {diff_usecs, {dels, writes}} = :timer.tc(fn -> diff(cache) end)
        AeMdw.Log.info("name_cache: diff took #{diff_usecs / 1000} milliseconds")
        # AeMdw.Log.info("name_cache: diff dels = #{inspect value_counts(dels)}")
        # AeMdw.Log.info("name_cache: diff wrts = #{inspect value_counts(writes)}")

        :mnesia.transaction(fn ->
          do_dels(dels, :delete)
          do_writes(writes, :write)
        end)
    end
  end

  # :mnesia.transaction(
  #   fn ->
  #     all(Model.Name) |> prx(Model.Name)
  #     all(Model.NameAuction) |> prx(Model.NameAuction)
  #     all(Model.NamePointee) |> prx(Model.NamePointee)
  #     all(Model.RevNamePointee) |> prx(Model.RevNamePointee)
  #   end)
  # IO.puts("==================================================")

  def ptr_resolve(%__MODULE__{update: us}, name_hash, key) do
    with {_height, _txi, [_name_ttl, pointers]} <- us[name_hash] do
      pointers
      |> Enum.find_value(&(:aens_pointer.key(&1) == key && :aens_pointer.id(&1)))
      |> map_ok_nil(&Validate.id!/1)
    end
  end

  ##########

  # non auction create
  def name_diff(_hash, [{:c, {_, _, {_m_name, nil}}}] = cur),
    do: {%{}, m_n_claim_new_writes(cur)}

  # auction create
  def name_diff(_hash, [{:c, {_, _, {_m_name, m_salt}}}] = cur)
      when is_integer(m_salt) and m_salt != 0,
      do: {%{}, m_n_claim_new_writes(cur)}

  # add bid
  def name_diff(hash, [{:c, {_, _, {m_name, 0}} = c}]) do
    [{_, _, _} | _] = exp_txi_salts = Model.name(m_name, :auction)

    case :lists.last(exp_txi_salts) do
      # first in cache is another bid
      {_, _, 0} ->
        [db_c] = dbtx([c], hash, :name_claim)
        {db_m_name, db_m_auction} = db_m_name_auction(hash, db_c.block_height)
        true = is_tuple(db_m_auction)
        {m_name, m_auction} = cached_m_name_auction(m_name, &from_db_m_name(&1, &2, db_m_name))

        {%{Model.NameAuction => [Model.name_auction(db_m_auction, :index)]},
         %{Model.Name => [m_name], Model.NameAuction => [m_auction]}}

      # first in cache is new auction
      {_, _, salt} when is_integer(salt) and salt != 0 ->
        {m_name, m_auction} = cached_m_name_auction(m_name, &from_m_name/2)
        {%{}, %{Model.Name => [m_name], Model.NameAuction => [m_auction]}}
    end
  end

  def name_diff(hash, [{:r, {revoke_h, _}}]),
    do: {%{}, %{Model.Name => [Model.name(Name.last_name!(hash), revoke: revoke_h)]}}

  def name_diff(hash, [{:c, {_claim_h, _c_txi, {m_name, _}}} | [{:u, u} | _] = u?]) do
    db_u? = dbtx([u], hash, :name_update)
    {m_n, m_a?} = cached_m_name_auction(m_name)
    auction_dels = (m_a? && %{Model.NameAuction => [{Model.name(m_n, :expire), hash}]}) || %{}
    writes = m_n_update_writes(m_n, u?)
    dels = map_one_nil(db_u?, &ptrs_update_dels(&1.tx.pointers, &1.tx_index)) || %{}
    {Map.merge(auction_dels, dels), writes}
  end

  def name_diff(hash, [{:u, u} | _] = cur) do
    [db_c] = dbtx([], hash, :name_claim)
    db_u? = dbtx([u], hash, :name_update)
    [m_n] = Name.name({hash, db_c.block_height})
    dels = map_one_nil(db_u?, &ptrs_update_dels(&1.tx.pointers, &1.tx_index)) || %{}
    {dels, m_n_update_writes(m_n, cur)}
  end

  ####

  def concat_tagged_list(_, xs, ys), do: ys ++ xs

  def revoke_h(r?),
    do: map_one_nil(r?, fn {r_h, _} -> r_h end)

  def cached_m_name_auction(m_n),
    do: cached_m_name_auction(m_n, fn m_n, m_a -> Model.name(m_n, auction: m_a) end)

  def cached_m_name_auction(m_n, f) do
    case Model.name(m_n, :auction) do
      nil ->
        {f.(m_n, nil), nil}

      [{ex, _, _} | _] = cached_exp_txis ->
        {_, prev_bids, _} = :lists.unzip3(cached_exp_txis)
        m_n = f.(m_n, prev_bids)
        {hash, _} = Model.name(m_n, :index)
        {m_n, Model.name_auction(index: {ex, hash}, name_rec: m_n)}
    end
  end

  def from_db_m_name(m_name, [_ | _] = cache_bids, db_m_name) do
    {_, claim_h} = Model.name(m_name, :index)
    expire = claim_h + auction_timeout(Model.name(m_name, :name), claim_h)
    db_bids = Model.name(db_m_name, :auction)
    Model.name(db_m_name, expire: expire, auction: cache_bids ++ db_bids)
  end

  def from_m_name(m_name, [_ | _] = cache_bids) do
    {_, claim_h} = Model.name(m_name, :index)
    expire = claim_h + auction_timeout(Model.name(m_name, :name), claim_h)
    Model.name(m_name, expire: expire, auction: cache_bids)
  end

  def m_n_claim_new_writes([{:c, {_, _, {m_name, nil}}}]) do
    {m_name, nil} = cached_m_name_auction(m_name)
    %{Model.Name => [m_name]}
  end

  def m_n_claim_new_writes([{:c, {_, _, {m_name, m_salt}}}])
      when is_integer(m_salt) and m_salt != 0 do
    {m_name, m_auction?} = cached_m_name_auction(m_name)
    %{Model.Name => [m_name], Model.NameAuction => [m_auction?]}
  end

  def m_n_update_writes(m_n, [{:u, {update_h, u_txi, [ttl, ptrs]}} | r?]) do
    Map.merge(
      ptrs_update_writes(ptrs, u_txi),
      %{
        Model.Name => [
          Model.name(m_n,
            expire: update_h + ttl,
            revoke: revoke_h(r?)
          )
        ]
      }
    )
  end

  def ptrs_update_writes([]),
    do: %{}

  def ptrs_update_writes([last]),
    do: ptrs_update_writes(last.tx.ptrs, last.tx_index)

  def ptrs_update_writes(ptrs, txi) do
    {pointees, rev_pointees} = pointee_keys(ptrs, txi)

    %{
      Model.NamePointee => Enum.map(pointees, &Model.name_pointee(index: &1)),
      Model.RevNamePointee => Enum.map(rev_pointees, &Model.rev_name_pointee(index: &1))
    }
  end

  def ptrs_update_dels([]),
    do: %{}

  def ptrs_update_dels([last]),
    do: ptrs_update_dels(last.tx.pointers, last.tx_index)

  def ptrs_update_dels(ptrs, txi) do
    {pointees, rev_pointees} = pointee_keys(ptrs, txi)
    %{Model.NamePointee => pointees, Model.RevNamePointee => rev_pointees}
  end

  # def tab_groups([[m_n | _] = m_names | m_rest]) when elem(m_n, 0) == :name,
  #   do: Map.merge(%{Model.Name => m_names}, tab_groups(m_rest))
  # def tab_groups([[m_a | _] = m_auctions | m_rest]) when elem(m_a, 0) == :name_auction,
  #   do: Map.merge(%{Model.NameAuction => m_auctions}, tab_groups(m_rest))
  # def tab_groups([[{[m_p | _] = m_pointees, [m_r | _] = m_rev_pointees} | _] | m_rest])
  # when elem(m_p, 0) == :name_pointee and elem(m_r, 0) == :rev_name_pointee,
  #   do: Map.merge(%{Model.NamePointee => m_pointees, Model.RevNamePointee => m_rev_pointees},
  #         tab_groups(m_rest))

  def m_name(name, name_hash, claim_height, expire_height, auction?),
    do:
      Model.name(
        index: {name_hash, claim_height},
        name: name,
        expire: expire_height,
        auction: auction?
      )

  def pointer_kv(ptr),
    do: {:aens_pointer.key(ptr), Validate.id!(:aens_pointer.id(ptr))}

  def pointee_keys(pointers, txi) do
    for ptr <- pointers, reduce: {[], []} do
      {pointees, rev_pointees} ->
        {p_key, p_val} = pointer_kv(ptr)
        {[{p_val, txi, p_key} | pointees], [{txi, p_val, p_key} | rev_pointees]}
    end
  end

  def auction_timeout(plain_name, height) do
    proto_vsn = (height >= AE.lima_height() && AE.lima_vsn()) || 0
    :aec_governance.name_claim_bid_timeout(plain_name, proto_vsn)
  end

  def auction?(plain_name, height),
    do: auction_timeout(plain_name, height) > 0

  def value_counts(%{} = m),
    do: Enum.into(Enum.map(m, fn {k, xs} -> {k, Enum.count(xs)} end), %{})

  def repr_txi({_, txi}), do: txi
  def repr_txi({_, txi, _}), do: txi

  def dbtx([], hash, type), do: last_db_tx(nil, hash, type)
  def dbtx([txi], hash, type) when is_integer(txi), do: last_db_tx(txi, hash, type)
  def dbtx([repr], hash, type) when is_tuple(repr), do: last_db_tx(repr_txi(repr), hash, type)

  def last_db_tx(below_txi, hash, type) do
    case EtsCache.get(last_cache_tab(type), hash) do
      {val, _} ->
        [val]

      nil ->
        case last_db_tx_(below_txi, hash, type) do
          [] ->
            []

          [%{tx: %{type: :name_claim_tx}} = x] = res ->
            EtsCache.put(:last_name_claim, hash, %{
              block_height: x.block_height,
              tx_index: x.tx_index
            })

            res

          [%{tx: %{type: :name_update_tx}} = x] = res ->
            EtsCache.put(:last_name_update, hash, %{
              block_height: x.block_height,
              tx_index: x.tx_index,
              tx: %{pointers: x.tx.pointers}
            })

            res
        end
    end
  end

  def last_db_tx_(below_txi, hash, type) do
    scope = (below_txi && {:txi, (below_txi - 1)..0}) || :backward

    case type do
      :name_claim ->
        DBS.map(scope, :raw, "name_claim.name_id": hash)
        |> Stream.drop_while(&(&1.tx.name_salt == 0))

      :name_update ->
        DBS.map(scope, :raw, "name_update.name_id": hash)
    end
    |> Enum.take(1)
  end

  def last_cache_tab(:name_claim), do: :last_name_claim
  def last_cache_tab(:name_update), do: :last_name_update

  def db_m_name_auction(name_hash, valid_h) do
    [m_name] = Name.name_spans(name_hash, valid_h)
    {_, claim_h} = Model.name(m_name, :index)

    case auction_timeout(Model.name(m_name, :name), claim_h) do
      0 ->
        {m_name, nil}

      t when t > 0 ->
        expire = Model.name(m_name, :expire)
        [m_auction] = Name.auction({expire, name_hash})
        {m_name, m_auction}
    end
  end

  # def db_m_name_auction(%{block_height: c_h,
  #                          tx: %{name: nm_bin, name_id: name_id,
  #                                type: :name_claim_tx}} = _latest_name_claim_in_db) do
  #   nm_hash = Validate.id!(name_id)
  #   case auction_timeout(nm_bin, c_h) do
  #     0 ->
  #       expire = c_h + :aec_governance.name_claim_max_expiration()
  #       {m_name(nm_bin, nm_hash, c_h, expire, nil), nil}

  #     timeout when timeout > 0 ->
  #       [%{block_height: first_h} = _first_claim | _] = db_claims =
  #         {:txi, c_h..0}
  #         |> DBS.map(:raw, {:or, [['name_claim.name': nm_bin],
  #                                 ['name_revoke.name_id': name_id]]})
  #         |> Enum.reduce_while([], fn
  #              %{tx: %{type: :name_claim_tx, name_salt: salt}, tx_index: txi} = x, xs ->
  #                {salt == 0 && :cont || :halt, [x | xs]
  #              %{tx: %{type: :name_revoke_tx}}, xs ->
  #                {:halt, xs}
  #            end)
  #       bid_txis = Enum.map(db_claims, & &1.tx_index) |> Enum.reverse
  #       expire = :lists.last(db_claims).block_height + timeout
  #       m_name = m_name(nm_bin, nm_hash, first_h, expire, bid_txis)
  #       {m_name, Model.name_auction(index: {expire, name_hash}, name_rec: m_name)}
  #   end
  # end

  # def resync(%Range{first: f, last: l}) when f <= l do
  #   alias Sync.Transaction, as: ST

  #   DBS.map({:gen, f..l}, :raw, type_group: :name)
  #   |> Enum.reduce(:gb_trees.empty(), fn %{block_height: h} = tx, gens ->
  #          case :gb_trees.lookup(h, gens) do
  #            :none -> :gb_trees.insert(h, [tx], gens)
  #            {:value, txs} -> :gb_trees.update(h, [tx | txs], gens)
  #          end
  #        end)
  #   |> :gb_trees.to_list
  #   |> Enum.each(fn {kbi, rev_txs} ->
  #        kbi |> prx("////////// SYNCING GEN")
  #        :mnesia.transaction(fn ->
  #          name_cache =
  #            Enum.reduce(Enum.reverse(rev_txs), %Sync.Name.Cache{},
  #              fn %{block_height: ^kbi, micro_index: mbi, micro_time: mb_time,
  #                    tx_index: txi, hash: tx_hash}, name_cache ->
  #                ctx = {{kbi, mbi}, mb_time}
  #                {_, signed_tx} = :aec_db.find_tx_with_location(tx_hash)
  #                {_, name_cache} = ST.sync_transaction(signed_tx, txi, ctx, name_cache)
  #                name_cache
  #              end)
  #          Sync.Name.Cache.persist!(name_cache)
  #        end)
  #      end)

  # end

  # def resync(%Range{first: f, last: l}) when f <= l do
  #   alias Sync.Transaction, as: ST
  #   :mnesia.transaction(
  #     fn ->
  #       Enum.each(f..l,
  #         fn h ->
  #           name_cache =
  #             DBS.map({:gen, h}, :raw, type_group: :name)
  #             |> Enum.reduce(%Sync.Name.Cache{},
  #                  fn %{block_height: kbi, micro_index: mbi, micro_time: mb_time,
  #                       tx_index: txi, hash: tx_hash}, name_cache ->
  #                    ctx = {{kbi, mbi}, mb_time}
  #                    {_, signed_tx} = :aec_db.find_tx_with_location(tx_hash)
  #                    {_, name_cache} = ST.sync_transaction(signed_tx, txi, ctx, name_cache)
  #                    name_cache
  #                  end)
  #           Sync.Name.Cache.persist!(name_cache)
  #         end
  #       )
  #     end
  #   )
  # end
end
