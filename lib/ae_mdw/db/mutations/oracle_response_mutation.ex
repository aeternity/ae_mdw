defmodule AeMdw.Db.OracleResponseMutation do
  @moduledoc """
  Processes oracle_response_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil
  alias AeMdw.Node.Db
  alias AeMdw.Oracles
  alias AeMdw.Txs

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:block_index, :txi, :oracle_pk, :query_id]

  @typep query_id() :: Oracles.query_id()
  @opaque t() :: %__MODULE__{
            block_index: Blocks.block_index(),
            txi: Txs.txi(),
            oracle_pk: Db.pubkey(),
            query_id: query_id()
          }

  @spec new(Blocks.block_index(), Txs.txi(), Db.pubkey(), query_id()) :: t()
  def new(block_index, txi, oracle_pk, query_id) do
    %__MODULE__{
      block_index: block_index,
      txi: txi,
      oracle_pk: oracle_pk,
      query_id: query_id
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          block_index: {height, _mbi},
          txi: txi,
          oracle_pk: oracle_pk,
          query_id: query_id
        },
        state
      ) do
    Model.oracle_query(txi_idx: txi_idx) =
      State.fetch!(state, Model.OracleQuery, {oracle_pk, query_id})

    oracle_query_tx = DbUtil.read_node_tx(state, txi_idx)
    fee = :aeo_query_tx.query_fee(oracle_query_tx)

    IntTransfer.write(state, {height, txi}, "reward_oracle", oracle_pk, txi, fee)
  end
end
