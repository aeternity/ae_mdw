defmodule AeMdw.Db.OracleQueryMutation do
  @moduledoc """
  Processes oracle_query_tx.
  """

  alias AeMdw.Blocks
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Node.Db
  alias AeMdw.Oracles
  alias AeMdw.Txs

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:oracle_pk, :query_id, :txi, :sender_pk, :fee, :expiration_height]

  @typep height() :: Blocks.height()
  @typep amount() :: IntTransfer.amount()
  @typep query_id() :: Oracles.query_id()
  @opaque t() :: %__MODULE__{
            oracle_pk: Db.pubkey(),
            query_id: query_id(),
            txi: Txs.txi(),
            sender_pk: Db.pubkey(),
            fee: amount(),
            expiration_height: height()
          }

  @spec new(Db.pubkey(), query_id(), Txs.txi(), Db.pubkey(), amount(), height()) :: t()
  def new(oracle_pk, query_id, txi, sender_pk, fee, expiration_height) do
    %__MODULE__{
      oracle_pk: oracle_pk,
      query_id: query_id,
      txi: txi,
      sender_pk: sender_pk,
      fee: fee,
      expiration_height: expiration_height
    }
  end

  @spec execute(t(), State.t()) :: State.t()
  def execute(
        %__MODULE__{
          oracle_pk: oracle_pk,
          query_id: query_id,
          txi: txi,
          sender_pk: sender_pk,
          fee: fee,
          expiration_height: expiration_height
        },
        state
      ) do
    oracle_query =
      Model.oracle_query(
        index: {oracle_pk, query_id},
        txi: txi,
        fee: fee,
        expire: expiration_height,
        sender_pk: sender_pk
      )

    expiration = Model.oracle_query_expiration(index: {expiration_height, oracle_pk, query_id})

    state
    |> State.put(Model.OracleQuery, oracle_query)
    |> State.put(Model.OracleQueryExpiration, expiration)
  end
end
