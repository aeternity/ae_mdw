# Changelog

### [1.2.1](https://www.github.com/aeternity/ae_mdw/compare/v1.2.0...v1.2.1) (2021-11-04)


### Bug Fixes

* gameta claimed name rendering ([ce9293b](https://www.github.com/aeternity/ae_mdw/commit/ce9293bf582a7e799710f90ca4974f033dc45b84))

## [1.2.0](https://www.github.com/aeternity/ae_mdw/compare/v1.1.0...v1.2.0) (2021-11-03)


### Features

* account presence based on aex9 balance ([#262](https://www.github.com/aeternity/ae_mdw/issues/262)) ([57c1ef3](https://www.github.com/aeternity/ae_mdw/commit/57c1ef3af7dfc19f0f1096ded8e0585899214dd4))
* add cursor-based pagination to scoped txs ([67b7097](https://www.github.com/aeternity/ae_mdw/commit/67b7097cbe9748e053bd830e4d4b3b5dc78c546a))
* add gas_used to create contract tx info ([#258](https://www.github.com/aeternity/ae_mdw/issues/258)) ([6dc5577](https://www.github.com/aeternity/ae_mdw/commit/6dc55775f946e7f9fac1395b70022aa2ab51b06d))
* add name hash to owned_by response ([#299](https://www.github.com/aeternity/ae_mdw/issues/299)) ([a148f7b](https://www.github.com/aeternity/ae_mdw/commit/a148f7ba2bdfcce8e68966a7f87ae32ad888d879))
* add recipient details for /tx and /txi ([#318](https://www.github.com/aeternity/ae_mdw/issues/318)) ([7868e9d](https://www.github.com/aeternity/ae_mdw/commit/7868e9d2ee949ef89d1899684d4f117490464f61))
* add support for Chain.clone and Chain.create events ([8e3b0c8](https://www.github.com/aeternity/ae_mdw/commit/8e3b0c8b5eed1fafc265b3da85596614a0328bf1)), closes [#208](https://www.github.com/aeternity/ae_mdw/issues/208)
* async account aex9 presence ([#279](https://www.github.com/aeternity/ae_mdw/issues/279)) ([2c0d44d](https://www.github.com/aeternity/ae_mdw/commit/2c0d44d022d16d46daa9a4e7b4ba5e635ff119d2))
* async tasks status ([#286](https://www.github.com/aeternity/ae_mdw/issues/286)) ([6ccce3d](https://www.github.com/aeternity/ae_mdw/commit/6ccce3db7fde45d7cf9eef5121ec89336c2d8714))
* auto migrate_db on start ([#261](https://www.github.com/aeternity/ae_mdw/issues/261)) ([a577816](https://www.github.com/aeternity/ae_mdw/commit/a5778165273fb507b0752d2028d4177102eb635b))
* contract calls with dry-run ([8407dc0](https://www.github.com/aeternity/ae_mdw/commit/8407dc03276c20b344ee4c0213ea4c54edf66805))
* contract create init details ([#310](https://www.github.com/aeternity/ae_mdw/issues/310)) ([aa8158d](https://www.github.com/aeternity/ae_mdw/commit/aa8158d2389a34a7d4812876dc1361f3830e8dea))
* delay slow aex9 migration balance ([6e885fa](https://www.github.com/aeternity/ae_mdw/commit/6e885faeb6c2b5618f3dd7fba5d5ac7732db7442))
* publish to websocket subs afer height sync ([#304](https://www.github.com/aeternity/ae_mdw/issues/304)) ([d0696f8](https://www.github.com/aeternity/ae_mdw/commit/d0696f89bf94a2f2e43ee60a11fe56917f2ef7de))


### Bug Fixes

* add AETERNITY_CONFIG env variable to docker-compose ([8d49e3d](https://www.github.com/aeternity/ae_mdw/commit/8d49e3d14b278504f0d479f3c1ac4ced8d50c9ad))
* add ex_json_schema to deps for phoenix_swagger to use ([21aa314](https://www.github.com/aeternity/ae_mdw/commit/21aa3141c534508bcbdbff6a53cf0a4a53af025d))
* adjust Mnesia module return types for consistency ([86bae6e](https://www.github.com/aeternity/ae_mdw/commit/86bae6e0098fa6f0f4e57716548ee7883fbfa86d))
* aex9 presence async processing state ([#290](https://www.github.com/aeternity/ae_mdw/issues/290)) ([bb53964](https://www.github.com/aeternity/ae_mdw/commit/bb53964e790000ef0b4cd64ef0ff0f3973e06cbc))
* aex9 presence check demands mnesia ctx ([56d33fc](https://www.github.com/aeternity/ae_mdw/commit/56d33fcf6c4005dfee8a736ed4aa6bba9a3fce08))
* aex9 presence write within transaction ([#282](https://www.github.com/aeternity/ae_mdw/issues/282)) ([f342d50](https://www.github.com/aeternity/ae_mdw/commit/f342d50e475feeef0e8c5d2774696d823a476e86))
* application init warning ([5461dc2](https://www.github.com/aeternity/ae_mdw/commit/5461dc273176a94ee5b381ea9f9ae4e0c8966543))
* base64 encode queries when returning oracle query txs ([#274](https://www.github.com/aeternity/ae_mdw/issues/274)) ([239c967](https://www.github.com/aeternity/ae_mdw/commit/239c967a271b92c2f0fd7a719cfe32e242c80b56)), closes [#264](https://www.github.com/aeternity/ae_mdw/issues/264)
* duplicated indexation when receiver=sender ([3a878e4](https://www.github.com/aeternity/ae_mdw/commit/3a878e4f4ad388add8155b9af94f97984ee43999))
* fix /txs route handling ([#296](https://www.github.com/aeternity/ae_mdw/issues/296)) ([c1d1e1b](https://www.github.com/aeternity/ae_mdw/commit/c1d1e1b78d8706351b97f5e6d13e1bf428397f74))
* fix default range gen fetching ([095315c](https://www.github.com/aeternity/ae_mdw/commit/095315cf1f3171456419c27111f352daade69a9b))
* fix dockerfile for multiple node releases ([d6c52cb](https://www.github.com/aeternity/ae_mdw/commit/d6c52cb37249ae565c50aa5d9f1c62d7980b6cf6))
* handle contracts w/o creation tx gracefully and consistently ([#293](https://www.github.com/aeternity/ae_mdw/issues/293)) ([c68cb66](https://www.github.com/aeternity/ae_mdw/commit/c68cb66974d87eaac3bbdbdb6d07e3c69fec2c6b)), closes [#269](https://www.github.com/aeternity/ae_mdw/issues/269) [#208](https://www.github.com/aeternity/ae_mdw/issues/208)
* internal server error on aex9 balance(s) range ([#297](https://www.github.com/aeternity/ae_mdw/issues/297)) ([1757f4c](https://www.github.com/aeternity/ae_mdw/commit/1757f4c0f5f9290e23068a6c8aec76a8d46e680b))
* missing AeMdw.Txs alias from rebase ([778c059](https://www.github.com/aeternity/ae_mdw/commit/778c0596084e697ec5b15afa75d00902baeb43d4))
* mix version comma ([bbc74ac](https://www.github.com/aeternity/ae_mdw/commit/bbc74ac6c532873ba54fe245d7e5346b7bc20e94))
* name auction bid details when expand=true ([83d3831](https://www.github.com/aeternity/ae_mdw/commit/83d3831bf744714f271d6fcd9cbca80bec27998a))
* oracle expire validation ([#315](https://www.github.com/aeternity/ae_mdw/issues/315)) ([3bcb95f](https://www.github.com/aeternity/ae_mdw/commit/3bcb95fc979cecce3c295409b9e75da8dbb3f772))
* oracle extend validation ([#306](https://www.github.com/aeternity/ae_mdw/issues/306)) ([781c4b7](https://www.github.com/aeternity/ae_mdw/commit/781c4b78dc660e795a8b25bca4bdd938c37638c1))
* rescue :aeo_state_tree.get_query error ([326a528](https://www.github.com/aeternity/ae_mdw/commit/326a5285b8da0cb325404c064aef2096644ae6bd))
* return nil when contract tries fetching non-synced tx ([#272](https://www.github.com/aeternity/ae_mdw/issues/272)) ([61d3622](https://www.github.com/aeternity/ae_mdw/commit/61d36222312b91343be8e6875677ecccbf48f3db))
* revert field indexation (keeps both fields) ([a03e1cf](https://www.github.com/aeternity/ae_mdw/commit/a03e1cfda2987d41f68513eed532fa2c65284b60))
* set :app_ctrl mode to :normal to allow MDW to sync ([#284](https://www.github.com/aeternity/ae_mdw/issues/284)) ([b546d72](https://www.github.com/aeternity/ae_mdw/commit/b546d72055d7c6f9818fe33da8c9396146e61257))
* start :aesync and :app_ctrl_server when initializing app ([23c41ef](https://www.github.com/aeternity/ae_mdw/commit/23c41efff41dfb7ba2f467bb818afc0b8ae7f2fc)), closes [#275](https://www.github.com/aeternity/ae_mdw/issues/275)
* start all aecore services after starting app_ctrl_server ([351c9cf](https://www.github.com/aeternity/ae_mdw/commit/351c9cf3a43162593c90ab608444f61872db133c))


### Miscellaneous

* base documentation on hosted infrastructure ([20d6ee4](https://www.github.com/aeternity/ae_mdw/commit/20d6ee4239639926a0e7da688ec22665ca80e02b))
* expose service ports when starting docker-shell container ([#291](https://www.github.com/aeternity/ae_mdw/issues/291)) ([9886344](https://www.github.com/aeternity/ae_mdw/commit/9886344e764082c714b9968bc73c59391f9fc6d1))
* simplified account presence filtering ([#271](https://www.github.com/aeternity/ae_mdw/issues/271)) ([f41b9e6](https://www.github.com/aeternity/ae_mdw/commit/f41b9e654e67d44605ed57d00e2a525267580f13))


### CI / CD

* credo and unused code ([14acf7c](https://www.github.com/aeternity/ae_mdw/commit/14acf7c08aa6436a035e46337412edb9a35ba253))
* dialyzer ([4800c8f](https://www.github.com/aeternity/ae_mdw/commit/4800c8f55dc5e0d3f8f40d5d3b7e57a49ae8bc15))
* new plt version ([daea38e](https://www.github.com/aeternity/ae_mdw/commit/daea38e4ae1cefce8c31499c9ce7de64e0cf43d2))
* new plt version ([399ed19](https://www.github.com/aeternity/ae_mdw/commit/399ed195d4980e320262cebae4c1ea35eb6c5bb0))
* plt version ([cdc14d9](https://www.github.com/aeternity/ae_mdw/commit/cdc14d9225db2bd7c0817e954e314fbbb5d853e7))
* revert force PLT creation ([ce3aedf](https://www.github.com/aeternity/ae_mdw/commit/ce3aedf2b206ad91544105c321df824e1d2ce6b1))
* temp delete priv/plts ([82cb5ba](https://www.github.com/aeternity/ae_mdw/commit/82cb5bada87ac1ee9689e03493b7d4a29f37658b))
* temporarily create plt without condition ([f1f78d8](https://www.github.com/aeternity/ae_mdw/commit/f1f78d837168e5ba2d02e22545983ae26ff637e8))
* temporarily remove old plt file ([bd601f8](https://www.github.com/aeternity/ae_mdw/commit/bd601f8ba012e0a67f4beac382643edc7df1e5c5))


### Testing

* add async task produce/consume tc ([b19adda](https://www.github.com/aeternity/ae_mdw/commit/b19addaa0fd6db925af62b8b813e5d4f1c3dca98))
* add sender = recipient integration case ([58ae0de](https://www.github.com/aeternity/ae_mdw/commit/58ae0de58cdc09322b7da033fb905c8480aac8ef))
* add sync_transaction write fields test ([27a070a](https://www.github.com/aeternity/ae_mdw/commit/27a070accab60b9e3acec5e618db29777e12078b))
* add tests to Chain.clone events handling ([9fce49f](https://www.github.com/aeternity/ae_mdw/commit/9fce49f5146bbfe5b785c12e49bb994550a065b2))
* additional sync case when recipient = sender ([edb9d1e](https://www.github.com/aeternity/ae_mdw/commit/edb9d1e2ff01687e563f6cc3cfb18676703905ab))
* fix oracles integration tests ([#255](https://www.github.com/aeternity/ae_mdw/issues/255)) ([14c59fb](https://www.github.com/aeternity/ae_mdw/commit/14c59fbae824e4c9ff6260c5ec4307f01d25b4b8))
* fix oracles/names tests ([d5cb035](https://www.github.com/aeternity/ae_mdw/commit/d5cb035194196778999445b6fbc4856596e86c1c))
* replace last_txi with very high value ([33e2d87](https://www.github.com/aeternity/ae_mdw/commit/33e2d87ebdc6b766535d9bdf078bfc2b1f8f6e1d))
* uniq integration case check for recipient = sender ([a81513f](https://www.github.com/aeternity/ae_mdw/commit/a81513f286263e7ff7c345503e2baead3a39bd6c))
* use mnesia sandbox ([90e6688](https://www.github.com/aeternity/ae_mdw/commit/90e6688b8840bd1d2a1af72653acbcc95bcf048d))


### Refactorings

* add :scope, :query and :offset to Conn.assigns ([6661134](https://www.github.com/aeternity/ae_mdw/commit/6661134376f99f28f9f9b2a4f7594a4513691683))
* add Collection module to deal with complex pagination ([#256](https://www.github.com/aeternity/ae_mdw/issues/256)) ([c89ec18](https://www.github.com/aeternity/ae_mdw/commit/c89ec1880726cac5239a09996b142f1b9e024b0b))
* add paginated auction name endpoints ([#260](https://www.github.com/aeternity/ae_mdw/issues/260)) ([8d8bf9b](https://www.github.com/aeternity/ae_mdw/commit/8d8bf9b9833505a8cf2aa4c825e873609bd280c9))
* add paginated name endpoints without making use of streams ([#257](https://www.github.com/aeternity/ae_mdw/issues/257)) ([6a460e0](https://www.github.com/aeternity/ae_mdw/commit/6a460e02f443d737f243dc0fcc46ffcc5d7147f6))
* add paginated txs endpoint ([#283](https://www.github.com/aeternity/ae_mdw/issues/283)) ([435d184](https://www.github.com/aeternity/ae_mdw/commit/435d1841544fea47d07019f3d7812ec9c4891d1c))
* convert from gen to txi differently ([2d3cdea](https://www.github.com/aeternity/ae_mdw/commit/2d3cdea7b0c2d66a642e5fb6235b6289c3d56e04))
* migration logs with Log.info ([f9b4e15](https://www.github.com/aeternity/ae_mdw/commit/f9b4e157ca8d9baaca7e27e3adbdd4d7fde35f95))
* move first_gen! and last_gen! to Db.Util module ([385e00f](https://www.github.com/aeternity/ae_mdw/commit/385e00f2232f334739c42d1825cda205fd78961f))
* only add contract creation txs when tx_type is contract ([63417ee](https://www.github.com/aeternity/ae_mdw/commit/63417ee75a0aca7789da5836af726b8b1f59abfa))
* use aetx getters for retrieving tx fields ([4197983](https://www.github.com/aeternity/ae_mdw/commit/41979837812c502cb1a926782fd2be5d5fd69457))

## [1.1.0](https://www.github.com/aeternity/ae_mdw/compare/v1.0.9...v1.1.0) (2021-09-17)


### Features

* /v2/blocks endpoint returns mbs sorted by time ([#236](https://www.github.com/aeternity/ae_mdw/issues/236)) ([9111b83](https://www.github.com/aeternity/ae_mdw/commit/9111b83cf2599927df19b5371a7e090f1367732b))
* add oracles v2 endpoint without making use of streams ([#249](https://www.github.com/aeternity/ae_mdw/issues/249)) ([17cbdfb](https://www.github.com/aeternity/ae_mdw/commit/17cbdfb4e7838359f8f8f6d411ffa32169ba8215))
* adds recipient account and name to spendtx ([#237](https://www.github.com/aeternity/ae_mdw/issues/237)) ([e06296d](https://www.github.com/aeternity/ae_mdw/commit/e06296d25038e624b0aaf2f4c5e6faa21653b363))
* backup and restore db table ([#227](https://www.github.com/aeternity/ae_mdw/issues/227)) ([a39cac6](https://www.github.com/aeternity/ae_mdw/commit/a39cac6345fb618a681dc77fd26ef32a26521092))
* index inner transactions ([#248](https://www.github.com/aeternity/ae_mdw/issues/248)) ([0a02727](https://www.github.com/aeternity/ae_mdw/commit/0a02727c51095d16a25f0794be258ef13dec694e))
* restructure ETS stateful DB streams implementation ([#241](https://www.github.com/aeternity/ae_mdw/issues/241)) ([40a2a3d](https://www.github.com/aeternity/ae_mdw/commit/40a2a3dd07029af264a8d46bcb03aa412ab25994))


### Bug Fixes

* adjust tuple structure sent on AEX9 balances endpoints ([06a570e](https://www.github.com/aeternity/ae_mdw/commit/06a570e1196d93d1028f5e9d29a58465a7d7df5e))
* don't read from cache the last 6 blocks ([#210](https://www.github.com/aeternity/ae_mdw/issues/210)) ([64d9dd5](https://www.github.com/aeternity/ae_mdw/commit/64d9dd53431ac3626ed598e3d353c27da53dfffe))
* indexes remote call event logs also by called contract ([#222](https://www.github.com/aeternity/ae_mdw/issues/222)) ([27e08aa](https://www.github.com/aeternity/ae_mdw/commit/27e08aa3944f22a3a46d6c552be4e123176491d1))
* recipient account is the pointee if name have one ([#242](https://www.github.com/aeternity/ae_mdw/issues/242)) ([534fd7f](https://www.github.com/aeternity/ae_mdw/commit/534fd7fc302b9471966bb8cf34d484ed91f98791))


### Testing

* add blockchain DSL for testing purposes ([#233](https://www.github.com/aeternity/ae_mdw/issues/233)) ([10f2acb](https://www.github.com/aeternity/ae_mdw/commit/10f2acbfe3ebd54dddd628603d0cc59a610dff20))
* move integration tests to a separate directory ([#238](https://www.github.com/aeternity/ae_mdw/issues/238)) ([e37287d](https://www.github.com/aeternity/ae_mdw/commit/e37287da4ea484c65277ae2f26e3094a2ca8ac34))
* separate unit/integration tests and add to ci ([#221](https://www.github.com/aeternity/ae_mdw/issues/221)) ([0854208](https://www.github.com/aeternity/ae_mdw/commit/0854208fbc932f6214b7378b29b23bd1021be1b3))
* small integration tests updates ([#231](https://www.github.com/aeternity/ae_mdw/issues/231)) ([0df99b3](https://www.github.com/aeternity/ae_mdw/commit/0df99b3341e61243fda8f307d11e16a8ab80aef2))
* update NameController tests to be unit tests ([#235](https://www.github.com/aeternity/ae_mdw/issues/235)) ([32bc946](https://www.github.com/aeternity/ae_mdw/commit/32bc9466e28fdd681f8402087f6d96d58a8ccd57))
* use specific docker image version of Elixir ([#240](https://www.github.com/aeternity/ae_mdw/issues/240)) ([93cb45d](https://www.github.com/aeternity/ae_mdw/commit/93cb45d86d13b5be19ec00be75c8747e750ebdf7))


### CI / CD

* add ci proposal with github actions ([3bee5a8](https://www.github.com/aeternity/ae_mdw/commit/3bee5a8a927284802bd327f7554a98fc59ade307))
* add commitlint ([e87e51f](https://www.github.com/aeternity/ae_mdw/commit/e87e51f3517957ed728caba3c9e32cc4778f95fb))
* add credo to ci ([#243](https://www.github.com/aeternity/ae_mdw/issues/243)) ([42dd057](https://www.github.com/aeternity/ae_mdw/commit/42dd057dec42b6d11cfbb27ef3f520e262dd72ba))
* add dialyzer to project ([76956ef](https://www.github.com/aeternity/ae_mdw/commit/76956efe590722a644310a0d0184befc80f511b9))
* add release please workflow ([88cff95](https://www.github.com/aeternity/ae_mdw/commit/88cff95d22595aa58983905a8ae05131b31eb29f))


### Miscellaneous

* add git_hooks lib for optional use ([#245](https://www.github.com/aeternity/ae_mdw/issues/245)) ([7229c7e](https://www.github.com/aeternity/ae_mdw/commit/7229c7e2e508e492f5c6969ca0d3d7fe0438be0a))
* format elixir files ([8a0fbfc](https://www.github.com/aeternity/ae_mdw/commit/8a0fbfc8949b8b571f1eb152ec4edc722784d750))
* prepend slash to pagination next ([#251](https://www.github.com/aeternity/ae_mdw/issues/251)) ([d5435c1](https://www.github.com/aeternity/ae_mdw/commit/d5435c17c76a7aaeb32d6a58d64d602c20497636))
* remove warnings ([#225](https://www.github.com/aeternity/ae_mdw/issues/225)) ([720fcfc](https://www.github.com/aeternity/ae_mdw/commit/720fcfc4c3468a0c3f1488b70a8d83aa75e8e440))
* warnings as errors ([cc162b8](https://www.github.com/aeternity/ae_mdw/commit/cc162b84fb5fc73f6d8da0319ec203be2742da53))
