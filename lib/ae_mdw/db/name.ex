defmodule AeMdw.Db.Name do
  alias AeMdw.Db.Model
  alias AeMdw.Validate

  require Model
  require Ex2ms

  import AeMdw.{Util, Db.Util}

  ##########

  def clear_tables() do
    :mnesia.clear_table(Model.Name)
    :mnesia.clear_table(Model.NameAuction)
    :mnesia.clear_table(Model.NamePointee)
    :mnesia.clear_table(Model.RevNamePointee)
    :ok
  end

  def plain_name!(name_hash) do
    {[m_name | _], _cont} =
      :mnesia.async_dirty(fn ->
        :mnesia.select(Model.Name, name_match_spec(name_hash), 1, :read)
      end)

    Model.name(m_name, :name)
  end

  def name(name_hash) when is_binary(name_hash),
    do: :mnesia.async_dirty(fn -> :mnesia.select(Model.Name, name_match_spec(name_hash)) end)

  def name({name_hash, claim_height}) when is_binary(name_hash) and is_integer(claim_height),
    do: :mnesia.async_dirty(fn -> :mnesia.read(Model.Name, {name_hash, claim_height}) end)

  def name_spans(name_hash, height) do
    collect_keys(Model.Name, [], {name_hash, nil}, &:mnesia.prev/2, fn
      {^name_hash, _} = claim_index, _ ->
        [m_n] = name(claim_index)

        case name_spans?(m_n, height) do
          false -> {:next, []}
          true -> {:halt, [m_n]}
        end

      _, _ ->
        {:halt, []}
    end)
  end

  def last_name(name_hash) do
    case :mnesia.dirty_prev(Model.Name, {name_hash, nil}) do
      {^name_hash, _} = key ->
        one!(:mnesia.dirty_read(Model.Name, key))

      _ ->
        nil
    end
  end

  def last_name!(name_hash) do
    {^name_hash, _} = key = :mnesia.dirty_prev(Model.Name, {name_hash, nil})
    one!(:mnesia.dirty_read(Model.Name, key))
  end

  def name_spans?(m_name, height) do
    {_, claim_h} = Model.name(m_name, :index)
    height >= claim_h and height <= Model.name(m_name, :expire)
  end

  def auction_spans?(m_auction, height),
    do: name_spans(Model.name_auction(m_auction, :name_rec), height)

  def auction({expire, name_hash}) when is_integer(expire) and is_binary(name_hash),
    do: :mnesia.dirty_read(Model.NameAuction, {expire, name_hash})

  def auction_spans(name_hash, height) do
    collect_keys(Model.NameAuction, [], :"$end_of_table", &:mnesia.prev/2, fn
      {_expire, ^name_hash} = auction_index, _ ->
        [m_a] = auction(auction_index)
        {:halt, (auction_spans?(m_a, height) && [m_a]) || []}

      _, _ ->
        {:next, []}
    end)
  end

  def name_match_spec(name_hash) do
    Ex2ms.fun do
      {:name, {^name_hash, :_}, :_, :_, :_, :_} = x -> x
    end
  end

  def pointees(pubkey) do
    mspec = pointees_match_spec(pubkey)
    :mnesia.async_dirty(fn -> :mnesia.select(Model.NamePointee, mspec) end)
  end

  def pointees_match_spec(pubkey) do
    Ex2ms.fun do
      {:name_pointee, {^pubkey, :_, :_}, :_} = x -> x
    end
  end

  def ptr_resolve(block_index, name_hash, key) do
    block_hash = Model.block(read_block!(block_index), :hash)
    trees = :aec_db.get_block_state(block_hash)

    :aens.resolve_hash("account_pubkey", name_hash, :aec_trees.ns(trees))
    |> map_ok_nil(&Validate.id!/1)
  end
end
