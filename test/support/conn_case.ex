defmodule AeMdwWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use AeMdwWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Phoenix.ConnTest

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import AeMdw.TestUtil
      alias AeMdwWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint AeMdwWeb.Endpoint
    end
  end

  setup tags do
    alias AeMdw.Db.MemStore
    alias AeMdw.Db.NullStore

    if Map.get(tags, :integration, false) or Map.get(tags, :skip_store, false) do
      {:ok, conn: ConnTest.build_conn()}
    else
      {:ok, conn: ConnTest.build_conn(), store: MemStore.new(NullStore.new())}
    end
  end
end
