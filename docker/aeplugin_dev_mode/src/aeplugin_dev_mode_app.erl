-module(aeplugin_dev_mode_app).
-behavior(application).

-export([ start_unlink/0,
          start/2,
          start_phase/3,
          stop/1 ]).

-export([ check_env/0 ]).

-export([ info/0 ]).

-export([emitter/0]).

-include("aeplugin_dev_mode.hrl").

start_unlink() ->
  persistent_term:put({aeplugin_dev_mode_app, dev_mode_emitter}, aeplugin_dev_mode_emitter),
  gen_server:start({local, aeplugin_dev_mode_emitter}, aeplugin_dev_mode_emitter, [], []),
  ok = start_http_api(),
  aeplugin_dev_mode_emitter:auto_emit_microblocks(true).

start(_Type, _Args) ->
    {ok, Pid} = aeplugin_dev_mode_sup:start_link(),
    ok = start_http_api(),
    {ok, Pid}.

start_phase(check_config, _Type, _Args) ->
    case aeu_plugins:find_config(?PLUGIN_NAME_STR, [], [user_config, schema_default]) of
        undefined ->
            ok;
        {ok, Config} ->
            apply_config(Config)
    end.

stop(_State) ->
    stop_http_api(),
    ok.


check_env() ->
    aeu_plugins:check_config(?PLUGIN_NAME_STR, ?SCHEMA_FNAME, ?OS_ENV_PFX),
    WorkspaceDir = determine_workspace_dir(),
    Accs = aeplugin_dev_mode_prefunded:check_accounts(WorkspaceDir),
    case Accs =/= [] of
        true ->
            Pub = case Accs of
                [ #{pub_key := PubKey} | _ ] ->
                    PubKey;
                Other ->
                    erlang:error({invalid_devmode_data_format_found, Other})
                end,
            maybe_set_beneficiary(enc_pub_key(Pub));
        false ->
            % if it's devmode and there are no accounts found, it can only be a synced node or
            % one that has a DB with the previous hardcoded test keypair.
            #{pubkey := Pub} = aecore_env:patron_keypair_for_testing(),
            maybe_set_beneficiary(enc_pub_key(Pub))
        end,
    ok.

enc_pub_key(Pub) ->
    aeapi:format_account_pubkey(Pub).

maybe_set_beneficiary(Pub) ->
    case aecore_env:is_dev_mode() of
        true ->
            aeu_plugins:suggest_config([<<"mining">>, <<"beneficiary">>], Pub),
            aeu_plugins:suggest_config([<<"mining">>, <<"beneficiary_reward_delay">>], 2);
        false ->
            ignore
    end.

determine_workspace_dir() ->
    case aeu_plugins:find_config(?PLUGIN_NAME_STR, [<<"workspace_path">>], [user_config]) of
        undefined ->
            Dir = aeu_plugins:data_dir(?PLUGIN_NAME_STR),
            ok = filelib:ensure_dir(filename:join(Dir, "foo")),
            Dir;
        {ok, Dir} ->
            Dir
    end.



start_http_api() ->
    Port = get_http_api_port(),
    Dispatch = cowboy_router:compile(aeplugin_dev_mode_handler:routes()),
    {ok, _} = cowboy:start_clear(devmode_listener,
                                 [{port, Port}],
                                 #{env => #{dispatch => Dispatch}}),
    ok.

stop_http_api() ->
    cowboy:stop_listener(devmode_listener).

get_http_api_port() ->
    list_to_integer(os:getenv("AE_DEVMODE_PORT", "3313")).

apply_config(_Config) ->
    ok.

info() ->
    M = emitter(),
    #{ keyblock_interval      => M:get_keyblock_interval()
     , microblock_interval    => M:get_microblock_interval()
     , auto_demit_microblocks => M:get_auto_emit_microblocks()
     }.

emitter() ->
    K = {?MODULE, dev_mode_emitter},
    case persistent_term:get(K, undefined) of
        undefined ->
            try aedevmode_emitter:module_info(module) of
                M ->
                    persistent_term:put(K, M)
            catch
                error:_ ->
                    Mine = aeplugin_dev_mode_emitter,
                    persistent_term:put(K, Mine),
                    Mine
            end;
        M ->
            M
    end.
