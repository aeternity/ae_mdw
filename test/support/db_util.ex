defmodule AeMdw.TestDbUtil do
  @moduledoc false

  alias AeMdw.Validate
  alias AeMdw.Db.Format
  alias AeMdw.Db.Model
  alias AeMdw.Db.Sync
  alias AeMdw.Db.Util

  require Model
  require Ex2ms

  @default_limit 10
  @mnesia_table Model.ContractLog
  @typep direction :: :forward | :backward

  @spec get_contract_logs_json(String.t(), direction(), Range.t()) :: String.t()
  def get_contract_logs_json(contract_id, direction \\ :forward, range \\ 1..@default_limit) do
    # Format.to_map fetches the log by index and formats it
    contract_id
    |> get_contract_logs_index(direction, range)
    |> Enum.map(&Format.to_map(&1, @mnesia_table))
    |> Jason.encode!()
  end

  @spec get_contract_logs_index(String.t(), direction(), Range.t()) :: [map()]
  def get_contract_logs_index(contract_id, direction, range) do
    ct_txi =
      contract_id
      |> Validate.id!()
      |> Sync.Contract.get_txi()

    log_index_spec =
      Ex2ms.fun do
        {:contract_log, {^ct_txi, call_txi, event_hash, log_idx}, _ext_contract_id, _args, _data} ->
          {^ct_txi, call_txi, event_hash, log_idx}
      end

    {invert_factor, sorting} = if direction == :forward, do: {-1, :asc}, else: {1, :desc}

    # sort contracts by call_txi and log_idx (inverted like the endpoint)
    @mnesia_table
    |> Util.select(log_index_spec)
    |> Enum.sort_by(&{elem(&1, 1), invert_factor * elem(&1, 3)}, sorting)
    |> Enum.drop(range.first - 1)
    |> Enum.take(range.last - range.first + 1)
  end
end
