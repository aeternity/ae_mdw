defmodule AeMdw.Db.OracleExtendMutation do
  @moduledoc """
  Processes oracle_extend_mutation.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.Sync.Oracle, as: SyncOracle
  alias AeMdw.Db.State
  alias AeMdw.Log
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:block_index, :txi, :oracle_pk, :delta_ttl]

  @opaque t() :: %__MODULE__{
            block_index: Blocks.block_index(),
            txi: Txs.txi(),
            oracle_pk: Db.pubkey(),
            delta_ttl: Blocks.height()
          }

  @spec new(Blocks.block_index(), Txs.txi(), Db.pubkey(), Blocks.height()) :: t()
  def new(block_index, txi, oracle_pk, delta_ttl) do
    %__MODULE__{
      block_index: block_index,
      txi: txi,
      oracle_pk: oracle_pk,
      delta_ttl: delta_ttl
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          block_index: {height, _mbi} = block_index,
          txi: txi,
          oracle_pk: oracle_pk,
          delta_ttl: delta_ttl
        },
        state
      ) do
    case Oracle.cache_through_read(state, Model.ActiveOracle, oracle_pk) do
      {:ok, Model.oracle(expire: old_expire, extends: extends) = m_oracle} ->
        new_expire = old_expire + delta_ttl
        extends = [{block_index, txi} | extends]
        m_exp = Model.expiration(index: {new_expire, oracle_pk})
        m_oracle = Model.oracle(m_oracle, expire: new_expire, extends: extends)

        state
        |> SyncOracle.cache_through_delete(Model.ActiveOracleExpiration, {old_expire, oracle_pk})
        |> SyncOracle.cache_through_write(Model.ActiveOracleExpiration, m_exp)
        |> SyncOracle.cache_through_write(Model.ActiveOracle, m_oracle)

      nil ->
        Log.warn("[#{height}] invalid extend for oracle #{Enc.encode(:oracle_pubkey, oracle_pk)}")
        state
    end
  end
end
