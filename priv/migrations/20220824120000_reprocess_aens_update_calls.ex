defmodule AeMdw.Migrations.ReprocessAENSUpdateCalls do
  @moduledoc """
  Deals with the AENS.update calls which have an absolute name_ttl (expiration_height = name_ttl)
  but were processed as if they were relative (expiration_height = height + name_ttl)
  """

  alias AeMdw.Collection
  alias AeMdw.Db.DeleteKeysMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Util

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    case State.prev(state, Model.DeltaStat, nil) do
      {:ok, total_gens} -> run_with_gens(state, total_gens)
      :none -> {:ok, 0}
    end
  end

  defp run_with_gens(state, total_gens) do
    {mutations, expire_deletion_keys} =
      state
      |> Collection.stream(
        Model.FnameGrpIntContractCall,
        {"AENS.update", Util.min_int(), nil, nil}
      )
      |> Stream.take_while(&match?({"AENS.update", _create_txi, _call_txi, _local_idx}, &1))
      |> Stream.map(fn {"AENS.update", _create_txi, call_txi, local_idx} ->
        Model.int_contract_call(tx: tx) =
          State.fetch!(state, Model.IntContractCall, {call_txi, local_idx})

        {:name_update_tx, name_update_tx} = :aetx.specialize_type(tx)

        {name_update_tx, :aens_update_tx.name_ttl(name_update_tx)}
      end)
      |> Stream.reject(&match?({_tx, 0}, &1))
      |> Enum.flat_map_reduce([], fn {name_update_tx, new_expiration}, deletion_keys ->
        name_hash = :aens_update_tx.name_hash(name_update_tx)
        Model.plain_name(value: plain_name) = State.fetch!(state, Model.PlainName, name_hash)

        if new_expiration < total_gens do
          raise "name `#{plain_name}` already expired, can't reprocess it"
        end

        Model.name(expire: old_expire) =
          m_name = State.fetch!(state, Model.ActiveName, plain_name)

        new_m_name = Model.name(m_name, expire: new_expiration)
        new_m_name_exp = Model.expiration(index: {new_expiration, plain_name})

        {
          [
            WriteMutation.new(Model.ActiveNameExpiration, new_m_name_exp),
            WriteMutation.new(Model.ActiveName, new_m_name)
          ],
          [{old_expire, plain_name} | deletion_keys]
        }
      end)

    mutations = [
      DeleteKeysMutation.new(%{Model.ActiveNameExpiration => expire_deletion_keys}) | mutations
    ]

    _state = State.commit(state, mutations)

    {:ok, div(length(mutations), 2)}
  end
end
