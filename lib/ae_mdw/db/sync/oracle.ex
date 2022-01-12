defmodule AeMdw.Db.Sync.Oracle do
  @moduledoc """
  Save oracle state operations for each transaction type:
    - register
    - extend
    - expire
    - respond (query)
  """
  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.Model
  alias AeMdw.Log

  require Model
  require Logger

  import AeMdw.Db.Oracle,
    only: [
      cache_through_read: 2,
      cache_through_write: 2,
      cache_through_delete: 2
    ]

  @typep pubkey() :: <<_::256>>
  @typep tx_tuple() :: tuple()
  @typep block_index() :: {pos_integer(), non_neg_integer()}

  @spec extend(pubkey(), tx_tuple(), pos_integer(), block_index()) :: boolean()
  def extend(pubkey, tx, txi, bi) do
    case cache_through_read(Model.ActiveOracle, pubkey) do
      {:ok, m_oracle} ->
        {:delta, delta_ttl} = :aeo_extend_tx.oracle_ttl(tx)
        old_expire = Model.oracle(m_oracle, :expire)
        new_expire = old_expire + delta_ttl
        extends = [{bi, txi} | Model.oracle(m_oracle, :extends)]
        m_exp = Model.expiration(index: {new_expire, pubkey})
        cache_through_delete(Model.ActiveOracleExpiration, {old_expire, pubkey})
        cache_through_write(Model.ActiveOracleExpiration, m_exp)
        m_oracle = Model.oracle(m_oracle, expire: new_expire, extends: extends)
        cache_through_write(Model.ActiveOracle, m_oracle)
        true

      nil ->
        Log.warn(
          "[#{elem(bi, 0)}] invalid extend for oracle #{Enc.encode(:oracle_pubkey, pubkey)}"
        )

        false
    end
  end

  @doc """
  Updates the fees transfered after an Oracle query.
  """
  @spec respond(pubkey(), tx_tuple(), pos_integer(), block_index()) :: :ok
  def respond(pubkey, tx, txi, {height, _} = bi) do
    query_id = :aeo_response_tx.query_id(tx)
    o_tree = AeMdw.Db.Oracle.oracle_tree!(bi)

    try do
      fee =
        pubkey
        |> :aeo_state_tree.get_query(query_id, o_tree)
        |> :aeo_query.fee()

      AeMdw.Db.IntTransfer.write({height, txi}, "reward_oracle", pubkey, txi, fee)
    rescue
      # TreeId = <<OracleId/binary, QId/binary>>,
      # Serialized = aeu_mtrees:get(TreeId, Tree#oracle_tree.otree)
      # raises error on unexisting tree_id
      error -> Log.error(error)
    end

    :ok
  end
end
