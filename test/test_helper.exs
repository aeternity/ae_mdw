config = ExUnit.configuration()

if :integration not in Keyword.fetch!(config, :include) do
  IO.puts("Stopping :aecore..")
  Application.stop(:aecore)
end

ExUnit.start()
