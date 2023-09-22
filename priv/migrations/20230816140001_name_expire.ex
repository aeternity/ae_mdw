defmodule AeMdw.Migrations.NameExpired.OldName do
  @moduledoc false
  require Record

  Record.defrecord(:name,
    index: nil,
    active: nil,
    expire: nil,
    revoke: nil,
    auction_timeout: nil,
    owner: nil,
    previous: nil
  )
end

defmodule AeMdw.Migrations.NameExpired do
  # credo:disable-for-this-file
  @moduledoc """
  Index name expirations.
  """

  alias __MODULE__.OldName
  alias AeMdw.Collection
  alias AeMdw.Db.Model
  alias AeMdw.Db.WriteMutation
  alias AeMdw.Db.State
  alias AeMdw.Log

  require Model
  require Record
  require OldName

  import AeMdw.Util, only: [max_int: 0]

  @first_printable_char :erlang.list_to_binary([32])

  @spec run(State.t(), boolean()) :: {:ok, non_neg_integer()}
  def run(state, _from_start?) do
    write_mutations1 = name_expired_mutations(state, Model.ActiveName)
    write_mutations2 = name_expired_mutations(state, Model.InactiveName)

    _state = State.commit(state, write_mutations1 ++ write_mutations2)
    {:ok, length(write_mutations1 ++ write_mutations2)}
  end

  defp name_expired_mutations(state, table) do
    state
    |> boundaries(table)
    |> Task.async_stream(fn key_boundary ->
      Log.info("Indexing expirations for #{inspect(key_boundary)}")

      state
      |> Collection.stream(table, :forward, key_boundary, nil)
      |> Stream.map(&State.fetch!(state, table, &1))
      |> filter_expired()
      |> Stream.map(fn Model.name(index: plain_name, active: active_from) ->
        m_name_expired = Model.name_expired(index: {plain_name, active_from, {max_int(), -1}})
        WriteMutation.new(Model.NameExpired, m_name_expired)
      end)
      |> Enum.to_list()
    end)
    |> Enum.map(fn {:ok, mutation} -> mutation end)
    |> List.flatten()
  end

  defp boundaries(state, table) do
    state
    |> State.next(table, @first_printable_char)
    |> Stream.unfold(fn
      :none ->
        nil

      {:ok, key} ->
        next_char = String.at(key, 0)

        next_key =
          next_char
          |> String.to_charlist()
          |> then(fn [char_int] -> <<char_int + 1::utf8>> end)

        boundary = {next_char, next_key}

        {boundary, State.next(state, table, next_key)}
    end)
    |> Enum.to_list()
  end

  def filter_expired(stream) do
    stream
    |> Stream.reject(&is_nil(OldName.name(&1, :previous)))
    |> Stream.map(&OldName.name(&1, :previous))
    |> Stream.filter(&is_nil(OldName.name(&1, :revoke)))
  end
end
