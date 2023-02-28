defmodule AeMdw.Db.OracleQueryMutation do
  @moduledoc """
  Processes oracle_query_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db
  alias AeMdw.Oracles
  alias AeMdw.Txs

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:oracle_pk, :query_id, :txi_idx, :expiration_height]

  @typep height() :: Blocks.height()
  @typep query_id() :: Oracles.query_id()
  @opaque t() :: %__MODULE__{
            oracle_pk: Db.pubkey(),
            query_id: query_id(),
            txi_idx: Txs.txi_idx(),
            expiration_height: height()
          }

  @spec new(Db.pubkey(), query_id(), Txs.txi_idx(), height()) :: t()
  def new(oracle_pk, query_id, txi_idx, expiration_height) do
    %__MODULE__{
      oracle_pk: oracle_pk,
      query_id: query_id,
      txi_idx: txi_idx,
      expiration_height: expiration_height
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          oracle_pk: oracle_pk,
          query_id: query_id,
          txi_idx: txi_idx,
          expiration_height: expiration_height
        },
        state
      ) do
    oracle_query =
      Model.oracle_query(
        index: {oracle_pk, query_id},
        txi_idx: txi_idx
      )

    expiration = Model.oracle_query_expiration(index: {expiration_height, oracle_pk, query_id})

    state
    |> State.put(Model.OracleQuery, oracle_query)
    |> State.put(Model.OracleQueryExpiration, expiration)
  end
end
