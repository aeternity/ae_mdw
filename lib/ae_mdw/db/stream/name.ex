defmodule AeMdw.Db.Stream.Name do
  # credo:disable-for-this-file
  alias AeMdw.Database
  alias AeMdw.Db.Stream.Resource.Util, as: RU
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util

  ##########

  def simple_resource(tab, init_k, advance, mapper) do
    advance = RU.advance_fn(advance, fn _ -> true end)
    RU.simple_resource({init_k, advance}, tab, mapper)
  end

  def prefix_resource(tab, prefix, direction, mapper)
      when direction in [:forward, :backward] do
    {init_k, advance} =
      case direction do
        :forward -> {prefix, &Database.next_key/2}
        :backward -> {prefix <> AeMdw.Node.max_blob(), &Database.prev_key/2}
      end

    advance = RU.advance_fn(advance, AeMdwWeb.Util.prefix_checker(prefix))
    RU.simple_resource({init_k, advance}, tab, mapper)
  end

  def auction_prefix_resource(prefix, direction, mapper)
      when direction in [:forward, :backward] do
    {init_k, advance} =
      case direction do
        :forward -> {prefix, &Database.next_key/2}
        :backward -> {prefix <> AeMdw.Node.max_blob(), &Database.prev_key/2}
      end

    advance = RU.advance_fn(advance, AeMdwWeb.Util.prefix_checker(prefix))
    RU.simple_resource({init_k, advance}, Model.AuctionBid, mapper)
  end

  def last_bin_key(tab) do
    case Util.last(tab) do
      :"$end_of_table" -> nil
      key -> key <> "Z"
    end
  end
end
