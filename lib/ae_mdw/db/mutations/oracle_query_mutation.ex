defmodule AeMdw.Db.OracleQueryMutation do
  @moduledoc """
  Processes oracle_query_tx.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Blocks
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Log
  alias AeMdw.Node.Db
  alias AeMdw.Oracles

  require Model
  require Logger

  @derive AeMdw.Db.Mutation
  defstruct [:oracle_pk, :query_id, :sender_pk, :fee, :expiration_height]

  @typep height() :: Blocks.height()
  @typep amount() :: IntTransfer.amount()
  @typep query_id() :: Oracles.query_id()
  @opaque t() :: %__MODULE__{
            oracle_pk: Db.pubkey(),
            query_id: query_id(),
            sender_pk: Db.pubkey(),
            fee: amount(),
            expiration_height: height()
          }

  @spec new(Db.pubkey(), query_id(), Db.pubkey(), amount(), height()) :: t()
  def new(oracle_pk, query_id, sender_pk, fee, expiration_height) do
    %__MODULE__{
      oracle_pk: oracle_pk,
      query_id: query_id,
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
          sender_pk: sender_pk,
          fee: fee,
          expiration_height: expiration_height
        },
        state
      ) do
    if State.exists?(state, Model.OracleQuery, {oracle_pk, query_id}) do
      oracle = Enc.encode(:oracle_pubkey, oracle_pk)
      query_id = Enc.encode(:oracle_query_id, query_id)

      Log.info("[OracleQueryMutation] Query ID #{query_id} for oracle #{oracle} already exists")
      state
    else
      oracle_query =
        Model.oracle_query(
          index: {oracle_pk, query_id},
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
end
