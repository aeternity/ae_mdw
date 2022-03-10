defmodule AeMdw.Db.StatsMutation do
  @moduledoc """
  Inserts statistics about this generation into Model.DeltaStat table.
  """

  alias AeMdw.Db.Model
  alias AeMdw.Database

  require Model

  @derive AeMdw.Db.TxnMutation
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

  @spec execute(t(), Database.transaction()) :: :ok
  def execute(
        %__MODULE__{
          delta_stat: delta_stat,
          total_stat: total_stat
        },
        txn
      ) do
    Database.write(txn, Model.DeltaStat, delta_stat)
    Database.write(txn, Model.TotalStat, total_stat)
  end
end
