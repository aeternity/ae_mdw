defmodule AeMdw.Migrations.AddMintingRevTransfer do
  @moduledoc """
  Adds minting rev (account->contract) aex9 transfer.
  """

  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.State
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Util

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    cursor = {:aex9, Util.min_bin(), -1, nil, nil, nil}

    count =
      state
      |> Collection.stream(Model.AexnTransfer, cursor)
      |> Stream.take_while(&match?({:aex9, _from_pk, _txi, _to_pk, _value, _index}, &1))
      |> Stream.reject(fn {:aex9, to_pk, _txi, from_pk, _value, _index} ->
        is_nil(to_pk) or is_nil(from_pk)
      end)
      |> Stream.map(fn {:aex9, from_pk, txi, to_pk, value, index} ->
        {:aex9, to_pk, txi, from_pk, value, index}
      end)
      |> Stream.reject(&State.exists?(state, Model.RevAexnTransfer, &1))
      |> Stream.map(&WriteMutation.new(Model.RevAexnTransfer, Model.rev_aexn_transfer(index: &1)))
      |> Stream.chunk_every(1000)
      |> Stream.map(fn mutations ->
        _state = State.commit_db(state, mutations)

        length(mutations)
      end)
      |> Enum.sum()

    {:ok, count}
  end
end
