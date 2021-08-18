defmodule AeMdw.Db.Stream.Name do
  alias AeMdw.Db.Stream.Resource.Util, as: RU
  alias AeMdw.Db.Model

  require Model

  import AeMdw.Db.Util

  ##########

  def auctions({:expiration, :forward}, mapper),
    do: simple_resource(Model.AuctionExpiration, nil, &next/2, mapper)

  def auctions({:expiration, :backward}, mapper),
    do: simple_resource(Model.AuctionExpiration, <<>>, &prev/2, mapper)

  def auctions({:name, :forward}, mapper),
    do: simple_resource(Model.AuctionBid, nil, &next/2, mapper)

  def auctions({:name, :backward}, mapper),
    do: simple_resource(Model.AuctionBid, <<>>, &prev/2, mapper)

  def active_names({:expiration, :forward}, mapper),
    do: simple_resource(Model.ActiveNameExpiration, nil, &next/2, mapper)

  def active_names({:expiration, :backward}, mapper),
    do: simple_resource(Model.ActiveNameExpiration, <<>>, &prev/2, mapper)

  def active_names({:name, :forward}, mapper),
    do: simple_resource(Model.ActiveName, nil, &next/2, mapper)

  def active_names({:name, :backward}, mapper),
    do: simple_resource(Model.ActiveName, last_bin_key(Model.ActiveName), &prev/2, mapper)

  def inactive_names({:expiration, :forward}, mapper),
    do: simple_resource(Model.InactiveNameExpiration, nil, &next/2, mapper)

  def inactive_names({:expiration, :backward}, mapper),
    do: simple_resource(Model.InactiveNameExpiration, <<>>, &prev/2, mapper)

  def inactive_names({:name, :forward}, mapper),
    do: simple_resource(Model.InactiveName, nil, &next/2, mapper)

  def inactive_names({:name, :backward}, mapper),
    do: simple_resource(Model.InactiveName, last_bin_key(Model.InactiveName), &prev/2, mapper)

  ##########

  def simple_resource(tab, init_k, advance, mapper) do
    advance = RU.advance_fn(advance, fn _ -> true end)
    RU.simple_resource({init_k, advance}, tab, mapper)
  end

  def prefix_resource(tab, prefix, direction, mapper)
      when direction in [:forward, :backward] do
    {init_k, advance} =
      case direction do
        :forward -> {prefix, &next/2}
        :backward -> {prefix <> AeMdw.Node.max_blob(), &prev/2}
      end

    advance = RU.advance_fn(advance, AeMdwWeb.Util.prefix_checker(prefix))
    RU.simple_resource({init_k, advance}, tab, mapper)
  end

  def auction_prefix_resource(prefix, direction, mapper)
      when direction in [:forward, :backward] do
    {init_k, advance} =
      case direction do
        :forward -> {{prefix, {}, :_, :_, :_}, &next/2}
        :backward -> {{prefix <> AeMdw.Node.max_blob(), [], :_, :_, :_}, &prev/2}
      end

    prefix_check = AeMdwWeb.Util.prefix_checker(prefix)
    advance = RU.advance_fn(advance, fn {name, _, _, _, _} -> prefix_check.(name) end)
    RU.simple_resource({init_k, advance}, Model.AuctionBid, mapper)
  end

  def last_bin_key(tab) do
    case last(tab) do
      :"$end_of_table" -> nil
      key -> key <> "Z"
    end
  end
end
