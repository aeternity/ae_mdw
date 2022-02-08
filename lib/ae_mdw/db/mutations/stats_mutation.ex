defmodule AeMdw.Db.StatsMutation do
  @moduledoc """
  Inserts statistics about this generation into Model.Stat table.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Mnesia

  require Model

  defstruct [:stat, :total_stat]

  @type t() :: %__MODULE__{
          stat: Model.stat(),
          total_stat: Model.total_stat()
        }

  @spec new(Model.stat(), Model.total_stat()) :: t()
  def new(m_stat, m_total_stat) do
    %__MODULE__{
      stat: m_stat,
      total_stat: m_total_stat
    }
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        stat: stat,
        total_stat: total_stat
      }) do
    Mnesia.write(Model.Stat, stat)
    Mnesia.write(Model.TotalStat, total_stat)
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.StatsMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
