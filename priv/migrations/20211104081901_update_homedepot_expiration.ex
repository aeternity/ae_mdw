defmodule AeMdw.Migrations.UpdateHomeDepotExpiration do
  @moduledoc """
  Update homedepot.chain expiration.
  """
  alias AeMdw.Db.Model
  alias AeMdw.Db.Util
  alias AeMdw.Log

  require Model
  require Ex2ms
  require Logger

  @homedepot "homedepot.chain"
  @last_claim 408123

  @spec run(boolean()) :: {:ok, {pos_integer(), pos_integer()}}
  def run(_from_start?) do
    begin = DateTime.utc_now()

    expired_at =
      if [] != :mnesia.dirty_read(Model.InactiveNameExpiration, {458121, @homedepot}) do
        :mnesia.dirty_delete(Model.InactiveNameExpiration, {458121, @homedepot})
        :mnesia.dirty_delete(Model.ActiveNameExpiration, {633884, @homedepot})

        expired_at = expire_from_claim(@homedepot, @last_claim)
        m_exp = Model.expiration(index: {expired_at, @homedepot})
        :mnesia.dirty_write(Model.InactiveNameExpiration, m_exp)

        expired_at
      end

    duration = DateTime.diff(DateTime.utc_now(), begin)

    indexed_count =
      if nil != expired_at do
        Log.info("Name homedepot expiration updated to #{expired_at} in #{duration}s")
        1
      else
        Log.info("No homedepot expiration update (in #{duration}s)")
        0
      end

    {:ok, {indexed_count, duration}}
  end

  defp expire_from_claim(plain_name, height) do
    proto_vsn = Util.proto_vsn(height)
    :aec_governance.name_claim_bid_timeout(plain_name, proto_vsn)
    height + :aec_governance.name_claim_max_expiration(proto_vsn)
  end
end
