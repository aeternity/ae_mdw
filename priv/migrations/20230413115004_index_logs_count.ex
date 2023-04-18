defmodule AeMdw.Migrations.IndexLogsCount do
  # credo:disable-for-this-file
  @moduledoc """
  Index aex9 logs count.
  """

  alias AeMdw.AexnContracts
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.Origin
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State
  alias AeMdw.Stats

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mint_hash = :aec_hash.blake2b_256_hash("Mint")
    burn_hash = :aec_hash.blake2b_256_hash("Burn")
    swap_hash = :aec_hash.blake2b_256_hash("Swap")
    transfer_hash = :aec_hash.blake2b_256_hash("Transfer")

    key_boundary = {{mint_hash, 0, 0, 0}, {mint_hash, nil, nil, nil}}
    mint_stream = Collection.stream(state, Model.EvtContractLog, :forward, key_boundary, nil)
    key_boundary = {{burn_hash, 0, 0, 0}, {burn_hash, nil, nil, nil}}
    burn_stream = Collection.stream(state, Model.EvtContractLog, :forward, key_boundary, nil)
    key_boundary = {{swap_hash, 0, 0, 0}, {swap_hash, nil, nil, nil}}
    swap_stream = Collection.stream(state, Model.EvtContractLog, :forward, key_boundary, nil)
    key_boundary = {{transfer_hash, 0, 0, 0}, {transfer_hash, nil, nil, nil}}
    transfer_stream = Collection.stream(state, Model.EvtContractLog, :forward, key_boundary, nil)

    write_mutations =
      [mint_stream, burn_stream, swap_stream, transfer_stream]
      |> Enum.flat_map(fn stream ->
        Enum.flat_map(stream, fn {_event_hash, _call_txi, create_txi, _log_idx} ->
          contract_pk = Origin.pubkey(state, {:contract, create_txi}) || <<>>

          if AexnContracts.is_aex9?(contract_pk) do
            [{contract_pk, 1}]
          else
            []
          end
        end)
      end)
      |> Enum.group_by(fn {pk, _amount} -> pk end)
      |> Enum.map(fn {contract_pk, list} ->
        key = Stats.aex9_logs_count_key(contract_pk)
        count = list |> Enum.map(fn {_pk, 1} -> 1 end) |> Enum.sum()
        WriteMutation.new(Model.Stat, Model.stat(index: key, payload: count))
      end)

    _state = State.commit(state, write_mutations)

    {:ok, length(write_mutations)}
  end
end
