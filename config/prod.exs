import Config

config :ae_mdw, build_revision: String.trim(File.read!("AEMDW_REVISION"))
