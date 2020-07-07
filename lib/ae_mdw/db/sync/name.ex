defmodule AeMdw.Db.Sync.Name do
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Node, as: AE
  alias AeMdw.Db.Model
  alias AeMdw.Db.Name
  alias AeMdw.Db.Format
  alias AeMdw.Validate

  require Model

  import AeMdw.Db.Sync.Name.Cache, only: [pointee_keys: 2]
  import AeMdw.Db.Util

  ##########

  def claim_height(m_name), do: elem(Model.name(m_name, :index), 1)

  def invalidate_txs(type_txis),
    do: invalidate_txs(type_txis, &Format.tx_to_raw_map(read_tx!(&1)))

  @reversible_types [:name_claim_tx, :name_update_tx, :name_revoke_tx]
  # type_txis: ascending (newest last)
  def invalidate_txs(type_txis, read_tx) do
    type_txis
    |> Enum.flat_map(fn {type, txi} -> (type in @reversible_types && [read_tx.(txi)]) || [] end)
    |> Enum.group_by(& &1.tx.name_id)
    |> Enum.reduce(
      {%{}, %{}, {[], []}},
      fn {name_id, txs}, xchgs ->
        name_hash = Validate.id!(name_id)

        Enum.reduce(invalidate({name_hash, txs}), xchgs, fn {ds, ws, {last_c?, last_u?}},
                                                            {dels, writes,
                                                             {last_claims, last_updates}} ->
          {Map.merge(dels, ds), Map.merge(writes, ws),
           {(last_c? && [name_hash | last_claims]) || last_claims,
            (last_u? && [name_hash | last_updates]) || last_updates}}
        end)
      end
    )
  end

  # txs - newest last
  def invalidate({name_hash, txs}) do
    activity_spans =
      name_hash
      |> Name.name()
      |> Enum.map(&{claim_height(&1), &1})
      |> sorted_map

    txs
    |> Enum.group_by(&get_span_val(activity_spans, &1.block_height))
    |> Enum.map(&active_period_invalidate/1)
  end

  def active_period_invalidate({m_name, [_ | _] = txs}) do
    type_groups = Enum.group_by(txs, & &1.tx.type) |> Enum.into(%{})
    {dels, writes} = active_period_invalidate(m_name, type_groups)

    {dels, writes,
     {Map.has_key?(type_groups, :name_claim_tx), Map.has_key?(type_groups, :name_update_tx)}}
  end

  def active_period_invalidate(m_name, %{name_claim_tx: claims, name_update_tx: updates}),
    do: invalidate_claims_updates(m_name, claims, updates)

  def active_period_invalidate(m_name, %{name_update_tx: updates}),
    do: invalidate_updates(m_name, updates)

  def active_period_invalidate(m_name, %{name_claim_tx: claims}),
    do: invalidate_claims(m_name, claims)

  def active_period_invalidate(m_name, %{name_revoke_tx: [_]}),
    do: {%{}, %{Model.Name => [Model.name(m_name, revoke: nil)]}}

  ####

  def invalidate_claims_updates(m_name, claims, updates) do
    {c_dels, c_writes} = invalidate_claims(m_name, claims)
    %{tx: %{pointers: last_ptrs}, tx_index: last_update_txi} = :lists.last(updates)
    {del_pointee_keys, del_rev_pointee_keys} = pointee_keys(last_ptrs, last_update_txi)

    u_dels = %{
      Model.NamePointee => del_pointee_keys,
      Model.RevNamePointee => del_rev_pointee_keys
    }

    {Map.merge(c_dels, u_dels), c_writes}
  end

  def invalidate_claims(m_name, [first_claim | _] = claims) do
    {name_hash, claim_height} = Model.name(m_name, :index)

    case {Model.name(m_name, :auction), Enum.reverse(claims)} do
      {nil, [%{block_height: ^claim_height}]} ->
        {%{Model.Name => [{name_hash, claim_height}]}, %{}}

      {[last_bid_txi | _] = m_n_bid_txis, [%{tx_index: last_bid_txi} = last_bid | _]} ->
        plain_name = Model.name(m_name, :name)
        last_height = last_bid.block_height
        proto_vsn = (claim_height >= AE.lima_height() && AE.lima_vsn()) || 0
        claim_delta = claim_delta(plain_name, proto_vsn)
        del_expire = last_height + claim_delta
        first_txi = :lists.last(m_n_bid_txis)

        case first_claim.tx_index do
          ^first_txi ->
            {%{
               Model.NameAuction => [{del_expire, name_hash}],
               Model.Name => [{name_hash, claim_height}]
             }, %{}}

          txi when txi > first_txi ->
            [last_rem_bid | _] =
              rem_bid_txs =
              {:txi, (txi - 1)..first_txi}
              |> DBS.map(:raw, "name_claim.name_id": name_hash)
              |> Enum.to_list()

            rem_bid_txis = Enum.map(rem_bid_txs, & &1.tx_index)
            expire = last_rem_bid.block_height + claim_delta
            m_name = Model.name(m_name, auction: rem_bid_txis, expire: expire, revoke: nil)
            m_auction = Model.name_auction(index: {expire, name_hash}, name_rec: m_name)

            {%{Model.NameAuction => [{del_expire, name_hash}]},
             %{Model.Name => [m_name], Model.NameAuction => [m_auction]}}
        end
    end
  end

  def invalidate_updates(m_name, [first_update | _] = updates) do
    %{tx: %{pointers: last_ptrs}, tx_index: last_txi} = :lists.last(updates)
    {del_pointee_keys, del_rev_pointee_keys} = pointee_keys(last_ptrs, last_txi)
    dels = %{Model.NamePointee => del_pointee_keys, Model.RevNamePointee => del_rev_pointee_keys}
    {name_hash, _} = Model.name(m_name, :index)

    writes =
      {:txi, (first_update.tx_index - 1)..0}
      |> DBS.map(:raw, name_id: name_hash, type: :name_claim, type: :name_update)
      |> Enum.take(1)
      |> case do
        [%{tx: %{type: :name_claim_tx}, block_height: h}] ->
          expire = :aec_governance.name_claim_max_expiration()
          %{Model.Name => Model.name(m_name, expire: h + expire, revoke: nil)}

        [%{tx: %{type: :name_update_tx}, block_height: h} = tx] ->
          {ptes, rev_ptes} = pointee_keys(tx.tx.pointers, tx.tx_index)

          %{
            Model.NamePointee => Enum.map(ptes, &Model.name_pointee(index: &1)),
            Model.RevNamePointee => Enum.map(rev_ptes, &Model.rev_name_pointee(index: &1)),
            Model.Name => Model.name(m_name, expire: h + tx.tx.name_ttl, revoke: nil)
          }
      end

    {dels, writes}
  end

  def claim_delta(plain_name, proto_vsn) do
    t = :aec_governance.name_claim_bid_timeout(plain_name, proto_vsn)
    (t > 0 && t) || :aec_governance.name_claim_max_expiration()
  end

  def sorted_map(kvs),
    do: kvs |> :orddict.from_list() |> :gb_trees.from_orddict()

  def get_span_val(sorted_map, i) do
    Enum.to_list(spans(sorted_map))
    |> Enum.reduce_while(nil, fn {x, v}, last -> (x > i && {:halt, last}) || {:cont, v} end)
  end

  def spans(sorted_map) do
    Stream.resource(
      fn -> :gb_trees.iterator(sorted_map) end,
      fn acc ->
        case :gb_trees.next(acc) do
          :none -> {:halt, acc}
          {k, v, acc} -> {[{k, v}], acc}
        end
      end,
      fn _ -> nil end
    )
  end

  # ################################################################################
  # ## testing

  # def fake_tx({:name_claim_tx, {nonce, name, pk, fee, salt}}) do
  #   {:ns_claim_tx,
  #    {:id, :account, pk},
  #    nonce,
  #    name,
  #    salt,
  #    fee,
  #    :other_fee,
  #    :ttl}
  # end

  # def fake_tx({:name_update_tx, {nonce, name, pk, ttl, pointers}}) do
  #   {:ns_update_tx,
  #    {:id, :account, pk},
  #    nonce,
  #    {:id, :name, ok!(:aens.get_name_hash(name))},
  #    ttl,
  #    (for {k, v} <- pointers, do: {:pointer, k, {:id, :account, v}}),
  #    :client_ttl,
  #    :fee,
  #    :other_ttl}
  # end

  # def fake_tx({:name_revoke_tx, {nonce, name, pk}}) do
  #   {:ns_revoke_tx,
  #    {:id, :account, pk},
  #    nonce,
  #    {:id, :name, ok!(:aens.get_name_hash(name))},
  #    :fee,
  #    :ttl}
  # end

  # def raw_fake_tx({tx_desc, txi, bi = {height, mb_index}}) do
  #   tx_hash = <<txi::32, 0::224>>
  #   mb_time = height * 1_000_000 + mb_index
  #   bk_hash = <<height::32, mb_index::32, 0::192>>
  #   type = elem(tx_desc, 0)
  #   fake_tx = fake_tx(tx_desc)
  #   signed_tx = {:signed_tx, {:aetx, type, :fake_name_mod_tx, 1234, fake_tx}, [<<0::256>>]}
  #   Format.tx_to_raw_map({:tx, txi, tx_hash, bi, mb_time}, {bk_hash, type, signed_tx, fake_tx})
  # end

  # # beware - destroys name related tables - only for verifying the invalidation logic!!
  # # sync should not be running!!
  # def run_destructive_scenario!([_|_] = scenario) do
  #   :mnesia.clear_table(Model.Name)
  #   :mnesia.clear_table(Model.NameAuction)
  #   :mnesia.clear_table(Model.NamePointee)
  #   :mnesia.clear_table(Model.RevNamePointee)

  #   claim = fn {_, name, _, _, _}, tx, txi, bi ->
  #     hash = ok!(:aens.get_name_hash(name))
  #     claim(name, hash, tx, txi, bi)
  #   end
  #   update = fn {_, _name, _pk, _ttl, _pointers}, tx, txi, bi -> update(tx, txi, bi) end
  #   revoke = fn {_, _name, _pk}, tx, txi, bi -> revoke(tx, txi, bi) end

  #   scenario |> prx("!!! RUNNING SCENARIO")

  #   fns = %{name_claim_tx: claim, name_update_tx: update, name_revoke_tx: revoke}
  #   run_destructive_scenario!(scenario, {fns, :gb_trees.empty(), 0})
  # end

  # def run_destructive_scenario!([{:dump, tab} | rest], {fns, txs, last_txi}) do
  #   all(tab) |> prx(tab)
  #   run_destructive_scenario!(rest, {fns, txs, last_txi})
  # end

  # def run_destructive_scenario!([{:invalidate, from_txi}], {_fns, txs, _last_txi}) do
  #   type_txis = type_txi_from(txs, from_txi)

  #   IO.puts("========================================")
  #   IO.puts("=== TABLES BEFORE INVALIDATE")
  #   all(Model.Name) |> prx("Model.Name")
  #   all(Model.NameAuction) |> prx("Model.NameAuction")
  #   all(Model.NamePointee) |> prx("Model.NamePointee")
  #   all(Model.RevNamePointee) |> prx("Model.RevNamePointee")

  #   IO.puts("--------------------")
  #   IO.puts("--- INVALIDATING")
  #   type_txis |> prx("type_txis")

  #   :mnesia.transaction(fn ->
  #     try do
  #       {dels, writes} = invalidate_txs(type_txis, &raw_fake_tx(:gb_trees.get(&1, txs)))
  #       dels |> prx("////////// DEL ")
  #       writes |> prx("////////// WRT ")
  #       for {tab, keys} <- dels, do: Enum.each(keys, &:mnesia.delete(tab, &1, :write))
  #       for {tab, recs} <- writes, do: Enum.each(recs, &:mnesia.write(tab, &1, :write))
  #     rescue
  #       eee ->
  #         {eee, __STACKTRACE__} |> prx("$$$$$$$$$$ CRASH!!!")
  #     end
  #   end)

  #   IO.puts("--------------------")
  #   IO.puts("=== TABLES AFTER INVALIDATE")

  #   all(Model.Name) |> prx("Model.Name")
  #   all(Model.NameAuction) |> prx("Model.NameAuction")
  #   all(Model.NamePointee) |> prx("Model.NamePointee")
  #   all(Model.RevNamePointee) |> prx("Model.RevNamePointee")
  #   IO.puts("====== DONE ===========================")
  # end

  # def run_destructive_scenario!([{bi, txi, {type, args} = tx_desc} | rest], {fns, txs, last})
  # when txi > last do
  #   :gb_trees.lookup(txi, txs) == :none || raise RuntimeError, message: "duplicate TXI: #{txi}"
  #   tx = fake_tx(tx_desc)
  #   :mnesia.transaction(fn -> Map.get(fns, type).(args, tx, txi, bi) end)
  #   txs = :gb_trees.insert(txi, {tx_desc, txi, bi}, txs)
  #   run_destructive_scenario!(rest, {fns, txs, txi})
  # end

  # def type_txi_from(txs, from_txi),
  #   do: type_txi_from_iter(:gb_trees.iterator_from(from_txi, txs), []) # newest first

  # def type_txi_from_iter(iter, acc) do
  #   case :gb_trees.next(iter) do
  #     :none ->
  #       acc
  #     {txi, {{type, _}, _, _}, next} ->
  #       acc = [{type, txi} | acc]
  #       next == [] && acc || type_txi_from_iter(next, acc)
  #   end
  # end

  # def ffs(bytes),
  #   do: :binary.list_to_bin(:lists.duplicate(bytes, <<255::8-signed-big-integer>>))

  # def t1!() do
  #   nm = "toolongtobeinauction.chain"
  #   pk = <<0::256>>
  #   run_destructive_scenario!(
  #     [
  #       {{200_000, 0}, 1, {:name_claim_tx, {1, nm, pk, 1000, 7}}},
  #       {:invalidate, 1}
  #     ]
  #   )
  # end

  # def t2!() do
  #   nm = "auction.chain"
  #   pk1 = <<0::256>>
  #   pk2 = ffs(32)
  #   run_destructive_scenario!(
  #     [
  #       {{200_000, 0}, 1, {:name_claim_tx, {1, nm, pk1, 1000, 7}}},
  #       {{200_001, 0}, 5, {:name_claim_tx, {1, nm, pk2, 1200, 0}}},
  #       {:invalidate, 1}
  #     ]
  #   )
  # end

  # def t3!() do
  #   nm = "auction.chain"
  #   pk1 = <<0::256>>
  #   pk2 = ffs(32)
  #   run_destructive_scenario!(
  #     [
  #       {{200_000, 0}, 1, {:name_claim_tx, {1, nm, pk1, 1000, 7}}},
  #       {{200_001, 0}, 5, {:name_claim_tx, {1, nm, pk2, 1200, 0}}},
  #       {:invalidate, 3}
  #     ]
  #   )
  # end

  # def t4!() do
  #   nm = "auction.chain"
  #   pk1 = <<0::256>>
  #   pk2 = ffs(32)
  #   run_destructive_scenario!(
  #     [
  #       {{200_000, 0}, 1, {:name_claim_tx, {1, nm, pk1, 1000, 7}}},
  #       {{200_001, 0}, 5, {:name_claim_tx, {1, nm, pk2, 1200, 0}}},
  #       {:invalidate, 0}
  #     ]
  #   )
  # end

  # def t5!() do
  #   nm = "auction.chain"
  #   pk1 = <<0::256>>
  #   pk2 = ffs(32)
  #   run_destructive_scenario!(
  #     [
  #       {{200_000, 0}, 1, {:name_claim_tx, {1, nm, pk1, 1000, 7}}},
  #       {{200_001, 0}, 5, {:name_claim_tx, {1, nm, pk2, 1200, 0}}},
  #       {:invalidate, 10}
  #     ]
  #   )
  # end

  # def t6!() do
  #   nm = "auction.chain"
  #   pk1 = <<0::256>>
  #   run_destructive_scenario!(
  #     [
  #       {{200_000, 0}, 1, {:name_claim_tx, {1, nm, pk1, 1000, 7}}},
  #       {{200_100, 9}, 5, {:name_revoke_tx, {10, nm, pk1}}},
  #       {:invalidate, 3}
  #     ]
  #   )
  # end

  # def t7!() do
  #   nm = "somenamewithnoauctionneeded.chain"
  #   pk1 = <<0::256>>
  #   pid = ffs(32)
  #   run_destructive_scenario!(
  #     [
  #       {{200_000, 0}, 1, {:name_claim_tx, {1, nm, pk1, 1000, 7}}},
  #       {:dump, Model.Name},
  #       {{200_100, 1}, 5, {:name_update_tx, {10, nm, pk1, 33_333, [{<<"a">>, pid}]}}},
  #       {:invalidate, 3}
  #     ]
  #   )
  # end

  # def t__10() do

  #   DBS.map(:backward, :raw, type: :name_claim) |> Stream.flat_map(fn tx -> tx.tx.name < 12 && [tx] || [] end) |> Enum.take(10)

  # end

  # def resync(raw_txs) do
  #   alias AeMdw.Db.Sync.Transaction, as: ST
  #   :mnesia.transaction(
  #     fn ->
  #       Enum.each(raw_txs,
  #         fn %{block_height: kbi, micro_index: mbi, micro_time: mb_time,
  #               tx_index: txi, hash: tx_hash} ->
  #           {_, signed_tx} = :aec_db.find_tx_with_location(tx_hash)
  #           ST.sync_transaction(signed_tx, txi, {{kbi, mbi}, mb_time})
  #         end
  #       )
  #     end
  #   )
  # end

  # def needs_auction?(name, height) do
  #   height >= AE.lima_height() &&
  #     case :aens_utils.to_ascii(name) do
  #       {:ok, ascii_name} ->
  #         {:ok, domain} = :aens_utils.name_domain(ascii_name)
  #         length = :erlang.size(ascii_name) - :erlang.size(domain) - 1
  #         length <= :aec_governance.name_max_length_starting_auction()
  #       {:error, _} ->
  #         false
  #     end
  # end
end
