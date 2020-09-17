defmodule AeMdw.Db.Stream.Oracle do
  alias AeMdw.Db.Stream, as: DBS
  alias AeMdw.Db.Model

  require Model

  import AeMdw.Db.Util

  ##########

  def active_oracles(:forward, mapper),
    do: simple_resource(Model.ActiveOracleExpiration, nil, &next/2, mapper)

  def active_oracles(:backward, mapper),
    do: simple_resource(Model.ActiveOracleExpiration, <<>>, &prev/2, mapper)

  def inactive_oracles(:forward, mapper),
    do: simple_resource(Model.InactiveOracleExpiration, nil, &next/2, mapper)

  def inactive_oracles(:backward, mapper),
    do: simple_resource(Model.InactiveOracleExpiration, <<>>, &prev/2, mapper)

  ##########

  def simple_resource(tab, init_k, advance, mapper) do
    alias DBS.Resource.Util, as: RU
    advance = RU.advance_fn(advance, fn _ -> true end)
    RU.simple_resource({init_k, advance}, tab, mapper)
  end
end
