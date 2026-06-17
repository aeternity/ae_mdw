defmodule AeMdwWeb.Plugs.GraphiQLPlug do
  @moduledoc """
  Serves the GraphiQL v5 playground UI only when the GRAPHIQL_ENABLED
  environment variable is set to "true".

  GraphQL queries are sent to the existing /graphql endpoint. The UI assets
  are loaded from esm.sh CDN at the pinned versions below.

  The flag is read from the Application environment, which is populated once
  at node startup from `runtime.exs`. Changing the environment variable on
  a running node has no effect — restart the node to pick up the new value.
  """

  @behaviour Plug

  # GraphiQL 5.2.4 — ESM-based CDN, no UMD bundle required.
  @graphiql_html """
  <!doctype html>
  <html lang="en">
    <head>
      <meta charset="UTF-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      <title>GraphiQL</title>
      <style>
        body { margin: 0; }
        #graphiql { height: 100dvh; }
        .loading { height: 100%; display: flex; align-items: center; justify-content: center; font-size: 2rem; }
      </style>
      <link rel="stylesheet" href="https://esm.sh/graphiql@5.2.4/dist/style.css" crossorigin="anonymous" />
      <script type="importmap">
        {
          "imports": {
            "react":             "https://esm.sh/react@19.2.7",
            "react/":            "https://esm.sh/react@19.2.7/",
            "react-dom":         "https://esm.sh/react-dom@19.2.7",
            "react-dom/":        "https://esm.sh/react-dom@19.2.7/",
            "graphiql":          "https://esm.sh/graphiql@5.2.4?standalone&external=react,react-dom,@graphiql/react,graphql",
            "graphiql/":         "https://esm.sh/graphiql@5.2.4/",
            "@graphiql/react":   "https://esm.sh/@graphiql/react@0.37.7?standalone&external=react,react-dom,graphql,@graphiql/toolkit,@emotion/is-prop-valid",
            "@graphiql/toolkit": "https://esm.sh/@graphiql/toolkit@0.12.1?standalone&external=graphql",
            "graphql":           "https://esm.sh/graphql@16.14.2",
            "@emotion/is-prop-valid": "data:text/javascript,"
          }
        }
      </script>
      <script type="module">
        import React from 'react';
        import ReactDOM from 'react-dom/client';
        import { GraphiQL } from 'graphiql';
        import { createGraphiQLFetcher } from '@graphiql/toolkit';
        import 'graphiql/setup-workers/esm.sh';

        const fetcher = createGraphiQLFetcher({ url: '/graphql' });

        ReactDOM.createRoot(document.getElementById('graphiql')).render(
          React.createElement(GraphiQL, { fetcher, defaultEditorToolsVisibility: true })
        );
      </script>
    </head>
    <body>
      <div id="graphiql">
        <div class="loading">Loading\u2026</div>
      </div>
    </body>
  </html>
  """

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    if Application.get_env(:ae_mdw, :graphiql_enabled, false) do
      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> Plug.Conn.send_resp(200, @graphiql_html)
      |> Plug.Conn.halt()
    else
      conn
      |> Plug.Conn.send_resp(404, "GraphiQL is not enabled on this instance")
      |> Plug.Conn.halt()
    end
  end
end
