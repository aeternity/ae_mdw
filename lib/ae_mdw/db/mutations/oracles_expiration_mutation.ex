defmodule AeMdw.Db.OraclesExpirationMutation do
  @moduledoc """
  Deactivate all Oracles that have expired on a block height.

  It also expires all oracle queries that have expired and creates the fee refund.

  The expiration height of an Oracle is always a result of the last `register`
   or `extend` operation.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Blocks
  alias AeMdw.Collection
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.Sync.Oracle, as: SyncOracle
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Log

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:height]

  @opaque t() :: %__MODULE__{
            height: Blocks.height()
          }

  @spec new(Blocks.height()) :: t()
  def new(height), do: %__MODULE__{height: height}

  @spec execute(t(), State.t()) :: State.t()
  def execute(%__MODULE__{height: height}, state) do
    state2 =
      state
      |> Collection.stream(Model.ActiveOracleExpiration, {height, <<>>})
      |> Stream.take_while(&match?({^height, _pk}, &1))
      |> Enum.reduce(state, fn {^height, pubkey}, state ->
        expire_oracle(state, height, pubkey)
      end)

    state2
    |> Collection.stream(Model.OracleQueryExpiration, {height, <<>>, <<>>})
    |> Stream.take_while(&match?({^height, _oracle_pk, _query_id}, &1))
    |> Enum.reduce(state2, fn {^height, oracle_pk, query_id}, state ->
      expire_oracle_query(state, height, oracle_pk, query_id)
    end)
  end

  defp expire_oracle_query(state, height, oracle_pk, query_id) do
    Model.oracle_query(txi_idx: txi_idx) =
      State.fetch!(state, Model.OracleQuery, {oracle_pk, query_id})

    oracle_query_tx = DbUtil.read_node_tx(state, txi_idx)
    fee = :aeo_query_tx.query_fee(oracle_query_tx)
    sender_pk = :aeo_query_tx.sender_pubkey(oracle_query_tx)

    IntTransfer.fee(state, {height, -1}, :refund_oracle, sender_pk, txi_idx, fee)
  end

  defp expire_oracle(state, height, pubkey) do
    oracle_id = Enc.encode(:oracle_pubkey, pubkey)

    state2 =
      SyncOracle.cache_through_delete(state, Model.ActiveOracleExpiration, {height, pubkey})

    case Oracle.cache_through_read(state2, Model.ActiveOracle, pubkey) do
      {:ok, m_oracle} ->
        if height == Model.oracle(m_oracle, :expire) do
          m_exp = Model.expiration(index: {height, pubkey})

          Log.info("[#{height}] inactivated oracle #{oracle_id}")

          state2
          |> SyncOracle.cache_through_write(Model.InactiveOracle, m_oracle)
          |> SyncOracle.cache_through_write(Model.InactiveOracleExpiration, m_exp)
          |> SyncOracle.cache_through_delete(Model.ActiveOracle, pubkey)
          |> State.inc_stat(:oracles_expired)
        else
          Log.warn("[#{height}] ignored old oracle expiration for #{oracle_id}")
          state2
        end

      nil ->
        Log.warn("[#{height}] ignored oracle expiration for #{oracle_id}")
        state2
    end
  end
end
