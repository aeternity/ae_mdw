defmodule AeMdw.Migrations.AddInactiveChannelsActivation do
  @moduledoc """
  Indexes Model.InactiveChannelActivation table
  """

  alias AeMdw.Collection
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.Model
  alias AeMdw.Db.State

  require Model

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    mutations =
      state
      |> Collection.stream(Model.InactiveChannel, nil)
      |> Stream.map(fn key ->
        Model.channel(index: channel_pk, active: active_height) =
          State.fetch!(state, Model.InactiveChannel, key)

        WriteMutation.new(
          Model.InactiveChannelActivation,
          Model.activation(index: {active_height, channel_pk})
        )
      end)
      |> Enum.to_list()

    _new_state = State.commit(state, mutations)

    {:ok, length(mutations)}
  end
end
