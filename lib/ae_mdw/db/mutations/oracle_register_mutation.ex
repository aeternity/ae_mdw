defmodule AeMdw.Db.OracleRegisterMutation do
  @moduledoc """
  Processes oracle_register_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.Sync.Oracle, as: SyncOracle
  alias AeMdw.Db.State
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:oracle_pk, :block_index, :expire, :txi]

  @typep expiration() :: Blocks.height()

  @opaque t() :: %__MODULE__{
            oracle_pk: Db.pubkey(),
            block_index: Blocks.block_index(),
            expire: expiration(),
            txi: Txs.txi()
          }

  @spec new(Db.pubkey(), Blocks.block_index(), expiration(), Txs.txi()) :: t()
  def new(oracle_pk, block_index, expire, txi) do
    %__MODULE__{
      oracle_pk: oracle_pk,
      block_index: block_index,
      expire: expire,
      txi: txi
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          oracle_pk: oracle_pk,
          block_index: {height, _mbi} = block_index,
          expire: expire,
          txi: txi
        },
        state
      ) do
    {previous, state2} =
      case Oracle.locate(state, oracle_pk) do
        nil ->
          {nil, state}

        {previous, Model.InactiveOracle} ->
          state2 = SyncOracle.cache_through_delete_inactive(state, previous)
          {previous, state2}

        {previous, Model.ActiveOracle} ->
          Model.oracle(index: pubkey, expire: old_expire) = previous

          state2 =
            SyncOracle.cache_through_delete(
              state,
              Model.ActiveOracleExpiration,
              {old_expire, pubkey}
            )

          {previous, state2}
      end

    m_oracle =
      Model.oracle(
        index: oracle_pk,
        active: height,
        expire: expire,
        register: {block_index, txi},
        previous: previous
      )

    m_exp_new = Model.expiration(index: {expire, oracle_pk})

    state2
    |> SyncOracle.cache_through_write(Model.ActiveOracle, m_oracle)
    |> SyncOracle.cache_through_write(Model.ActiveOracleExpiration, m_exp_new)
    |> State.inc_stat(:oracles_registered)
  end
end
