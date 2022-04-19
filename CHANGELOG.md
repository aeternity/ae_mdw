# Changelog

### [1.8.1](https://www.github.com/aeternity/ae_mdw/compare/v1.8.0...v1.8.1) (2022-04-19)


### Bug Fixes

* enable sync server to receive old :DOWN messages ([#642](https://www.github.com/aeternity/ae_mdw/issues/642)) ([53d716c](https://www.github.com/aeternity/ae_mdw/commit/53d716c9eba327f92d7017cf4cc982722c0df2b6))

## [1.8.0](https://www.github.com/aeternity/ae_mdw/compare/v1.7.3...v1.8.0) (2022-04-19)


### Features

* index aex9 contracts on Chain.clone and Chain.create ([#639](https://www.github.com/aeternity/ae_mdw/issues/639)) ([232ef4d](https://www.github.com/aeternity/ae_mdw/commit/232ef4d1e00411e2a9c840f8ffbfea501a74f727))


### Bug Fixes

* don't display source_hash when invalid compilation info ([#636](https://www.github.com/aeternity/ae_mdw/issues/636)) ([f68fc0f](https://www.github.com/aeternity/ae_mdw/commit/f68fc0f458e0e30d34a95f9491a5081c32b0cb5f)), closes [#635](https://www.github.com/aeternity/ae_mdw/issues/635)
* fix displaying single txis for v2 ([#637](https://www.github.com/aeternity/ae_mdw/issues/637)) ([2642d24](https://www.github.com/aeternity/ae_mdw/commit/2642d24292ebad327fbf8b85fb0c34728934578d))
* get next block hash on async task ([#624](https://www.github.com/aeternity/ae_mdw/issues/624)) ([4c5e1b1](https://www.github.com/aeternity/ae_mdw/commit/4c5e1b1e521e8c2535af72f7bae8e849bf564278))
* restart sync server after sync fails ([#640](https://www.github.com/aeternity/ae_mdw/issues/640)) ([2755773](https://www.github.com/aeternity/ae_mdw/commit/27557735b8c8dab10e1ccf7a17657dde4f5afe19))
* update aex9 balance on any call and invalidate it on fork ([#630](https://www.github.com/aeternity/ae_mdw/issues/630)) ([685ba96](https://www.github.com/aeternity/ae_mdw/commit/685ba96fa6e5e811bd844263c015e679fb5217f3))


### Testing

* coverage analysis ([#599](https://www.github.com/aeternity/ae_mdw/issues/599)) ([4657cb7](https://www.github.com/aeternity/ae_mdw/commit/4657cb7bf3c64d0b02931e7b41b97f017098e59f))
* fix intermittent RocksDbCF concurrent error ([#631](https://www.github.com/aeternity/ae_mdw/issues/631)) ([9b844d7](https://www.github.com/aeternity/ae_mdw/commit/9b844d78d0c01850d4c8c5fc4e25fbe16114022a))


### CI / CD

* speed up dialyzer without docker ([#632](https://www.github.com/aeternity/ae_mdw/issues/632)) ([8a77729](https://www.github.com/aeternity/ae_mdw/commit/8a77729a27606ee4a923945c041418c5c5cdc3c6))


### Miscellaneous

* add diffing script to compare two different environments ([#628](https://www.github.com/aeternity/ae_mdw/issues/628)) ([b238c0f](https://www.github.com/aeternity/ae_mdw/commit/b238c0fe2dd25994e9879a30d71f4dcfb37d47f6))

### [1.7.3](https://www.github.com/aeternity/ae_mdw/compare/v1.7.2...v1.7.3) (2022-04-05)


### Bug Fixes

* get pubkey for child contracts ([#620](https://www.github.com/aeternity/ae_mdw/issues/620)) ([6e8c2da](https://www.github.com/aeternity/ae_mdw/commit/6e8c2da9aa995fbf011549ed1be595adb5ae9e8f))


### Miscellaneous

* clean node db hooks from mdw ([#619](https://www.github.com/aeternity/ae_mdw/issues/619)) ([ce75528](https://www.github.com/aeternity/ae_mdw/commit/ce75528babc84d2fd8ccd2336efa76cea27708b7))


### Testing

* fix integration inactive names cases by expiration/deactivation ([#622](https://www.github.com/aeternity/ae_mdw/issues/622)) ([43a661b](https://www.github.com/aeternity/ae_mdw/commit/43a661b82bd752a62568cffdc425b6f9c758861f))


### Refactorings

* fetch expired oracle/names inside mutation ([#611](https://www.github.com/aeternity/ae_mdw/issues/611)) ([0910e84](https://www.github.com/aeternity/ae_mdw/commit/0910e84233072aeb1ba3c1a7eb910e79711566dd))
* include code to fetch stats inside StatsMutation ([#610](https://www.github.com/aeternity/ae_mdw/issues/610)) ([5991bc4](https://www.github.com/aeternity/ae_mdw/commit/5991bc41f7510d104f0a9bace3bf21e43afa1ef7))
* perform async invalidations on a sync server ([#589](https://www.github.com/aeternity/ae_mdw/issues/589)) ([32c2575](https://www.github.com/aeternity/ae_mdw/commit/32c25753cd74ff93d4e03515cb65a36dc1eccf7b))
* rename /v2/names/* by=expiration to by=deactivation ([#623](https://www.github.com/aeternity/ae_mdw/issues/623)) ([a360c8b](https://www.github.com/aeternity/ae_mdw/commit/a360c8b3ad3cd4a9d1b6e0ff6b0b67e79011b955))

### [1.7.2](https://www.github.com/aeternity/ae_mdw/compare/v1.7.1...v1.7.2) (2022-03-31)


### Bug Fixes

* get bi for a block hash ([#614](https://www.github.com/aeternity/ae_mdw/issues/614)) ([6b15215](https://www.github.com/aeternity/ae_mdw/commit/6b152159555d5725bad0b416d9fe35f50e776e0c))
* initialize aex9 balance when not exists ([#616](https://www.github.com/aeternity/ae_mdw/issues/616)) ([de283b5](https://www.github.com/aeternity/ae_mdw/commit/de283b54e80ee1f7f03412cafaaa38e3d2c6eb10))

### [1.7.1](https://www.github.com/aeternity/ae_mdw/compare/v1.7.0...v1.7.1) (2022-03-29)


### Bug Fixes

* aex9 creation for child contracts ([#592](https://www.github.com/aeternity/ae_mdw/issues/592)) ([ce586bf](https://www.github.com/aeternity/ae_mdw/commit/ce586bf43d6f766f219374aaca078a26671b6958))
* deactivate name on update with ttl 0 ([#602](https://www.github.com/aeternity/ae_mdw/issues/602)) ([6e1a2b7](https://www.github.com/aeternity/ae_mdw/commit/6e1a2b76444a2bedb53d7938e0107fe75bae337e))
* delta stat resume when name is not revoked ([#593](https://www.github.com/aeternity/ae_mdw/issues/593)) ([83af31b](https://www.github.com/aeternity/ae_mdw/commit/83af31b5e947f7dfda35e9a3b340b6b0c5b85c6b))
* fix /names/owned_by path ([#612](https://www.github.com/aeternity/ae_mdw/issues/612)) ([80adf01](https://www.github.com/aeternity/ae_mdw/commit/80adf01dae1e32383670aa55c626a5775d45f790))
* fix aex9 balances route for a contract ([#606](https://www.github.com/aeternity/ae_mdw/issues/606)) ([59bb989](https://www.github.com/aeternity/ae_mdw/commit/59bb9890382b8cab685429e6ff49301ea9b840be))
* handle name ownership and pointers when tx is internal ([#601](https://www.github.com/aeternity/ae_mdw/issues/601)) ([95b2f5a](https://www.github.com/aeternity/ae_mdw/commit/95b2f5af138bc9f5372c2675f134ef667ca209e7))
* missing InactiveNameOwner record ([#598](https://www.github.com/aeternity/ae_mdw/issues/598)) ([85f6c74](https://www.github.com/aeternity/ae_mdw/commit/85f6c74a7135c01d918cb58791dad9e00481126b))
* oracle expiration stats ([#585](https://www.github.com/aeternity/ae_mdw/issues/585)) ([859b452](https://www.github.com/aeternity/ae_mdw/commit/859b452f6070f5649da11e5618a946fe5440f861))
* set contract created stats min value to 0 ([#609](https://www.github.com/aeternity/ae_mdw/issues/609)) ([9be2d02](https://www.github.com/aeternity/ae_mdw/commit/9be2d02bd716207b73e2d5cc0fe35f946268fe71))
* start syncing mdw after running migrations ([#587](https://www.github.com/aeternity/ae_mdw/issues/587)) ([5b580b1](https://www.github.com/aeternity/ae_mdw/commit/5b580b1f37da84334c3cd2c7afc351dc81e32530))
* update readme for /v2/deltastats ([#613](https://www.github.com/aeternity/ae_mdw/issues/613)) ([bd8570b](https://www.github.com/aeternity/ae_mdw/commit/bd8570b79adb6b4d73c19ea151f82f4703ab685d))


### Testing

* disable async tasks ([#583](https://www.github.com/aeternity/ae_mdw/issues/583)) ([b451b4d](https://www.github.com/aeternity/ae_mdw/commit/b451b4d84f1bd915974316c4435179415b04503e))
* fix v1/v2 stats tests ([#608](https://www.github.com/aeternity/ae_mdw/issues/608)) ([a216b83](https://www.github.com/aeternity/ae_mdw/commit/a216b83e6d33898b9c59aac54f011a3f1c44d512))


### Refactorings

* async tasks persisted with rocksdb ([#577](https://www.github.com/aeternity/ae_mdw/issues/577)) ([0810dde](https://www.github.com/aeternity/ae_mdw/commit/0810dde0bda5726e61375671a84bca552c11e266))
* chain and name tables persisted with rocksdb ([#590](https://www.github.com/aeternity/ae_mdw/issues/590)) ([3d8d22f](https://www.github.com/aeternity/ae_mdw/commit/3d8d22f5dc00f6ab1f31408985fbec755f045a1c))
* contract tables persisted with rocksdb ([#594](https://www.github.com/aeternity/ae_mdw/issues/594)) ([93de2b3](https://www.github.com/aeternity/ae_mdw/commit/93de2b3c86d30542e2cff712ce5f56ade0e3755e))
* oracles persisted with rocksdb ([#588](https://www.github.com/aeternity/ae_mdw/issues/588)) ([3d8aae4](https://www.github.com/aeternity/ae_mdw/commit/3d8aae47a4d3f83fd90befba56f6ccbd16f01fd0))
* stats tables persisted with rocksdb ([#579](https://www.github.com/aeternity/ae_mdw/issues/579)) ([2860bbd](https://www.github.com/aeternity/ae_mdw/commit/2860bbd98fee105938d7506c4653d87b36c7ac27))

## [1.7.0](https://www.github.com/aeternity/ae_mdw/compare/v1.6.1...v1.7.0) (2022-03-09)


### Features

* /v2/deltastats ([#560](https://www.github.com/aeternity/ae_mdw/issues/560)) ([0f8961a](https://www.github.com/aeternity/ae_mdw/commit/0f8961a585a7f650322d763d4684e7573daaad5a))
* add /v2 routes to support versioning ([#530](https://www.github.com/aeternity/ae_mdw/issues/530)) ([539042b](https://www.github.com/aeternity/ae_mdw/commit/539042bcccc5d5838c9563e11083834920350f99))
* add AEX9 v2 endpoint to retrieve balance history ([#575](https://www.github.com/aeternity/ae_mdw/issues/575)) ([d3abb00](https://www.github.com/aeternity/ae_mdw/commit/d3abb00c9505cfb2e493eb549c8bb306bbabcc4c))
* add aex9 v2 endpoints ([#563](https://www.github.com/aeternity/ae_mdw/issues/563)) ([13a0a07](https://www.github.com/aeternity/ae_mdw/commit/13a0a07e904f2d9110eaae74618506fcb6e4a489))
* add contracts v2 endpoints ([#559](https://www.github.com/aeternity/ae_mdw/issues/559)) ([74aadab](https://www.github.com/aeternity/ae_mdw/commit/74aadabbb733c03d4311679907011d003881ce63))
* add paginated /names/search/:prefix endpoint ([#447](https://www.github.com/aeternity/ae_mdw/issues/447)) ([3f213d7](https://www.github.com/aeternity/ae_mdw/commit/3f213d78ddab696cb0b57836d29118ae64d39304))
* add prev link cursor on paginated endpoints ([#526](https://www.github.com/aeternity/ae_mdw/issues/526)) ([0eca223](https://www.github.com/aeternity/ae_mdw/commit/0eca223483aa77d42b2822e804f4baf4d5813364))
* add v2 blocks endpoints ([#549](https://www.github.com/aeternity/ae_mdw/issues/549)) ([24c4020](https://www.github.com/aeternity/ae_mdw/commit/24c402006d231ca550b2c31857b90cd20e20da4c)), closes [#498](https://www.github.com/aeternity/ae_mdw/issues/498)
* add v2 oracles endpoints ([#550](https://www.github.com/aeternity/ae_mdw/issues/550)) ([76d47a0](https://www.github.com/aeternity/ae_mdw/commit/76d47a063759e207ac1267ab9e357f0157ab46e2)), closes [#498](https://www.github.com/aeternity/ae_mdw/issues/498)
* add v2 stats endpoints ([#556](https://www.github.com/aeternity/ae_mdw/issues/556)) ([11dd8f6](https://www.github.com/aeternity/ae_mdw/commit/11dd8f6b9fc72b36700cbc8cb69361dbea71be28))
* add v2 transfers endpoints ([#554](https://www.github.com/aeternity/ae_mdw/issues/554)) ([bd94755](https://www.github.com/aeternity/ae_mdw/commit/bd94755a557b5e561875668bd0bcca2e32c77ff3))
* add v2 txs endpoints ([#552](https://www.github.com/aeternity/ae_mdw/issues/552)) ([86daad0](https://www.github.com/aeternity/ae_mdw/commit/86daad05ad87bb60840adfd6cb5d43bc4ebc1c88))
* aex9 transfers pagination ([#551](https://www.github.com/aeternity/ae_mdw/issues/551)) ([d765a25](https://www.github.com/aeternity/ae_mdw/commit/d765a25b552b2382f3ad4fde6d0d82285d75ea5b))
* allow mdw sync module to restart after a failure ([#564](https://www.github.com/aeternity/ae_mdw/issues/564)) ([f6b7b47](https://www.github.com/aeternity/ae_mdw/commit/f6b7b47366fd262eb7751b29a8abdb5aa8c43e02))
* cached aex9 balances ([#571](https://www.github.com/aeternity/ae_mdw/issues/571)) ([d53ba6b](https://www.github.com/aeternity/ae_mdw/commit/d53ba6bc33a08620248cff2137566904d86a908a))
* rocksdb without mnesia ([#475](https://www.github.com/aeternity/ae_mdw/issues/475)) ([37f5889](https://www.github.com/aeternity/ae_mdw/commit/37f5889bf4d9db2b7ba8f1fdea81cafb00e049ec))
* use Mnesia module ([#506](https://www.github.com/aeternity/ae_mdw/issues/506)) ([9b50a8e](https://www.github.com/aeternity/ae_mdw/commit/9b50a8ef64f3280b016cb5c07dda391246e57d45))


### Bug Fixes

* /aex9/transfers/from timeout ([#546](https://www.github.com/aeternity/ae_mdw/issues/546)) ([1010cac](https://www.github.com/aeternity/ae_mdw/commit/1010cac922178195b4c44d3fb4a63d2a15db47ea))
* /stats counters with negative values ([#562](https://www.github.com/aeternity/ae_mdw/issues/562)) ([4c60302](https://www.github.com/aeternity/ae_mdw/commit/4c60302e357f8e046dd41701eb4fc4ed24784566))
* derive aex9 presence error handling ([#537](https://www.github.com/aeternity/ae_mdw/issues/537)) ([348e3d9](https://www.github.com/aeternity/ae_mdw/commit/348e3d9e08a6dc0176d3bfa25fff35d7d003cfcc))
* fix missing streams errors  ([#531](https://www.github.com/aeternity/ae_mdw/issues/531)) ([a97f3e7](https://www.github.com/aeternity/ae_mdw/commit/a97f3e7e3d5a877554ffe4e2b82279a87bf8e0a9))
* integration tests db path ([#542](https://www.github.com/aeternity/ae_mdw/issues/542)) ([90c4961](https://www.github.com/aeternity/ae_mdw/commit/90c49614888be76a175105aa103facf74df40639))
* raise exception when aex9 contract doesn't exist ([#540](https://www.github.com/aeternity/ae_mdw/issues/540)) ([26044d5](https://www.github.com/aeternity/ae_mdw/commit/26044d59d83adba99908b007c12decd8ef0bece0))
* update names search streams to use new Database module ([#544](https://www.github.com/aeternity/ae_mdw/issues/544)) ([507bc94](https://www.github.com/aeternity/ae_mdw/commit/507bc94d801fd353d05228bb9b9b50809b642424))


### Testing

* fix intermittent prev_key async test ([#543](https://www.github.com/aeternity/ae_mdw/issues/543)) ([04b004c](https://www.github.com/aeternity/ae_mdw/commit/04b004cbaf0b2aa629b7d8809bd0939675908346))


### Refactorings

* add fallback controller to deal with errors consistently ([#547](https://www.github.com/aeternity/ae_mdw/issues/547)) ([2664124](https://www.github.com/aeternity/ae_mdw/commit/2664124fa0019dbec052c06b9c71afc3472882a5))
* change name routes to be consistent with core ([#451](https://www.github.com/aeternity/ae_mdw/issues/451)) ([40f598c](https://www.github.com/aeternity/ae_mdw/commit/40f598cdb1fa12dbfd9a8ebc2c13c8a3a5deabed)), closes [#110](https://www.github.com/aeternity/ae_mdw/issues/110) [#498](https://www.github.com/aeternity/ae_mdw/issues/498)
* commit only through mutations ([#534](https://www.github.com/aeternity/ae_mdw/issues/534)) ([42b09e8](https://www.github.com/aeternity/ae_mdw/commit/42b09e8ea3c9ccc5b36f18f54901e656ed344d66))
* migrations with rocksdb ([#573](https://www.github.com/aeternity/ae_mdw/issues/573)) ([fac84b4](https://www.github.com/aeternity/ae_mdw/commit/fac84b40b0c35bedd6026fc709c4f7e6a54b4113))
* Mnesia to Database ([#528](https://www.github.com/aeternity/ae_mdw/issues/528)) ([934ebd8](https://www.github.com/aeternity/ae_mdw/commit/934ebd862c3703fb9f19e4db1c363fb844f80fbe))
* mutations derive to default impl ([#553](https://www.github.com/aeternity/ae_mdw/issues/553)) ([c406a57](https://www.github.com/aeternity/ae_mdw/commit/c406a57c212b3efedd73167f3b9429ee3d15baac))
* remove and make private unused modules/functions ([#527](https://www.github.com/aeternity/ae_mdw/issues/527)) ([d6fc8e9](https://www.github.com/aeternity/ae_mdw/commit/d6fc8e983f4dedfdbca1588ad68bcfc85c551aad))
* remove unused web code ([#532](https://www.github.com/aeternity/ae_mdw/issues/532)) ([93c2487](https://www.github.com/aeternity/ae_mdw/commit/93c248740f01dd17ea4b156bff9a0b696eee52b4))
* rename write mutation ([#533](https://www.github.com/aeternity/ae_mdw/issues/533)) ([ec1badd](https://www.github.com/aeternity/ae_mdw/commit/ec1baddb34aee959c2ffb530ecbbef0900eab42c))
* update name routes to be consistent with core ([40f598c](https://www.github.com/aeternity/ae_mdw/commit/40f598cdb1fa12dbfd9a8ebc2c13c8a3a5deabed))


### Miscellaneous

* added check script for readme routes ([4c57a1e](https://www.github.com/aeternity/ae_mdw/commit/4c57a1e6c55aadbed1180448a3c59b75fc6827ab))
* drop old model sum_stat ([#558](https://www.github.com/aeternity/ae_mdw/issues/558)) ([7dc65c2](https://www.github.com/aeternity/ae_mdw/commit/7dc65c2108b1f3fccf681c6fc0b9b283730fcde3))
* ignore data directory on docker/git ([#555](https://www.github.com/aeternity/ae_mdw/issues/555)) ([c10a9b8](https://www.github.com/aeternity/ae_mdw/commit/c10a9b86a28dea341734da7c92f4f1921392ff55))
* mnesia and mdw.db under same data dir ([#539](https://www.github.com/aeternity/ae_mdw/issues/539)) ([f7e636f](https://www.github.com/aeternity/ae_mdw/commit/f7e636f69271dbce3043a5dea478a03e0c2ff133))
* remove no longer needed migrations ([#576](https://www.github.com/aeternity/ae_mdw/issues/576)) ([de01738](https://www.github.com/aeternity/ae_mdw/commit/de017386b560486af782662b3302a2ef8509e639))
* rename name endpoints swagger operation ids ([#561](https://www.github.com/aeternity/ae_mdw/issues/561)) ([308c556](https://www.github.com/aeternity/ae_mdw/commit/308c5564c047137a7479662bf0a258ded0bbda27)), closes [#179](https://www.github.com/aeternity/ae_mdw/issues/179)
* withhold non-migrated v2 routes ([#548](https://www.github.com/aeternity/ae_mdw/issues/548)) ([f73f27d](https://www.github.com/aeternity/ae_mdw/commit/f73f27dc7a6624061ff352643ad63edde9f0f57b))

### [1.6.1](https://www.github.com/aeternity/ae_mdw/compare/v1.6.0...v1.6.1) (2022-02-08)


### Bug Fixes

* properly assign m_bid to actual bid value ([#521](https://www.github.com/aeternity/ae_mdw/issues/521)) ([91b1f0b](https://www.github.com/aeternity/ae_mdw/commit/91b1f0b698015efdc4e5a92d7184f88275cf951d))

## [1.6.0](https://www.github.com/aeternity/ae_mdw/compare/v1.5.0...v1.6.0) (2022-02-08)


### Features

* /aex9/by_contract search ([#505](https://www.github.com/aeternity/ae_mdw/issues/505)) ([117a45d](https://www.github.com/aeternity/ae_mdw/commit/117a45dacfd601548ccb2ec1658cac10143635c0))
* aex9 contract created by :contract_call_tx ([#514](https://www.github.com/aeternity/ae_mdw/issues/514)) ([7224252](https://www.github.com/aeternity/ae_mdw/commit/7224252fb62a5f59383a589f93b908b843c4b0af))
* sum of auctions, names, oracles and contracts in total stats ([#504](https://www.github.com/aeternity/ae_mdw/issues/504)) ([3adb25d](https://www.github.com/aeternity/ae_mdw/commit/3adb25d7dcc32515e64b5a6435798c4c6fb47926))


### Bug Fixes

* render auctions by name using just the AuctionBid key ([#515](https://www.github.com/aeternity/ae_mdw/issues/515)) ([b3c0f3a](https://www.github.com/aeternity/ae_mdw/commit/b3c0f3a798d7afc5e0535c6b4590fe781e74bbe4))
* updates txi when internal call expiration is unchanged ([#502](https://www.github.com/aeternity/ae_mdw/issues/502)) ([8450838](https://www.github.com/aeternity/ae_mdw/commit/845083883076dc5233433cd77b732bef5488f567))


### Refactorings

* extract range independently of the direction requested ([#499](https://www.github.com/aeternity/ae_mdw/issues/499)) ([979c5ab](https://www.github.com/aeternity/ae_mdw/commit/979c5ab0a2d07929794867642d7a6dafa4a7f059))

## [1.5.0](https://www.github.com/aeternity/ae_mdw/compare/v1.4.0...v1.5.0) (2022-01-28)


### Features

* /names/owned_by for inactive names ([#461](https://www.github.com/aeternity/ae_mdw/issues/461)) ([d206326](https://www.github.com/aeternity/ae_mdw/commit/d206326b134403506f6d10afbe134d21cb835771))
* add encoded query_id on query txs ([#455](https://www.github.com/aeternity/ae_mdw/issues/455)) ([4691bdd](https://www.github.com/aeternity/ae_mdw/commit/4691bdd6d8b14291253b3a3081ec3a47c6728b5b)), closes [#381](https://www.github.com/aeternity/ae_mdw/issues/381) [#60](https://www.github.com/aeternity/ae_mdw/issues/60)
* aex9 balances for an account with token info ([#424](https://www.github.com/aeternity/ae_mdw/issues/424)) ([658c522](https://www.github.com/aeternity/ae_mdw/commit/658c5221b51eaa12bd6b1a6eb33c0544a1efe78b))
* aex9 presence on calls other than transfer ([#438](https://www.github.com/aeternity/ae_mdw/issues/438)) ([ceee4b1](https://www.github.com/aeternity/ae_mdw/commit/ceee4b193af2b3c8efb48643359d36607e2d0d30))
* contract compilation info ([#457](https://www.github.com/aeternity/ae_mdw/issues/457)) ([16a88d0](https://www.github.com/aeternity/ae_mdw/commit/16a88d0e33d1d32159001473a2b35a15b1e05191))
* index AENS internal calls ([#472](https://www.github.com/aeternity/ae_mdw/issues/472)) ([b089194](https://www.github.com/aeternity/ae_mdw/commit/b089194477033bc031eb2fb1dfaf8065560e3a04))
* index ga_attach_tx by contract ([#413](https://www.github.com/aeternity/ae_mdw/issues/413)) ([fc2f3cb](https://www.github.com/aeternity/ae_mdw/commit/fc2f3cb99c0e3e6ba0c8099f983d4b974baed4f6))


### Bug Fixes

* aex9 migrations origin handling ([#481](https://www.github.com/aeternity/ae_mdw/issues/481)) ([d27dc0e](https://www.github.com/aeternity/ae_mdw/commit/d27dc0ecb0bae0c19f9b7905a480dcc579488843))
* avoid loading block_hash for building oracle tree when syncing ([#460](https://www.github.com/aeternity/ae_mdw/issues/460)) ([1776b26](https://www.github.com/aeternity/ae_mdw/commit/1776b26dfcbf914563a90153f17409a8da6b10ba))
* execute block_rewards mutation before stats mutation ([#452](https://www.github.com/aeternity/ae_mdw/issues/452)) ([d1ece21](https://www.github.com/aeternity/ae_mdw/commit/d1ece218661d61924bd5ada7b3ff3246bb88dc22)), closes [#450](https://www.github.com/aeternity/ae_mdw/issues/450)
* expirations shall run at the end of a height ([#484](https://www.github.com/aeternity/ae_mdw/issues/484)) ([25d9d96](https://www.github.com/aeternity/ae_mdw/commit/25d9d96257895779ffb31d4dba211eb6e75a4671))
* extract pointers from internal calls ([#486](https://www.github.com/aeternity/ae_mdw/issues/486)) ([4475676](https://www.github.com/aeternity/ae_mdw/commit/44756761983a1e48f335231825b141c4c57a9ddf)), closes [#477](https://www.github.com/aeternity/ae_mdw/issues/477)
* fix dockerfile for multiple node releases ([67b57a4](https://www.github.com/aeternity/ae_mdw/commit/67b57a4e7b210477b40bcdb41fea05ff2a4ba35b))
* get aex9 meta info error handling ([#496](https://www.github.com/aeternity/ae_mdw/issues/496)) ([a8fc71d](https://www.github.com/aeternity/ae_mdw/commit/a8fc71dd8facab416e18a5f113a116ea7d2cf7ed))
* inactive name owner table for sync ([#463](https://www.github.com/aeternity/ae_mdw/issues/463)) ([f936572](https://www.github.com/aeternity/ae_mdw/commit/f93657257cba40861ed7de2c04349374cc9d9563))
* index Oracle.respond internal contract calls ([#480](https://www.github.com/aeternity/ae_mdw/issues/480)) ([e065bf4](https://www.github.com/aeternity/ae_mdw/commit/e065bf4b8ebefc8eab7e56fbd74d32c241b2040c)), closes [#468](https://www.github.com/aeternity/ae_mdw/issues/468)
* index the origin of contracts created via Chain.clone/create ([#474](https://www.github.com/aeternity/ae_mdw/issues/474)) ([a0f39e9](https://www.github.com/aeternity/ae_mdw/commit/a0f39e9f85e829f323bf03be97138d19787eeb3b))
* make db transactions synchronous ([#443](https://www.github.com/aeternity/ae_mdw/issues/443)) ([7ee8347](https://www.github.com/aeternity/ae_mdw/commit/7ee83473c431c01366b8e9299e62f85972fe2b9f))
* name and oracle int calls filtering ([#488](https://www.github.com/aeternity/ae_mdw/issues/488)) ([b35daa1](https://www.github.com/aeternity/ae_mdw/commit/b35daa16b323d0b2f2a6e84a1f4531229b0e9650))
* name expiration after aens.update with name_ttl = 0 ([#491](https://www.github.com/aeternity/ae_mdw/issues/491)) ([9ab3502](https://www.github.com/aeternity/ae_mdw/commit/9ab3502cc6b7b20225cad97780a9ce1ea4fd4c23))
* nested or nil mutation processing ([#493](https://www.github.com/aeternity/ae_mdw/issues/493)) ([fcc9119](https://www.github.com/aeternity/ae_mdw/commit/fcc9119b9bb32ddd351309e03c9b5ce8bf917425))
* register oracles created through Oracle.register contract calls ([#466](https://www.github.com/aeternity/ae_mdw/issues/466)) ([d2409c7](https://www.github.com/aeternity/ae_mdw/commit/d2409c7d2e5db370abf3c5dcc7805ed3762516bc)), closes [#380](https://www.github.com/aeternity/ae_mdw/issues/380)
* skip processing internal calls for Chain.* events ([#467](https://www.github.com/aeternity/ae_mdw/issues/467)) ([25bcf4e](https://www.github.com/aeternity/ae_mdw/commit/25bcf4e015b890ddcd64931fd0fe2bd9589627e0))
* stats count for existing objects ([#454](https://www.github.com/aeternity/ae_mdw/issues/454)) ([5fb8ea2](https://www.github.com/aeternity/ae_mdw/commit/5fb8ea2837c1cc527b83a66e2e14ee82670e0a18))
* validate existing contract when filtering calls by contract_id ([#446](https://www.github.com/aeternity/ae_mdw/issues/446)) ([35c6054](https://www.github.com/aeternity/ae_mdw/commit/35c6054be47b8d832571b6accebdd593403b312a)), closes [#422](https://www.github.com/aeternity/ae_mdw/issues/422)


### Miscellaneous

* disable accoutnt txs legacy endpoint ([9a4480e](https://www.github.com/aeternity/ae_mdw/commit/9a4480e7b88d5c812642ad73efae67e74da21ea0)), closes [#410](https://www.github.com/aeternity/ae_mdw/issues/410)


### CI / CD

* invert order to avoid setting git user ([d00e0f7](https://www.github.com/aeternity/ae_mdw/commit/d00e0f7e14c2d204c556fcc0519b197e5978923d))


### Testing

* fix auction sorting check ([#449](https://www.github.com/aeternity/ae_mdw/issues/449)) ([efeb945](https://www.github.com/aeternity/ae_mdw/commit/efeb9453fcca75658c403e2efe11cc36f7ae9281))
* fix oracles and tx_controller integration tests ([#440](https://www.github.com/aeternity/ae_mdw/issues/440)) ([1d6541b](https://www.github.com/aeternity/ae_mdw/commit/1d6541b7cfd37c72e25748cb1fb857ee8f9cad9b))
* fix the single stats test that is failing ([#479](https://www.github.com/aeternity/ae_mdw/issues/479)) ([79d918e](https://www.github.com/aeternity/ae_mdw/commit/79d918ee3a069807b26b90d88ec9471a5b90593d))
* restructure oracles integration tests ([#423](https://www.github.com/aeternity/ae_mdw/issues/423)) ([36e0800](https://www.github.com/aeternity/ae_mdw/commit/36e080068c9b4e8ea8b3edd340e63bcd91b81e84))
* restructure tx_controller integration tests ([#427](https://www.github.com/aeternity/ae_mdw/issues/427)) ([0a17539](https://www.github.com/aeternity/ae_mdw/commit/0a17539c0091891d609321d09c1e6799d4d3c193))


### Refactorings

* add name transfer/update/revoke mutations ([#465](https://www.github.com/aeternity/ae_mdw/issues/465)) ([fcaff4a](https://www.github.com/aeternity/ae_mdw/commit/fcaff4a7e6e090b700638227c807923458c55cef))
* add tx context for dealing with tx mutations ([#439](https://www.github.com/aeternity/ae_mdw/issues/439)) ([a8cc83a](https://www.github.com/aeternity/ae_mdw/commit/a8cc83aa4da53d13477e13b1b3044ad80920a69c))
* create ContractCreateMutation ([#428](https://www.github.com/aeternity/ae_mdw/issues/428)) ([e74dc17](https://www.github.com/aeternity/ae_mdw/commit/e74dc17d802dc198292cfaf4e96ede2e3ea0859a))
* extract channel_create_tx syncing to Sync.Transaction ([#429](https://www.github.com/aeternity/ae_mdw/issues/429)) ([9036bf1](https://www.github.com/aeternity/ae_mdw/commit/9036bf177766f879f0bdfe36f48c3688c23a5a89))
* extract name claim mutation ([#431](https://www.github.com/aeternity/ae_mdw/issues/431)) ([66be18a](https://www.github.com/aeternity/ae_mdw/commit/66be18a6d3ae81fbd6c26276f10611d73c68b55e))
* extract oracle extand/response mutations ([#444](https://www.github.com/aeternity/ae_mdw/issues/444)) ([9e520e2](https://www.github.com/aeternity/ae_mdw/commit/9e520e20cca4b20864421e0928a6be2cecf31404))
* extract OracleRegister transaction into mutation ([#430](https://www.github.com/aeternity/ae_mdw/issues/430)) ([8c0933d](https://www.github.com/aeternity/ae_mdw/commit/8c0933d10f431af9b64459cbb6fc6c77911c4ead))
* key blocks mutation ([#441](https://www.github.com/aeternity/ae_mdw/issues/441)) ([c64fda6](https://www.github.com/aeternity/ae_mdw/commit/c64fda6d8260b22f25369f4ee0dbf5afe98a1406))
* split contract events mutation into multiple MnesiaWrite ([#458](https://www.github.com/aeternity/ae_mdw/issues/458)) ([1521121](https://www.github.com/aeternity/ae_mdw/commit/15211213bd56f436025610bc24d30ba2aacf270d))
* split ga_attach_tx mutation to use FieldMutation instead ([#445](https://www.github.com/aeternity/ae_mdw/issues/445)) ([378b74d](https://www.github.com/aeternity/ae_mdw/commit/378b74d543de1e4bc14f0385b7bcf5e4f0587edf))
* trim unused code from the paginated endpoints ([#494](https://www.github.com/aeternity/ae_mdw/issues/494)) ([5aa92aa](https://www.github.com/aeternity/ae_mdw/commit/5aa92aaa8cafb326bfd1e7f7889f25f67d2c44fb))

## [1.4.0](https://www.github.com/aeternity/ae_mdw/compare/v1.3.1...v1.4.0) (2021-12-27)


### Features

* add cursor-based pagination to contract logs/calls ([#392](https://www.github.com/aeternity/ae_mdw/issues/392)) ([f0724ab](https://www.github.com/aeternity/ae_mdw/commit/f0724ab3221e9316fb3f88f1f45f66bf88d51a1f))
* add cursor-based pagination to stats ([#384](https://www.github.com/aeternity/ae_mdw/issues/384)) ([045ee35](https://www.github.com/aeternity/ae_mdw/commit/045ee3518e38b4cdff92f7163da6f697c905b7d2))
* db transactions per microblock ([#390](https://www.github.com/aeternity/ae_mdw/issues/390)) ([eb76e5b](https://www.github.com/aeternity/ae_mdw/commit/eb76e5b5ec00465f7b0bb39a5db7f538470a2b4d))
* index contract init events and internal calls ([#395](https://www.github.com/aeternity/ae_mdw/issues/395)) ([ca7f295](https://www.github.com/aeternity/ae_mdw/commit/ca7f295d9de201c4dd45cdb03dfcddce86b39e21))


### Bug Fixes

* base32 encode account cursor on transfers ([8d4c274](https://www.github.com/aeternity/ae_mdw/commit/8d4c274f60e2d25a5523dd4a17d0d1a91d74949e))
* build expiring mutation using mnesia transaction ([c94f28d](https://www.github.com/aeternity/ae_mdw/commit/c94f28d8651b407dbdec504161341799bbefd461))
* build oracles expiration transaction using mnesia transaction ([721ad99](https://www.github.com/aeternity/ae_mdw/commit/721ad99869f04751595f6ad7648aa7916b60e055))
* get info for contract with :ref instead of :code ([5ffcec1](https://www.github.com/aeternity/ae_mdw/commit/5ffcec1f82b9dab63ac8edac581bd430852d1ddc))
* revert chainsubscriber refactor ([#412](https://www.github.com/aeternity/ae_mdw/issues/412)) ([1b1e52f](https://www.github.com/aeternity/ae_mdw/commit/1b1e52f4395e210d2156d9689a90f73dd675777c))
* sync height 0 without mbs and txs ([9b9bbdf](https://www.github.com/aeternity/ae_mdw/commit/9b9bbdfc4754b99ff4b5f0be7d7dbf23ae7a2548))
* use last synced gen for stats and totalstats ([#401](https://www.github.com/aeternity/ae_mdw/issues/401)) ([53b27e7](https://www.github.com/aeternity/ae_mdw/commit/53b27e7a189527ed2a16a327587266e2be7510b3))


### Miscellaneous

* add additional logging information for auction updates ([865421c](https://www.github.com/aeternity/ae_mdw/commit/865421cce3ac5ccef8bcfcb21844d34468f818c5)), closes [#396](https://www.github.com/aeternity/ae_mdw/issues/396)
* include date on info.log ([#389](https://www.github.com/aeternity/ae_mdw/issues/389)) ([cee643e](https://www.github.com/aeternity/ae_mdw/commit/cee643e797e687e1c8653bdbb088363da8fe5afb)), closes [#361](https://www.github.com/aeternity/ae_mdw/issues/361)
* prev_stat is not used ([#400](https://www.github.com/aeternity/ae_mdw/issues/400)) ([55a7e48](https://www.github.com/aeternity/ae_mdw/commit/55a7e48823ac7c7c6a72d2c49caff9799f79df29))


### Refactorings

* remove dep from chain subscriber ([6be7a7f](https://www.github.com/aeternity/ae_mdw/commit/6be7a7f085ee43f75a9377cfd6f91939ac6545e0))


### Testing

* add contract controller endpoints integration tests ([#391](https://www.github.com/aeternity/ae_mdw/issues/391)) ([6389fb1](https://www.github.com/aeternity/ae_mdw/commit/6389fb1763b63a8017098513a5ac1af69a017ac0))
* refactor name controller integration tests ([#421](https://www.github.com/aeternity/ae_mdw/issues/421)) ([2413b7b](https://www.github.com/aeternity/ae_mdw/commit/2413b7b0bcedb95f5d9618965b363b7f0fcb1745))

### [1.3.1](https://www.github.com/aeternity/ae_mdw/compare/v1.3.0...v1.3.1) (2021-12-09)


### Bug Fixes

* add missing aliases on the Db.Oracle module ([4584411](https://www.github.com/aeternity/ae_mdw/commit/4584411b6d4b5bdda363bffda1e67e4afe809985))


### Refactorings

* add oracle expiration mutation when syncing ([#371](https://www.github.com/aeternity/ae_mdw/issues/371)) ([51beb6e](https://www.github.com/aeternity/ae_mdw/commit/51beb6eb60385fdb172e5e3e424ff601fcd2390d))
* extract block rewards syncing into mutation ([#367](https://www.github.com/aeternity/ae_mdw/issues/367)) ([9602804](https://www.github.com/aeternity/ae_mdw/commit/9602804b57bdbd1c370c79bb1d594c1e061e0352))


### Testing

* add stats endpoints integration tests ([#383](https://www.github.com/aeternity/ae_mdw/issues/383)) ([72c5001](https://www.github.com/aeternity/ae_mdw/commit/72c500109cfb15afb11a17fdaafe7ef920d5a5a5))
* name and auction sync logs ([e42a197](https://www.github.com/aeternity/ae_mdw/commit/e42a197ef65c042d73f98a633cdfdb709740deb2))


### Miscellaneous

* remove cleanup name expiration ([d63bf1b](https://www.github.com/aeternity/ae_mdw/commit/d63bf1b2f8ebf01b65b352aae186ded529d39301))

## [1.3.0](https://www.github.com/aeternity/ae_mdw/compare/v1.2.1...v1.3.0) (2021-11-30)


### Features

* add cursor-based pagination to transfers endpoints ([7f0d4d7](https://www.github.com/aeternity/ae_mdw/commit/7f0d4d7017d5ba5eb6ce40a6b03b202e819f2f73))
* add mutations abstraction to deal with mnesia updates ([#342](https://www.github.com/aeternity/ae_mdw/issues/342)) ([2f565cf](https://www.github.com/aeternity/ae_mdw/commit/2f565cf937875b3d5aa3e3c7e2a1c48fb3636263)), closes [#331](https://www.github.com/aeternity/ae_mdw/issues/331)
* allow scoping transfers by txis ([#356](https://www.github.com/aeternity/ae_mdw/issues/356)) ([0cf7058](https://www.github.com/aeternity/ae_mdw/commit/0cf70587a920345fb3bdd96c658cbaffb11eafd9)), closes [#307](https://www.github.com/aeternity/ae_mdw/issues/307)
* async derive_aex9_presence ([66a358a](https://www.github.com/aeternity/ae_mdw/commit/66a358afcb7eb7f18fa03fa9812eff35616a8b50))
* dedup existing records ([03708c2](https://www.github.com/aeternity/ae_mdw/commit/03708c2b8e7242ea98b09ed40785424c8b20f772))
* implement cursor-based pagination for scoped oracles & names ([#324](https://www.github.com/aeternity/ae_mdw/issues/324)) ([a82981c](https://www.github.com/aeternity/ae_mdw/commit/a82981c9f62898fb7b4a8d86f264de1e3a580536))
* long running async tasks ([cd18e3d](https://www.github.com/aeternity/ae_mdw/commit/cd18e3d6f6fe2c9b166b5065b6c7d4e568a6deeb))
* use cursor-based pagination for blocks endpoints ([#333](https://www.github.com/aeternity/ae_mdw/issues/333)) ([18a859c](https://www.github.com/aeternity/ae_mdw/commit/18a859c8cd8e7bd961e29ff5be0202cb7276fb06))


### Bug Fixes

* add name ttl to last_bid tx ([deede55](https://www.github.com/aeternity/ae_mdw/commit/deede55ce0c4957deb0618524bc0c81d4f8277de))
* allow filtering transfer by kind when backwards direction ([#360](https://www.github.com/aeternity/ae_mdw/issues/360)) ([78c6648](https://www.github.com/aeternity/ae_mdw/commit/78c664828a1445509d09375ad1b9427c3b345e57))
* always display the correct contract_id on contract logs ([84b06dc](https://www.github.com/aeternity/ae_mdw/commit/84b06dc6e8a237c6e18a105e50060b860974aa82)), closes [#301](https://www.github.com/aeternity/ae_mdw/issues/301)
* binary encoding for websocket broadcasting ([9ead4d0](https://www.github.com/aeternity/ae_mdw/commit/9ead4d029e7d53f3ed3e4c43d72bd39bcea9ef32))
* cancel task timer ([a1d11f9](https://www.github.com/aeternity/ae_mdw/commit/a1d11f9c74196fa0d22dcf0ee1a95bf217c8a366))
* contract might not be present ([65b18df](https://www.github.com/aeternity/ae_mdw/commit/65b18dfa305453057e910b36c94cf93dd6277637))
* dedup args for any task type ([af7b9c6](https://www.github.com/aeternity/ae_mdw/commit/af7b9c66c7a34385542cc770b34290bbde6e4cd3))
* filtering aex9 call ([9c374bd](https://www.github.com/aeternity/ae_mdw/commit/9c374bd9e674ef45a1bee40d6f2d0136f60da164))
* getting aex9 recipients ([6adf87c](https://www.github.com/aeternity/ae_mdw/commit/6adf87cba8426043699f7d5d3bb46f4d1245e3b6))
* increase task timeout ([8715600](https://www.github.com/aeternity/ae_mdw/commit/871560064a41ba0190a43b30130aece565ebff84))
* long task without timeout ([f2256c7](https://www.github.com/aeternity/ae_mdw/commit/f2256c772305a73bad6bccf121da8bf1d0bf7deb))
* reindex transfers to be able to filter by account + kind ([710ee08](https://www.github.com/aeternity/ae_mdw/commit/710ee0811c2e3abc6c982f75181fcb9ecf495484)), closes [#359](https://www.github.com/aeternity/ae_mdw/issues/359)
* remove old oracle expiration ([369aa50](https://www.github.com/aeternity/ae_mdw/commit/369aa50894b6d87445ba3d1004c2936f0530736e))
* remove unexisting auction fields ([#350](https://www.github.com/aeternity/ae_mdw/issues/350)) ([9621d66](https://www.github.com/aeternity/ae_mdw/commit/9621d66a1dde505c9f61d6824e484e8b4be481e8))
* start long task ([71b3404](https://www.github.com/aeternity/ae_mdw/commit/71b34048594e51d84f366990331f3713a4d05dc8))
* update contracts txi ([e08334c](https://www.github.com/aeternity/ae_mdw/commit/e08334c1b9d7d522239fef2d2b51ac23ed1b25e7))
* validate name expiration ([13703a4](https://www.github.com/aeternity/ae_mdw/commit/13703a432342cc44d5b2478e3412840c2b006684))


### Refactorings

* code review changes ([e5ce624](https://www.github.com/aeternity/ae_mdw/commit/e5ce624b00fb904971db35283672674d5ac5653e))
* move task sup to async tasks ([689bb60](https://www.github.com/aeternity/ae_mdw/commit/689bb60650d62336e49b0e752991eba88d2504a9))
* task sets done and simplified long task consumer ([f88f392](https://www.github.com/aeternity/ae_mdw/commit/f88f392619bc5b13812047d9932240b4d4306469))
* tests comparision of names with auction ([016e357](https://www.github.com/aeternity/ae_mdw/commit/016e35756802349b33722eb070bfc07718611b19))


### CI / CD

* credo fixes ([7255760](https://www.github.com/aeternity/ae_mdw/commit/7255760e3abd72a553cf70a0262025cddfe09a6c))
* credo moduledoc finding ([713558e](https://www.github.com/aeternity/ae_mdw/commit/713558ece7916a052ce9c70d5cbf2bab337f6dce))
* credo warnings ([d814bdd](https://www.github.com/aeternity/ae_mdw/commit/d814bdda26aa74183331aceab35deb34991e4d64))
* disable old credo warnings ([bf258d2](https://www.github.com/aeternity/ae_mdw/commit/bf258d20e83a85863bdfdeabbf0566b83db7f355))
* format and dialyzer ([1d605f4](https://www.github.com/aeternity/ae_mdw/commit/1d605f498a96cb38c9b2ded2c036403a7e4da78d))
* ignore existing credo warnings ([a953db1](https://www.github.com/aeternity/ae_mdw/commit/a953db1265e4a002f1534392ae2ccda29de6a5a3))
* linter ([63e4600](https://www.github.com/aeternity/ae_mdw/commit/63e4600e9fb9e3e222ecb6a34ba97e0a32b29180))
* new plt ([bb7022b](https://www.github.com/aeternity/ae_mdw/commit/bb7022b3478117284e8ff7fd006848e6e476ddf6))
* new plt ([90b336e](https://www.github.com/aeternity/ae_mdw/commit/90b336ebdc67272fefc3e6b75648bcb1cbbbe320))


### Miscellaneous

* remove comment ([1795c2b](https://www.github.com/aeternity/ae_mdw/commit/1795c2ba02263032f98eba60177c2baa8f15028b))
* use Blocks.height type ([038fb57](https://www.github.com/aeternity/ae_mdw/commit/038fb576a1b0b36cfc30289aed93355dac0213f8))


### Testing

* add aditional test case for transfers ([1a89b38](https://www.github.com/aeternity/ae_mdw/commit/1a89b38d8e44d9b19e96d9f629aadb6115e70ccc))
* add test case with mixed prefixes ([143bef7](https://www.github.com/aeternity/ae_mdw/commit/143bef77be0c879a8ab8027ec4ed8f83ba84bcd3))
* add testcase for account filtered transfers backwards ([fc4c00e](https://www.github.com/aeternity/ae_mdw/commit/fc4c00e40af44b66f8d4ffc7d3041409034ed3a9))
* async store tests ([0584ff8](https://www.github.com/aeternity/ae_mdw/commit/0584ff82515ffb1d908ca5cac6ca6b2edf8ec71c))
* avoid mutual side effects on stats ([1ca419a](https://www.github.com/aeternity/ae_mdw/commit/1ca419a186dabd096b24cae54dbb05f63a662e20))
* include kind filter on account transfers test ([9b1e3d5](https://www.github.com/aeternity/ae_mdw/commit/9b1e3d51ffde8e56681a78e5f5360f675b9b9690))
* long tasks test fixed ([a77b5a6](https://www.github.com/aeternity/ae_mdw/commit/a77b5a661d8c7a15a40a2aa27f2fc49c93321000))
* longs tasks stats ([598c75e](https://www.github.com/aeternity/ae_mdw/commit/598c75e0337b4604c2fa4bb7b9b0e2306b5a79a9))
* notify and wait for consumer ([fb03a09](https://www.github.com/aeternity/ae_mdw/commit/fb03a09edd9a6bf47da73adf1085fa9ad0121cee))
* proto_vsn for name unit tests ([f8aaa10](https://www.github.com/aeternity/ae_mdw/commit/f8aaa1047dc35735137ceee4c3a005625ee7dc7b))

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
