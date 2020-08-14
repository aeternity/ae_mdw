defmodule AeMdw.Db.Stream.Name do
  alias AeMdw.Node, as: AE
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Db.{Model, Format, Name}

  require Model

  import AeMdw.{Util, Db.Util}

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
    alias DBS.Resource.Util, as: RU
    advance = RU.advance_fn(advance, fn _ -> true end)
    RU.simple_resource({init_k, advance}, tab, mapper)
  end

  def last_bin_key(tab) do
    case last(tab) do
      :"$end_of_table" -> nil
      key -> key <> "Z"
    end
  end

end
