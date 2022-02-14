defmodule AeMdw.NodeHelper do
  @moduledoc """
  Actual functions called by SmartGlobal AeMdw.Node.
  """

  alias AeMdw.Extract
  alias AeMdw.Util

  @spec record_keys(list(), atom()) :: [atom()]
  def record_keys(mod_code, rec_name) do
    {:ok, rec_code} = Extract.AbsCode.record_fields(mod_code, rec_name)
    Enum.map(rec_code, &elem(Extract.AbsCode.field_name_type(&1), 0))
  end

  @spec token_supply_delta() :: list()
  def token_supply_delta() do
    sum_vals = Util.compose(&Enum.sum/1, &Map.values/1)
    {genesis_accs, hfs} = Map.pop(mints(), "genesis")

    [
      {0, sum_vals.(genesis_accs)}
      | hfs
        |> Enum.map(fn {hf, accs} ->
          proto = String.to_existing_atom(hf)
          proto_vsn = :aec_hard_forks.protocol_vsn(proto)
          height = :aec_hard_forks.protocols()[proto_vsn]
          {height, sum_vals.(accs)}
        end)
        |> Enum.sort()
    ]
  end

  defp mints() do
    node_dir = Application.fetch_env!(:ae_plugin, :node_root)
    # Note: Path.wildcard ignores symlinks...
    acc_files = [_ | _] = :filelib.wildcard('#{node_dir}/**/accounts.json')

    acc_files
    |> Enum.map(fn f ->
      f = to_string(f)

      hf =
        Path.dirname(f)
        |> Path.split()
        |> Enum.at(-1)
        |> String.trim_leading(".")

      {hf, Jason.decode!(File.read!(f))}
    end)
    |> Enum.into(%{})
  end
end
