defmodule AeMdw.Db.OracleRegisterMutation do
  @moduledoc """
  Processes oracle_register_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  import AeMdw.Db.Oracle, only: [locate: 2]

  import AeMdw.Db.Sync.Oracle,
    only: [
      cache_through_delete: 3,
      cache_through_delete_inactive: 2,
      cache_through_write: 3
    ]

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
      case locate(state, oracle_pk) do
        nil ->
          {nil, state}

        {previous, Model.InactiveOracle} ->
          {previous, cache_through_delete_inactive(state, previous)}

        {previous, Model.ActiveOracle} ->
          Model.oracle(index: pubkey, expire: old_expire) = previous

          {previous,
           cache_through_delete(state, Model.ActiveOracleExpiration, {old_expire, pubkey})}
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
    |> cache_through_write(Model.ActiveOracle, m_oracle)
    |> cache_through_write(Model.ActiveOracleExpiration, m_exp_new)
    |> State.inc_stat(:oracles_registered)
  end
end
