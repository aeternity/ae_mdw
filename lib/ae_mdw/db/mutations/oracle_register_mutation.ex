defmodule AeMdw.Db.OracleRegisterMutation do
  @moduledoc """
  Processes oracle_register_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.Oracle
  alias AeMdw.Db.Sync.Oracle, as: SyncOracle
  alias AeMdw.Db.State
  alias AeMdw.Db.Sync.ObjectKeys
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:oracle_pk, :block_index, :expire, :txi_idx]

  @typep expiration() :: Blocks.height()

  @opaque t() :: %__MODULE__{
            oracle_pk: Db.pubkey(),
            block_index: Blocks.block_index(),
            expire: expiration(),
            txi_idx: Txs.txi_idx()
          }

  @spec new(Db.pubkey(), Blocks.block_index(), expiration(), Txs.txi_idx()) :: t()
  def new(oracle_pk, block_index, expire, txi_idx) do
    %__MODULE__{
      oracle_pk: oracle_pk,
      block_index: block_index,
      expire: expire,
      txi_idx: txi_idx
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          oracle_pk: oracle_pk,
          block_index: {height, _mbi} = block_index,
          expire: expire,
          txi_idx: txi_idx
        },
        state
      ) do
    {previous, state2} = delete_existing(state, oracle_pk)

    m_oracle =
      Model.oracle(
        index: oracle_pk,
        active: height,
        expire: expire,
        register: {block_index, txi_idx},
        previous: previous
      )

    ObjectKeys.put_active_oracle(state, oracle_pk)

    SyncOracle.put_active(state2, m_oracle)
  end

  defp delete_existing(state, oracle_pk) do
    case Oracle.locate(state, oracle_pk) do
      nil ->
        {nil, state}

      {previous, Model.InactiveOracle} ->
        state2 = SyncOracle.delete_inactive(state, previous)

        {previous, state2}

      {previous, Model.ActiveOracle} ->
        Model.oracle(index: pubkey, expire: old_expire) = previous

        state2 =
          State.delete(
            state,
            Model.ActiveOracleExpiration,
            {old_expire, pubkey}
          )

        {previous, state2}
    end
  end
end
