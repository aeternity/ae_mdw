defmodule AeMdw.Db.StatsMutation do
  @moduledoc """
  Inserts statistics about this generation into Model.DeltaStat table.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Database

  require Model

  @derive AeMdw.Db.Mutation
  defstruct [:delta_stat, :total_stat]

  @type t() :: %__MODULE__{
          delta_stat: Model.delta_stat(),
          total_stat: Model.total_stat()
        }

  @spec new(Model.delta_stat(), Model.total_stat()) :: t()
  def new(m_delta_stat, m_total_stat) do
    %__MODULE__{
      delta_stat: m_delta_stat,
      total_stat: m_total_stat
    }
  end

  @spec mutate(t()) :: :ok
  def mutate(%__MODULE__{
        delta_stat: delta_stat,
        total_stat: total_stat
      }) do
    Database.write(Model.DeltaStat, delta_stat)
    Database.write(Model.TotalStat, total_stat)
  end
end
