Application.load(:ae_mdw)

for app <- Application.spec(:ae_mdw, :applications) do
  Application.ensure_all_started(app)
end

ExUnit.start()
