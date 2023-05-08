-module(aeplugin_dev_mode_prefunded).

-export([ check_accounts/1
        , get_prefunded/0 ]).

-include("aeplugin_dev_mode.hrl").

check_accounts(WorkspaceDir) ->
    WSName = workspace_name(),
    Accounts = case read_accounts(WorkspaceDir, WSName) of
                   {ok, As} ->
                       As;
                   {error, _} ->
                       generate_accounts(WorkspaceDir, WSName)
               end,
    set_prefunded(Accounts),
    Accounts.

set_prefunded(Accs) ->
    persistent_term:put({?MODULE, prefunded_accounts}, Accs).

get_prefunded() ->
    persistent_term:get({?MODULE, prefunded_accounts}, []).

generate_accounts(WorkspacePath, WSName) ->
    %% A CLI tool will provide a path to a new DB folder or an existing DB
    %% (maybe for the sake of using some synced node data)
    %% So here we check whether that DB path already has any accounts data present.
    %% if not and there is no DB present, it's a new workspace, we generate accounts and
    %% set the env var for the node where to look for the accounts.
    %% The node later looks for that file if the env var is set and, if present,
    %% uses it instead of its hardcoded accounts json.
    %%
    %% check if there is already a mnesia folder present.
    %% if so, it's most likely an already existing chain sync and therefore don't generate any accounts.
    %% if not in a synced dir and no accounts files present, generate new json file.
    case filelib:is_dir(mnesia_monitor:get_env(dir)) of
        true ->
            [];
        false ->
            %% Do generate accounts
            %% TODO: Add further account creation options here, for now use default acc generating
            case generate_accounts_(WorkspacePath, WSName) of
                {ok, Filename, Accs} ->
                    aeu_plugins:suggest_config(prefunded_accs_cfg_key(), Filename),
                    Accs;
                error ->
                    []
            end
    end.

generate_accounts_(WSDir, WSName) ->
    try aeplugin_dev_mode_acc_gen:generate_accounts() of
        Accs ->
            format_generated_accounts(Accs, WSDir, WSName)
    catch
        error:_E1:_ST1 ->
            error
    end.

format_generated_accounts(Accs, WSDir, WSName) ->
    Filename = accounts_file(WSDir, WSName),
    case format_generated_accounts_(Accs) of
        {ok, JSON} ->
            file:write_file(Filename, JSON),
            {ok, Filename, Accs};
        error ->
            error
    end.

format_generated_accounts_(Accounts) ->
    Out = [#{ aeapi:format_account_pubkey(Pub) => Amt} ||
              #{pub_key := Pub, initial_balance := Amt} <- Accounts],
    try jsx:encode(Out) of
        JSON ->
            {ok, JSON}
    catch
        error:_E:_ST ->
            error
    end.

read_accounts(WSDir, WSName) ->
    {ok, Filename} = aeu_plugins:find_config(?PLUGIN_NAME_STR, [<<"prefunded_accounts_file">>],
                                             [user_config,
                                              {value, keyfile_path(WSDir, WSName)}]),
    read_prefunded_accounts_file(Filename).

read_prefunded_accounts_file(F) ->
    case file:read_file(F) of
        {ok, Bin} ->
            try jsx:decode(Bin, [return_maps]) of
                Encoded ->
                    %% While jsx is capable of parsing keys to existing atoms,
                    %% We don't need to be so strict about not allowing unknown
                    %% keys in the file. So we explicitly convert what we need.
                    {ok, [#{ pub_key => Pub
                           , priv_key => Priv
                           , initial_balance => Bal} ||
                             #{ <<"pub_key">> := Pub
                              , <<"priv_key">> := Priv
                              , <<"initial_balance">> := Bal} <- Encoded]}
            catch
                error:_E ->
                    {error, json_parse_error}
            end;
        {error, _E} = Error ->
            Error
    end.

prefunded_accs_cfg_key() ->
    [<<"system">>, <<"custom_prefunded_accs_file">>].

workspace_name() ->
    {ok, Name} = aeu_plugins:find_config(?PLUGIN_NAME_STR, [<<"workspace_name">>],
                                         [user_config, schema_default]),
    Name.

accounts_file(WSPath, WSName) ->
    Dir = filename:join(WSPath, WSName),
    filename:join(Dir, "devmode_prefunded_accs_.json").

keyfile_path(WSPath, WSName) ->
    Dir = filename:join(WSPath, WSName),
    filename:join(Dir, "devmode_acc_keys.json").
