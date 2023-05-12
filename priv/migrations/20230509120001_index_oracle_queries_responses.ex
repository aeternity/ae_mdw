defmodule AeMdw.Migrations.IndexOracleQueriesResponses do
  @moduledoc """
  Indexes new Model.oracle_query response_txi_idx attribute.
  """

  alias :aeser_api_encoder, as: Enc
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.Util, as: DbUtil

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations =
      state
      |> DbUtil.transactions_of_type(:oracle_response_tx, :forward, nil, nil)
      |> Stream.map(fn response_txi_idx ->
        oracle_response_tx = DbUtil.read_node_tx(state, response_txi_idx)
        oracle_pk = :aeo_response_tx.oracle_pubkey(oracle_response_tx)
        query_id = :aeo_response_tx.query_id(oracle_response_tx)

        case State.get(state, Model.OracleQuery, {oracle_pk, query_id}) do
          {:ok, {:oracle_query, index, txi_idx}} ->
            oracle_query =
              Model.oracle_query(
                index: index,
                txi_idx: txi_idx,
                response_txi_idx: response_txi_idx
              )

            WriteMutation.new(Model.OracleQuery, oracle_query)

          :not_found ->
            IO.puts("""
              [OracleResponseMutation] Oracle response not found on txi #{inspect(response_txi_idx)} for #{Enc.encode(:oracle_pubkey, oracle_pk)}
              (query #{Enc.encode(:oracle_query_id, query_id)}).
              Probably due to ga_meta transaction not calculating nonce correcctly.
            """)

            nil
        end
      end)
      |> Enum.to_list()

    _new_state = State.commit(state, mutations)

    {:ok, length(mutations)}
  end
end
