defmodule AeMdw.Db.OracleRegisterMutation do
  @moduledoc """
  Processes oracle_register_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.Oracle
  alias AeMdw.Node.Db
  alias AeMdw.Txs

  require Model

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

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        oracle_pk: oracle_pk,
        block_index: {height, _mbi} = block_index,
        expire: expire,
        txi: txi
      }) do
    previous =
      case Oracle.locate(oracle_pk) do
        nil ->
          nil

        {previous, Model.InactiveOracle} ->
          Oracle.cache_through_delete_inactive(previous)
          previous

        {previous, Model.ActiveOracle} ->
          Model.oracle(index: pubkey, expire: old_expire) = previous
          Oracle.cache_through_delete(Model.ActiveOracleExpiration, {old_expire, pubkey})
          previous
      end

    m_oracle =
      Model.oracle(
        index: oracle_pk,
        active: height,
        expire: expire,
        register: {block_index, txi},
        previous: previous
      )

    Oracle.cache_through_write(Model.ActiveOracle, m_oracle)
    m_exp_new = Model.expiration(index: {expire, oracle_pk})
    Oracle.cache_through_write(Model.ActiveOracleExpiration, m_exp_new)

    AeMdw.Ets.inc(:stat_sync_cache, :active_oracles)
    previous && AeMdw.Ets.dec(:stat_sync_cache, :inactive_oracles)

    :ok
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.OracleRegisterMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
