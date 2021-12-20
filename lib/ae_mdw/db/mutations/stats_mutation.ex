defmodule AeMdw.Db.StatsMutation do
  @moduledoc """
  Inserts statistics about this generation into Model.Stat table.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Mnesia

  require Model

  defstruct [:stat, :sum_stat]

  @type t() :: %__MODULE__{
          stat: Model.stat(),
          sum_stat: Model.sum_stat()
        }

  @spec new(Model.stat(), Model.sum_stat()) :: t()
  def new(m_stat, m_sum_stat) do
    %__MODULE__{
      stat: m_stat,
      sum_stat: m_sum_stat
    }
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        stat: stat,
        sum_stat: sum_stat
      }) do
    Mnesia.write(Model.Stat, stat)
    Mnesia.write(Model.SumStat, sum_stat)
  end
end

defimpl AeMdw.Db.Mutation, for: AeMdw.Db.StatsMutation do
  def mutate(mutation) do
    @for.mutate(mutation)
  end
end
