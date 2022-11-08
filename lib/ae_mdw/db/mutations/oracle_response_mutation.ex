defmodule AeMdw.Db.OracleResponseMutation do
  @moduledoc """
  Processes oracle_response_tx.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Blocks
  alias AeMdw.Db.IntTransfer
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Log
  alias AeMdw.Node.Db
  alias AeMdw.Oracles
  alias AeMdw.Txs

  require Model
  require Logger

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
    # Temporary conditional to handle those responses that don't have a query associated to them because
    # of the invalid nonce being sent on the Oracle.query contract calls.
    case State.get(state, Model.OracleQuery, {oracle_pk, query_id}) do
      {:ok, Model.oracle_query(expire: expiration_height, fee: fee)} ->
        state
        |> IntTransfer.write({height, txi}, "reward_oracle", oracle_pk, txi, fee)
        |> State.delete(Model.OracleQuery, {oracle_pk, query_id})
        |> State.delete(Model.OracleQueryExpiration, {expiration_height, oracle_pk, query_id})

      :not_found ->
        oracle = Enc.encode(:oracle_pubkey, oracle_pk)
        query_id = Enc.encode(:oracle_query_id, query_id)

        Log.info("[OracleResponseMutation] Oracle query #{oracle} not found for #{query_id}")
        state
    end
  end
end
