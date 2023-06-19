-module(aeplugin_dev_mode_acc_gen).
-export([ generate_from_mnemonic/3
        , generate_accounts/2
        , generate_accounts/0]).

%% Generates Accounts from sources like mnemonic and seed, utilising ebip39 and eaex10
%%
generate_from_mnemonic(Mnemonic, Quantity, Balance) ->
    Seed = ebip39:mnemonic_to_seed(Mnemonic, <<"">>),
    Derived = derive_from_seed(Seed, Quantity),
    format_accounts(Derived, Balance).

generate_accounts() ->
    generate_accounts(10, 1000000000000000000000).

generate_accounts(Quantity, Balance) ->
    Mnemonic = ebip39:generate_mnemonic(128),
    generate_from_mnemonic(Mnemonic, Quantity, Balance).

derive_from_seed(Seed, Quantity) ->
    [ eaex10:derive_aex10_from_seed(Seed, 0, Index) || Index <- lists:seq(1, Quantity) ].

format_accounts(DerivedKeys, Balance) ->
    [ format_account_(K, Balance) || K <- DerivedKeys ].

format_account_(K, Balance) ->
    AEX10 = eaex10:private_to_public(K),
    (maps:with([priv_key, pub_key], AEX10))#{initial_balance => Balance}.
