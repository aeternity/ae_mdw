%% -*- erlang-indent-mode: 4; indent-tabs-mode: nil -*-
-module(aeplugin_dev_mode_sup).
-behavior(supervisor).

-export([start_link/0,
         init/1]).


start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{ strategy  => one_for_one
                , intensity => 3
                , period    => 60 },
    {ok, {SupFlags, children()}}.


children() ->
    case aeplugin_dev_mode_app:emitter() of
        aeplugin_dev_mode_emitter = Emitter ->
            [
             #{ id       => Emitter
              , start    => {Emitter, start_link, []}
              , restart  => permanent
              , shutdown => 2000
              , type     => worker
              , modules  => [Emitter] }
            ];
        _ ->
            []
    end.
