# Changelog

### [1.34.1](https://www.github.com/aeternity/ae_mdw/compare/v1.34.0...v1.34.1) (2023-01-05)


### Miscellaneous

* **ci:** use custom token instead of default ([#1107](https://www.github.com/aeternity/ae_mdw/issues/1107)) ([d1f0e6a](https://www.github.com/aeternity/ae_mdw/commit/d1f0e6a8b7c385401ba957af4d8d1ab43f5e7900))

## [1.34.0](https://www.github.com/aeternity/ae_mdw/compare/v1.33.0...v1.34.0) (2023-01-04)


### Features

* add block hash to activities ([#1098](https://www.github.com/aeternity/ae_mdw/issues/1098)) ([f743612](https://www.github.com/aeternity/ae_mdw/commit/f7436128770f07529680cb003cbf0c1c182d30b1))
* include source tx_hash on nested names endpoints ([#1104](https://www.github.com/aeternity/ae_mdw/issues/1104)) ([15bd964](https://www.github.com/aeternity/ae_mdw/commit/15bd96433aafce6e3c4c3aae146852cc06b999bf))
* introduce {bi, {txi, local_idx}} for precise internal txs refs ([#1088](https://www.github.com/aeternity/ae_mdw/issues/1088)) ([e5df7b5](https://www.github.com/aeternity/ae_mdw/commit/e5df7b565155cb2a2c2a95cc1034979b765bc3e8))
* query channel reserve at a hash ([#1106](https://www.github.com/aeternity/ae_mdw/issues/1106)) ([e595f0b](https://www.github.com/aeternity/ae_mdw/commit/e595f0b91868a9c3738626a959ecb8c30adcc59d))


### Miscellaneous

* **ci:** conditional dockerhub build env ([#1103](https://www.github.com/aeternity/ae_mdw/issues/1103)) ([184b112](https://www.github.com/aeternity/ae_mdw/commit/184b11229cf30f00c8bc191f1f37c46003b800bd))
* **ci:** make sure workflow is triggered on push ([#1097](https://www.github.com/aeternity/ae_mdw/issues/1097)) ([c8f498d](https://www.github.com/aeternity/ae_mdw/commit/c8f498db00d62fa8fff623d7717730bd6cb3a8db))
* remove tx hashes handling on int contract calls ([#1099](https://www.github.com/aeternity/ae_mdw/issues/1099)) ([706b785](https://www.github.com/aeternity/ae_mdw/commit/706b7853f93304f7a3c43987d8f61495c8f5e50d))
* use master instead of latest to pull docker image ([#1100](https://www.github.com/aeternity/ae_mdw/issues/1100)) ([9b06e72](https://www.github.com/aeternity/ae_mdw/commit/9b06e7270c2f4013d8ea6dc3647b68e07f30b300))

## [1.33.0](https://www.github.com/aeternity/ae_mdw/compare/v1.32.0...v1.33.0) (2022-12-23)


### Features

* add node details to channel page ([#1083](https://www.github.com/aeternity/ae_mdw/issues/1083)) ([260027c](https://www.github.com/aeternity/ae_mdw/commit/260027cf8bc2c073f5012d18a333eeff845deeff))
* add v2 websocket implementation ([#1072](https://www.github.com/aeternity/ae_mdw/issues/1072)) ([24bdc75](https://www.github.com/aeternity/ae_mdw/commit/24bdc752434bb42d191c131428503cad469abbd1))
* format aexn activities same as aexn transfers endpoints ([#1092](https://www.github.com/aeternity/ae_mdw/issues/1092)) ([37a5005](https://www.github.com/aeternity/ae_mdw/commit/37a50056fbfdf15276d2dc257914f1bebbd269ae))
* return event name when it is aexn ([#1090](https://www.github.com/aeternity/ae_mdw/issues/1090)) ([bc54cd6](https://www.github.com/aeternity/ae_mdw/commit/bc54cd63044bb88906637aeb0445c4ea4e132d5c))
* track nft template edition supply  ([#1078](https://www.github.com/aeternity/ae_mdw/issues/1078)) ([dfd84fd](https://www.github.com/aeternity/ae_mdw/commit/dfd84fde0b3e9a9adebf7bb490739c00894d65fd))


### Bug Fixes

* handle inner name_update pointers ([#1093](https://www.github.com/aeternity/ae_mdw/issues/1093)) ([4ac2316](https://www.github.com/aeternity/ae_mdw/commit/4ac23160b0dc04cf2d1205228cb3fb9e42a851ef))
* name of sender parameter of get_aex9_pair_transfers ([#1062](https://www.github.com/aeternity/ae_mdw/issues/1062)) ([da7531f](https://www.github.com/aeternity/ae_mdw/commit/da7531f25d0e16de40b6205f2f5b4adbcfc9ddf4))
* remove dockerization from ci tests run ([#1080](https://www.github.com/aeternity/ae_mdw/issues/1080)) ([295918d](https://www.github.com/aeternity/ae_mdw/commit/295918ded99c928bb9394702c0927c030b540577))
* remove extra colon before in path parameter name ([#1063](https://www.github.com/aeternity/ae_mdw/issues/1063)) ([08554db](https://www.github.com/aeternity/ae_mdw/commit/08554dbf5ae55312f4965791a9887184a1b7bcd9))
* update balance when adding liquidity ([#1094](https://www.github.com/aeternity/ae_mdw/issues/1094)) ([dd41834](https://www.github.com/aeternity/ae_mdw/commit/dd41834f2eb2d5b5e3c4bdbd15a75e1872441077))


### CI / CD

* enable docker image tests ([#1084](https://www.github.com/aeternity/ae_mdw/issues/1084)) ([7f05621](https://www.github.com/aeternity/ae_mdw/commit/7f05621dd64b9fd2709783e9fde60807b042222b))
* publish only tagged images (w/o tests) ([#1085](https://www.github.com/aeternity/ae_mdw/issues/1085)) ([b7ca317](https://www.github.com/aeternity/ae_mdw/commit/b7ca317f961ddcc05a774308b1f7e82a2dff966c))


### Miscellaneous

* add migration and update docs for nft templates ([#1081](https://www.github.com/aeternity/ae_mdw/issues/1081)) ([8eafec8](https://www.github.com/aeternity/ae_mdw/commit/8eafec8711b880463658dbc3d11c4fb9571c92fd))
* add proper typing to sync transaction nested function calls ([#1082](https://www.github.com/aeternity/ae_mdw/issues/1082)) ([f403c40](https://www.github.com/aeternity/ae_mdw/commit/f403c40e2a01d247db57b6abf676620b635574d1))
* add typespecs to all Db.Model records ([#1073](https://www.github.com/aeternity/ae_mdw/issues/1073)) ([73a906a](https://www.github.com/aeternity/ae_mdw/commit/73a906a429d5b4231c276f9a0f30885394a15e35))
* add union of model-specific State typespecs ([#1079](https://www.github.com/aeternity/ae_mdw/issues/1079)) ([46f7ca3](https://www.github.com/aeternity/ae_mdw/commit/46f7ca3a85a51b67e7d475d287230c841b3cf0bc))
* **ci:** separate docker compose by env ([#1086](https://www.github.com/aeternity/ae_mdw/issues/1086)) ([1d63f4a](https://www.github.com/aeternity/ae_mdw/commit/1d63f4ae5a7934f17998fd5fd65cff10fb51adb7))
* **ci:** simplify workflow triggering ([#1074](https://www.github.com/aeternity/ae_mdw/issues/1074)) ([f4e3cbe](https://www.github.com/aeternity/ae_mdw/commit/f4e3cbe5aaaf234a207ecca2315f90d0d2185b49))
* remove old makefile ([#1091](https://www.github.com/aeternity/ae_mdw/issues/1091)) ([07b02cb](https://www.github.com/aeternity/ae_mdw/commit/07b02cb6a9751f822896723f2226c043729b9634))
* specialize build envs ([#1089](https://www.github.com/aeternity/ae_mdw/issues/1089)) ([71f5b84](https://www.github.com/aeternity/ae_mdw/commit/71f5b84ab844c8f08c5bf3238e5de38354b48a9c))

## [1.32.0](https://www.github.com/aeternity/ae_mdw/compare/v1.31.0...v1.32.0) (2022-12-09)


### Features

* add /v2/channels/:id detail page ([#1064](https://www.github.com/aeternity/ae_mdw/issues/1064)) ([7c86a87](https://www.github.com/aeternity/ae_mdw/commit/7c86a875e342661b77ed918702173b3c47cb43f6))
* use aex9 event-based balance ([#1070](https://www.github.com/aeternity/ae_mdw/issues/1070)) ([7fa832b](https://www.github.com/aeternity/ae_mdw/commit/7fa832bdeb6dcdfa5c69a19b6c8b46b4ac6112d5))


### Testing

* ensure proper model declaration ([#1067](https://www.github.com/aeternity/ae_mdw/issues/1067)) ([ffde479](https://www.github.com/aeternity/ae_mdw/commit/ffde47975c8b5e43956160e01a5ed0287fafd0f6))


### CI / CD

* automatically publish docker images ([#1043](https://www.github.com/aeternity/ae_mdw/issues/1043)) ([d3013db](https://www.github.com/aeternity/ae_mdw/commit/d3013db1a570bd7bfcb87515d2606271189e45ad))


### Miscellaneous

* allow network id for local environment ([#1059](https://www.github.com/aeternity/ae_mdw/issues/1059)) ([4d49efe](https://www.github.com/aeternity/ae_mdw/commit/4d49efecf081802204a998e256e918fae7cf4ada))
* index only event-based aex9 balances ([#1071](https://www.github.com/aeternity/ae_mdw/issues/1071)) ([71212a8](https://www.github.com/aeternity/ae_mdw/commit/71212a864ef55f7834b23ff260999f45bb532199))

## [1.31.0](https://www.github.com/aeternity/ae_mdw/compare/v1.30.0...v1.31.0) (2022-12-02)


### Features

* add aex9 presence after event ([#1057](https://www.github.com/aeternity/ae_mdw/issues/1057)) ([d348987](https://www.github.com/aeternity/ae_mdw/commit/d3489877f8f3716c4453032e9d9e1d690c465d43))
* add auth function name to ga_attach ([#1048](https://www.github.com/aeternity/ae_mdw/issues/1048)) ([ea937a5](https://www.github.com/aeternity/ae_mdw/commit/ea937a54985f1f8cf956915a9d5392726f63240b))
* add name /transfers and /updates paginated endpoints ([#1049](https://www.github.com/aeternity/ae_mdw/issues/1049)) ([af52df2](https://www.github.com/aeternity/ae_mdw/commit/af52df20e48c38bd61c526539c1f7194d0de4d06))
* handle nft template edition limit ([#1051](https://www.github.com/aeternity/ae_mdw/issues/1051)) ([8872290](https://www.github.com/aeternity/ae_mdw/commit/8872290de780f44299067bb86fef20663c1e4cbf))
* include tx_hash on NameClaim activity ([#1052](https://www.github.com/aeternity/ae_mdw/issues/1052)) ([40797ab](https://www.github.com/aeternity/ae_mdw/commit/40797ab42af4fea166de7e8b9c3ce53d4e20e75a))


### Refactorings

* get immediately returned nft extensions ([#1047](https://www.github.com/aeternity/ae_mdw/issues/1047)) ([3b2b16e](https://www.github.com/aeternity/ae_mdw/commit/3b2b16ee6ad235f81da7bf6ad960dc106fcecc23))


### Testing

* use strict version on otp ci ([#1056](https://www.github.com/aeternity/ae_mdw/issues/1056)) ([5f5a499](https://www.github.com/aeternity/ae_mdw/commit/5f5a4990b25b6fb22747328294de953901ab1582))
* validate kbi range with blockchainsim ([#1055](https://www.github.com/aeternity/ae_mdw/issues/1055)) ([5aff9e0](https://www.github.com/aeternity/ae_mdw/commit/5aff9e09fae93e08cf8255790ad2ac0e5599ac29))


### Miscellaneous

* add template limit details to edition ([#1058](https://www.github.com/aeternity/ae_mdw/issues/1058)) ([0b32825](https://www.github.com/aeternity/ae_mdw/commit/0b32825f3a3b5ab593583d9505c02a70923f31fe))

## [1.30.0](https://www.github.com/aeternity/ae_mdw/compare/v1.29.1...v1.30.0) (2022-11-28)


### Features

* add /names/:id/claims endpoint ([#1037](https://www.github.com/aeternity/ae_mdw/issues/1037)) ([bc31513](https://www.github.com/aeternity/ae_mdw/commit/bc31513fed7cd0da121cad4e5a0db67c732fc7f3))
* handle nft contract limits ([#1040](https://www.github.com/aeternity/ae_mdw/issues/1040)) ([91a58f0](https://www.github.com/aeternity/ae_mdw/commit/91a58f0cb2bb721819b87b1ad2df4442b6d44f2e))


### Bug Fixes

* adjust git revision digits to allow variable length ([#1038](https://www.github.com/aeternity/ae_mdw/issues/1038)) ([5870dc9](https://www.github.com/aeternity/ae_mdw/commit/5870dc94906fb7579c3d869b407b7bb6797d9e37))
* encode non-string contract log data ([#1036](https://www.github.com/aeternity/ae_mdw/issues/1036)) ([6198316](https://www.github.com/aeternity/ae_mdw/commit/6198316c787b4d3eedfd2fa2f4e5137d73fbae0c))
* update async tasks db count on save ([#1025](https://www.github.com/aeternity/ae_mdw/issues/1025)) ([5f21192](https://www.github.com/aeternity/ae_mdw/commit/5f2119203da4c5972f72f546018a13e465507978))


### Testing

* validate multiple and remote aexn transfers ([#1034](https://www.github.com/aeternity/ae_mdw/issues/1034)) ([3eafff2](https://www.github.com/aeternity/ae_mdw/commit/3eafff2d1a8f8878f5aa88d539f8d2b051d790a4))


### Refactorings

* move ws subscription to specific module ([#1030](https://www.github.com/aeternity/ae_mdw/issues/1030)) ([1abc8f3](https://www.github.com/aeternity/ae_mdw/commit/1abc8f30b22b1fce787d64817c22e31e927aaf00))


### Miscellaneous

* add node version argument to docker builds ([904996b](https://www.github.com/aeternity/ae_mdw/commit/904996b0276db6cb7596885b9519d016bec2e18a))
* handle dry run timeout ([#1026](https://www.github.com/aeternity/ae_mdw/issues/1026)) ([054e87b](https://www.github.com/aeternity/ae_mdw/commit/054e87bec77305fd1c6cf31826fb996ad782b875))
* remove unnecessary smart_record dependency ([#1041](https://www.github.com/aeternity/ae_mdw/issues/1041)) ([e329f49](https://www.github.com/aeternity/ae_mdw/commit/e329f493e02f83c96934003ea785042e1b968dbc))
* remove unused migrations ([#1039](https://www.github.com/aeternity/ae_mdw/issues/1039)) ([6d8125b](https://www.github.com/aeternity/ae_mdw/commit/6d8125b705982dcc06cba2f8ea72c8fc2ba1e0c2))
* root dir cleanup ([#1046](https://www.github.com/aeternity/ae_mdw/issues/1046)) ([21aa19f](https://www.github.com/aeternity/ae_mdw/commit/21aa19f1ff51a3c671d7479a6a0d6d613cba766e))
* set network_id as runtime config ([#1045](https://www.github.com/aeternity/ae_mdw/issues/1045)) ([159371a](https://www.github.com/aeternity/ae_mdw/commit/159371ae81bb48eeaebb827fa0e9938758630e63))

### [1.29.1](https://www.github.com/aeternity/ae_mdw/compare/v1.29.0...v1.29.1) (2022-11-17)


### Bug Fixes

* avoid double aex9 event balance update ([#1020](https://www.github.com/aeternity/ae_mdw/issues/1020)) ([91c6036](https://www.github.com/aeternity/ae_mdw/commit/91c603694c25d23a819fc00274fda4bd61a6d436))
* handle account_pubkey recipient pointee ([9041da0](https://www.github.com/aeternity/ae_mdw/commit/9041da03e4a30dd4409901c567fe494b496a5dbf))


### Miscellaneous

* divide swagger v2 docs into separate resource files ([#1019](https://www.github.com/aeternity/ae_mdw/issues/1019)) ([bddbdff](https://www.github.com/aeternity/ae_mdw/commit/bddbdfffd563b4451eb18af69efdd09c217a5a58))

## [1.29.0](https://www.github.com/aeternity/ae_mdw/compare/v1.28.1...v1.29.0) (2022-11-14)


### Features

* add name claims to the activities retrieved by name hash ([#1014](https://www.github.com/aeternity/ae_mdw/issues/1014)) ([33d56f3](https://www.github.com/aeternity/ae_mdw/commit/33d56f3c524a80d6b69dd1efedd1fad89af10468))
* add oracle query expiration internal refund transfers ([#1001](https://www.github.com/aeternity/ae_mdw/issues/1001)) ([8539d2e](https://www.github.com/aeternity/ae_mdw/commit/8539d2ef6d5e800c3b3b8cdec35245b13a46c97d))
* display name buyer from inner claim tx ([#1016](https://www.github.com/aeternity/ae_mdw/issues/1016)) ([ca41a7b](https://www.github.com/aeternity/ae_mdw/commit/ca41a7b332e5bde5efd7745a051f0bc319c17b6b))


### Bug Fixes

* ignore oracle queries that do not have the right calculated nonce ([#1009](https://www.github.com/aeternity/ae_mdw/issues/1009)) ([31de473](https://www.github.com/aeternity/ae_mdw/commit/31de4738d47f66f336d7d3280e4931e07d3dad26))
* render binary pointer key on name related endpoints ([#1004](https://www.github.com/aeternity/ae_mdw/issues/1004)) ([a62d03f](https://www.github.com/aeternity/ae_mdw/commit/a62d03f863b440030f75b84f11f0181da2c40b53))
* scope contract calls filtered by function properly ([#1005](https://www.github.com/aeternity/ae_mdw/issues/1005)) ([6567619](https://www.github.com/aeternity/ae_mdw/commit/65676196b6cbd6496a47be921d0478f021dba7d1))
* use last call txi for hash account balance ([#1017](https://www.github.com/aeternity/ae_mdw/issues/1017)) ([0be0aed](https://www.github.com/aeternity/ae_mdw/commit/0be0aed243e759bed925913d372fe10d92e56097))


### Miscellaneous

* allow /txs/count to be filtered by tx_type ([#1008](https://www.github.com/aeternity/ae_mdw/issues/1008)) ([84ba88f](https://www.github.com/aeternity/ae_mdw/commit/84ba88fe6e2d8825e68ede1553c748adbbc9b304))
* use built-in phoenix websocket ([#1011](https://www.github.com/aeternity/ae_mdw/issues/1011)) ([5e8582a](https://www.github.com/aeternity/ae_mdw/commit/5e8582a97068b005d816acc5ff0e770b0dd1a1ac))

### [1.28.1](https://www.github.com/aeternity/ae_mdw/compare/v1.28.0...v1.28.1) (2022-11-06)


### Bug Fixes

* reintroduce nft_template model ([#1000](https://www.github.com/aeternity/ae_mdw/issues/1000)) ([466e29c](https://www.github.com/aeternity/ae_mdw/commit/466e29c5b7cf5553c3227b884d7bd61747ea852c))

## [1.28.0](https://www.github.com/aeternity/ae_mdw/compare/v1.27.0...v1.28.0) (2022-11-04)


### Features

* add response_id to channel settle rendering ([#994](https://www.github.com/aeternity/ae_mdw/issues/994)) ([0f46c5c](https://www.github.com/aeternity/ae_mdw/commit/0f46c5ce528a8386e33c3065b5182b0880ef8275))
* index nft templates ([#991](https://www.github.com/aeternity/ae_mdw/issues/991)) ([c279099](https://www.github.com/aeternity/ae_mdw/commit/c27909915827bcf5935def7418c6b0fab8334b69))


### Bug Fixes

* handle non-existing mbs txs endpoint response ([#992](https://www.github.com/aeternity/ae_mdw/issues/992)) ([3c62446](https://www.github.com/aeternity/ae_mdw/commit/3c6244610e7c0421b4be8989e372537f850abdb4))
* recalculate internal oracle query tx nonces ([#982](https://www.github.com/aeternity/ae_mdw/issues/982)) ([b87b3d7](https://www.github.com/aeternity/ae_mdw/commit/b87b3d79941e4a3fac2fb62617220b603ae26b80))
* render all pointers on names endpoint ([#995](https://www.github.com/aeternity/ae_mdw/issues/995)) ([ef0922e](https://www.github.com/aeternity/ae_mdw/commit/ef0922e14cf7c4ce71fb15dde6d2172cc341abae))

## [1.27.0](https://www.github.com/aeternity/ae_mdw/compare/v1.26.0...v1.27.0) (2022-11-02)


### Features

* update aex9 balance based on events ([#983](https://www.github.com/aeternity/ae_mdw/issues/983)) ([22c554d](https://www.github.com/aeternity/ae_mdw/commit/22c554d07d39a432f09a39e2244cacf48539ab89))


### Bug Fixes

* consider name updates and transfers for NameOwnerDeactivations ([#987](https://www.github.com/aeternity/ae_mdw/issues/987)) ([758acf9](https://www.github.com/aeternity/ae_mdw/commit/758acf96935972111ec9f43fefa4607cae85d49a))
* events from the node are obtained in reverse order ([#981](https://www.github.com/aeternity/ae_mdw/issues/981)) ([3340b7c](https://www.github.com/aeternity/ae_mdw/commit/3340b7cd09b31be57cd91e20d7493a22f039791f))
* render list of keyword lists args ([#976](https://www.github.com/aeternity/ae_mdw/issues/976)) ([aaf244a](https://www.github.com/aeternity/ae_mdw/commit/aaf244ac9fff1c56ae5f3a8baf05d85f50a281dc))


### Testing

* complement coverage for name syncing ([#978](https://www.github.com/aeternity/ae_mdw/issues/978)) ([ed81098](https://www.github.com/aeternity/ae_mdw/commit/ed81098f8cc077f2658c1f86dfbe497b285dc725))
* complement coverage for oracle syncing ([#977](https://www.github.com/aeternity/ae_mdw/issues/977)) ([c19e09b](https://www.github.com/aeternity/ae_mdw/commit/c19e09b18e2cba71adde92c4963da25ea2e6b81f))

## [1.26.0](https://www.github.com/aeternity/ae_mdw/compare/v1.25.1...v1.26.0) (2022-10-24)


### Features

* allow filtering names by owner/state ordered by deactivation ([#965](https://www.github.com/aeternity/ae_mdw/issues/965)) ([4c23fbe](https://www.github.com/aeternity/ae_mdw/commit/4c23fbe1003a6b55dbf22de49dffe63ffd4648ed))
* handle burn nft ([#970](https://www.github.com/aeternity/ae_mdw/issues/970)) ([6f3a5e5](https://www.github.com/aeternity/ae_mdw/commit/6f3a5e58def5d736c07da2e9ddf1aa2d705de498))
* render call details for ga_attach and ga_meta ([#972](https://www.github.com/aeternity/ae_mdw/issues/972)) ([8383c71](https://www.github.com/aeternity/ae_mdw/commit/8383c71e3d7f1919ff6dbea142ba42824d7849ce))


### Bug Fixes

* increment ga contract stat only on success ([#971](https://www.github.com/aeternity/ae_mdw/issues/971)) ([8694384](https://www.github.com/aeternity/ae_mdw/commit/8694384a927534bc3a980132169e4e0a04ce110c))


### Miscellaneous

* add return_type for ga_attach_tx ([#964](https://www.github.com/aeternity/ae_mdw/issues/964)) ([f6f69e3](https://www.github.com/aeternity/ae_mdw/commit/f6f69e3bdf90aa2547746d6e85aed0d3724cb49b))
* remove txi scoping support for new endpoints ([#968](https://www.github.com/aeternity/ae_mdw/issues/968)) ([3e83163](https://www.github.com/aeternity/ae_mdw/commit/3e83163b815f5b67b9f9e23bfe79b52d93d1437c))

### [1.25.1](https://www.github.com/aeternity/ae_mdw/compare/v1.25.0...v1.25.1) (2022-10-17)


### Bug Fixes

* handle any meta info value ([#962](https://www.github.com/aeternity/ae_mdw/issues/962)) ([b9e111a](https://www.github.com/aeternity/ae_mdw/commit/b9e111a1b6cdf0188532e1e9db72f048b9945213))

## [1.25.0](https://www.github.com/aeternity/ae_mdw/compare/v1.24.0...v1.25.0) (2022-10-17)


### Features

* add tx internal transfers to activities ([#957](https://www.github.com/aeternity/ae_mdw/issues/957)) ([ec875a3](https://www.github.com/aeternity/ae_mdw/commit/ec875a3f46cbead8d3d961107ad0d9a82fac9577))


### Bug Fixes

* render bid for names in auction ([#958](https://www.github.com/aeternity/ae_mdw/issues/958)) ([bb52e42](https://www.github.com/aeternity/ae_mdw/commit/bb52e42b58b2358ebe33474a3ac67e98f5696473))


### Miscellaneous

* add return type for ga_meta_tx ([#959](https://www.github.com/aeternity/ae_mdw/issues/959)) ([ba40c78](https://www.github.com/aeternity/ae_mdw/commit/ba40c7829a6412b89243a5314e65b443dded730b))

## [1.24.0](https://www.github.com/aeternity/ae_mdw/compare/v1.23.2...v1.24.0) (2022-10-12)


### Features

* add generation-only internal transfers to activities ([#935](https://www.github.com/aeternity/ae_mdw/issues/935)) ([0e8afb8](https://www.github.com/aeternity/ae_mdw/commit/0e8afb877765ac3dd137fdc9da96af99a5581982))


### Bug Fixes

* always return txs from last microblock ([37b5764](https://www.github.com/aeternity/ae_mdw/commit/37b576489120c5d480d1118a847673835acd8453))
* index remote log also with called contract ([#941](https://www.github.com/aeternity/ae_mdw/issues/941)) ([3d9a137](https://www.github.com/aeternity/ae_mdw/commit/3d9a137d4f01e01aa6abf7b255f3cdffac2b7cef))
* order gen-scoped txs and activities properly ([#954](https://www.github.com/aeternity/ae_mdw/issues/954)) ([6d7260e](https://www.github.com/aeternity/ae_mdw/commit/6d7260ebb46974b3cad84784ef768e933ed67ddf))
* return original error messages on txs invalid requests ([#953](https://www.github.com/aeternity/ae_mdw/issues/953)) ([f1036da](https://www.github.com/aeternity/ae_mdw/commit/f1036da6c403e96a8a02be249d0ca3b45ddf4bce))
* sort event logs by index ([#944](https://www.github.com/aeternity/ae_mdw/issues/944)) ([be3ec7f](https://www.github.com/aeternity/ae_mdw/commit/be3ec7f87fcc34db365c53f982a98cfa1d468e49))
* support listing active/inactive names when filterng by owner ([#947](https://www.github.com/aeternity/ae_mdw/issues/947)) ([8a1c8cb](https://www.github.com/aeternity/ae_mdw/commit/8a1c8cbd7a047a00fef4a8d34bccf7acb92924d7))


### Testing

* use always valid contract for invalid range test ([#955](https://www.github.com/aeternity/ae_mdw/issues/955)) ([2414b8b](https://www.github.com/aeternity/ae_mdw/commit/2414b8bfb48c3d62fc71975c2967376bf8b0f22b))


### Miscellaneous

* update aex141 signatures ([#952](https://www.github.com/aeternity/ae_mdw/issues/952)) ([0bd99a9](https://www.github.com/aeternity/ae_mdw/commit/0bd99a9d7f4f643bfea68566c448f070d144f3c7))

### [1.23.2](https://www.github.com/aeternity/ae_mdw/compare/v1.23.1...v1.23.2) (2022-10-10)


### Miscellaneous

* allow rendering static swagger.json (temporary fix) ([#945](https://www.github.com/aeternity/ae_mdw/issues/945)) ([fe0e3be](https://www.github.com/aeternity/ae_mdw/commit/fe0e3bec4c7f24da6f2e9fdceabdbb46ea7b0d8e))

### [1.23.1](https://www.github.com/aeternity/ae_mdw/compare/v1.23.0...v1.23.1) (2022-10-07)


### Bug Fixes

* allow sorting backward when gen first-last is the same ([f99b2c5](https://www.github.com/aeternity/ae_mdw/commit/f99b2c5032f0a1b88b55c824de8d9abbc39b4d21))
* handle other node tx locations ([#936](https://www.github.com/aeternity/ae_mdw/issues/936)) ([aec8bea](https://www.github.com/aeternity/ae_mdw/commit/aec8bea1cd832d9abd3e9af7438e7fb9eafd02f1))
* return {auction_bid, source} tuple on names owned_by_reply ([#940](https://www.github.com/aeternity/ae_mdw/issues/940)) ([70adf3f](https://www.github.com/aeternity/ae_mdw/commit/70adf3f187d5431738671d6a7445c5183a9ea26e))

## [1.23.0](https://www.github.com/aeternity/ae_mdw/compare/v1.22.0...v1.23.0) (2022-10-05)


### Features

* index oracle extend internal calls ([#933](https://www.github.com/aeternity/ae_mdw/issues/933)) ([d051180](https://www.github.com/aeternity/ae_mdw/commit/d051180d5940bb8068cc06a2ceb715eb482f7498))


### Bug Fixes

* add missing origin to oracle created by internal call ([#927](https://www.github.com/aeternity/ae_mdw/issues/927)) ([ba99629](https://www.github.com/aeternity/ae_mdw/commit/ba99629ffbeacccd76708db22216f2da2e4e5e65))
* return proper error when aex141 token is a partial int ([#926](https://www.github.com/aeternity/ae_mdw/issues/926)) ([95cd809](https://www.github.com/aeternity/ae_mdw/commit/95cd8092fb9779965bbd5bd48b0a24f460d4dbd1))
* set proper auction_timeout on names ([#932](https://www.github.com/aeternity/ae_mdw/issues/932)) ([d19be47](https://www.github.com/aeternity/ae_mdw/commit/d19be475d5c5598f387d2f9c2d81ac5c284bbf88))
* transform non encodable binary oracle fields into list ([#929](https://www.github.com/aeternity/ae_mdw/issues/929)) ([3de2cbb](https://www.github.com/aeternity/ae_mdw/commit/3de2cbbeeb8244c1fa5e3c533eaf0387cec3daf8))


### Refactorings

* move Db.Name syncing code to Sync.Name ([#925](https://www.github.com/aeternity/ae_mdw/issues/925)) ([f47703a](https://www.github.com/aeternity/ae_mdw/commit/f47703ad1f94f1765d8db928a0b68537d89307ba))
* print migrations total/duration using returned values ([#931](https://www.github.com/aeternity/ae_mdw/issues/931)) ([82d5e28](https://www.github.com/aeternity/ae_mdw/commit/82d5e28c3ead6360942fe6e2b95deee7c5bdd302))

## [1.22.0](https://www.github.com/aeternity/ae_mdw/compare/v1.21.1...v1.22.0) (2022-09-29)


### Features

* add aexn transfer activities ([#915](https://www.github.com/aeternity/ae_mdw/issues/915)) ([6cad834](https://www.github.com/aeternity/ae_mdw/commit/6cad8346d0c1e194af5e353083c951f3d4c7eb0b))


### Bug Fixes

* consider last txs when calculating mb tx count ([#917](https://www.github.com/aeternity/ae_mdw/issues/917)) ([9298edd](https://www.github.com/aeternity/ae_mdw/commit/9298edd00839872bf8fa5be65cd2f84fd53d24bf))


### Testing

* add cases websocket broadcasting ([#916](https://www.github.com/aeternity/ae_mdw/issues/916)) ([ca820ac](https://www.github.com/aeternity/ae_mdw/commit/ca820ac8ce0a632fca360c121ece01245f490b02))


### Miscellaneous

* improve dialyzer warnings to catch unmatched results ([#923](https://www.github.com/aeternity/ae_mdw/issues/923)) ([49388a8](https://www.github.com/aeternity/ae_mdw/commit/49388a831c5a477be9f774b3293056d450c488ff))
* upgrade phoenix and other deps ([#918](https://www.github.com/aeternity/ae_mdw/issues/918)) ([f5b4270](https://www.github.com/aeternity/ae_mdw/commit/f5b42702c01cd5922a672c2b2e8c8e84783674bd))

### [1.21.1](https://www.github.com/aeternity/ae_mdw/compare/v1.21.0...v1.21.1) (2022-09-26)


### Miscellaneous

* bump erlang to OTP 23 and elixir to 1.11 ([#909](https://www.github.com/aeternity/ae_mdw/issues/909)) ([fba6cfc](https://www.github.com/aeternity/ae_mdw/commit/fba6cfcd1d1c3ec58ac6df583afbc6c19174a026))
* cleanup tests warnings ([#914](https://www.github.com/aeternity/ae_mdw/issues/914)) ([d34ffb2](https://www.github.com/aeternity/ae_mdw/commit/d34ffb243db72e9e209bb4774250232790dd857d))

## [1.21.0](https://www.github.com/aeternity/ae_mdw/compare/v1.20.0...v1.21.0) (2022-09-26)


### Features

* add /accounts/:id/activities endpoint ([#906](https://www.github.com/aeternity/ae_mdw/issues/906)) ([950f738](https://www.github.com/aeternity/ae_mdw/commit/950f738833dd8152c41f103c87995649ee33b11e))
* include internal transactions as activities ([#911](https://www.github.com/aeternity/ae_mdw/issues/911)) ([5ab2cb2](https://www.github.com/aeternity/ae_mdw/commit/5ab2cb2d36b1590716545d59a1f209b4be419e96))


### Refactorings

* allocate smaller tuples for query streams ([#905](https://www.github.com/aeternity/ae_mdw/issues/905)) ([bd7229b](https://www.github.com/aeternity/ae_mdw/commit/bd7229b2ed5a48a31764bcf11d1e62c09891d397))


### Miscellaneous

* remove phoenix_swagger ([#912](https://www.github.com/aeternity/ae_mdw/issues/912)) ([05ece6c](https://www.github.com/aeternity/ae_mdw/commit/05ece6cbcfc68537627319258f09f081a606dda2))

## [1.20.0](https://www.github.com/aeternity/ae_mdw/compare/v1.19.1...v1.20.0) (2022-09-14)


### Features

* add /key-blocks endpoints with txs/mbs count ([#892](https://www.github.com/aeternity/ae_mdw/issues/892)) ([1b5f016](https://www.github.com/aeternity/ae_mdw/commit/1b5f016dd88d1032774d86fc9868d0d8ea44e7d1))
* add /key-blocks/:hash_or_kbi endpoint with mbs/txs count ([#895](https://www.github.com/aeternity/ae_mdw/issues/895)) ([b8a2e09](https://www.github.com/aeternity/ae_mdw/commit/b8a2e094eace0a0569ee2fb5eddd853eabb4328e))
* add /key-blocks/:hash_or_kbi/micro-blocks endpoint ([#896](https://www.github.com/aeternity/ae_mdw/issues/896)) ([0540074](https://www.github.com/aeternity/ae_mdw/commit/054007411c87bbaea9deee93db4c88cccbb6aea5))
* add /v2/micro-blocks/:hash endpoint ([#898](https://www.github.com/aeternity/ae_mdw/issues/898)) ([2c16e47](https://www.github.com/aeternity/ae_mdw/commit/2c16e477ac9feb981998735a7107903c1a04a003))
* add /v2/micro-blocks/:hash/txs endpoint ([#900](https://www.github.com/aeternity/ae_mdw/issues/900)) ([2312a8a](https://www.github.com/aeternity/ae_mdw/commit/2312a8a924ea4e79ec8640fc37ae33f75badfebd))
* add nft collection stats ([#899](https://www.github.com/aeternity/ae_mdw/issues/899)) ([5f5583a](https://www.github.com/aeternity/ae_mdw/commit/5f5583a206c45895f27af75db3b8438bcdfb5481))
* create nft ownership based on Mint event ([#897](https://www.github.com/aeternity/ae_mdw/issues/897)) ([929e7c5](https://www.github.com/aeternity/ae_mdw/commit/929e7c5369a2741f6ce0275f72a473c4a940eb4c))
* index and fetch nft owners on a collection ([#894](https://www.github.com/aeternity/ae_mdw/issues/894)) ([1d06bbf](https://www.github.com/aeternity/ae_mdw/commit/1d06bbfb7132680b0dd11cbd64794268bcae0d81))
* index channels and add active channels endpoint ([#889](https://www.github.com/aeternity/ae_mdw/issues/889)) ([d86b1cc](https://www.github.com/aeternity/ae_mdw/commit/d86b1cc96d1668a7e0ec37b9b8c463e51c5265c1))


### Miscellaneous

* accept contract param besides contract_id ([#903](https://www.github.com/aeternity/ae_mdw/issues/903)) ([af3471f](https://www.github.com/aeternity/ae_mdw/commit/af3471f0e9a0224fc402205f6e135c21290fdcd2))
* disable phoenix code_reloader by default ([#904](https://www.github.com/aeternity/ae_mdw/issues/904)) ([1b21738](https://www.github.com/aeternity/ae_mdw/commit/1b2173862b923608a208340b91292dadd0224380))

### [1.19.1](https://www.github.com/aeternity/ae_mdw/compare/v1.19.0...v1.19.1) (2022-09-05)


### Bug Fixes

* map recipient record when filtering by nft collection ([#890](https://www.github.com/aeternity/ae_mdw/issues/890)) ([251c5a8](https://www.github.com/aeternity/ae_mdw/commit/251c5a8eb80c94bdf1f1f156425831047ab51a13))

## [1.19.0](https://www.github.com/aeternity/ae_mdw/compare/v1.18.0...v1.19.0) (2022-09-01)


### Features

* generalize transfer history for aex141 ([#882](https://www.github.com/aeternity/ae_mdw/issues/882)) ([c6cb13c](https://www.github.com/aeternity/ae_mdw/commit/c6cb13caec51b0240280d96bc0265225f032d831))
* index miners count and total rewards from fees ([#854](https://www.github.com/aeternity/ae_mdw/issues/854)) ([725beb7](https://www.github.com/aeternity/ae_mdw/commit/725beb7ef3329e0283cf772c4e714d8c1afe713c))
* index nft transfers by collection ([#887](https://www.github.com/aeternity/ae_mdw/issues/887)) ([322dac0](https://www.github.com/aeternity/ae_mdw/commit/322dac06a5a42a0e8006c31fb5aca2249c37e9c4))


### Bug Fixes

* calculate prev on build_gen_pagination correctly ([#877](https://www.github.com/aeternity/ae_mdw/issues/877)) ([9a3011b](https://www.github.com/aeternity/ae_mdw/commit/9a3011b84e88827559792150db0aa3962616f5c2))
* convert transfer event token_id to integer ([#878](https://www.github.com/aeternity/ae_mdw/issues/878)) ([8e2be75](https://www.github.com/aeternity/ae_mdw/commit/8e2be75e5c7d922ff5aaf3460162b86670f14b87))
* handle out_of_gas_error on aex141 cleanup ([#883](https://www.github.com/aeternity/ae_mdw/issues/883)) ([c1d556d](https://www.github.com/aeternity/ae_mdw/commit/c1d556d54443ee61fdb475e9068977f04f37c39c))
* handle variant owner return ([#879](https://www.github.com/aeternity/ae_mdw/issues/879)) ([86c0383](https://www.github.com/aeternity/ae_mdw/commit/86c0383e47b9b36cd58d1abfc39135fe84e803c0))
* remove rocksdb wrapping code that created DB inconsistencies ([#865](https://www.github.com/aeternity/ae_mdw/issues/865)) ([530add4](https://www.github.com/aeternity/ae_mdw/commit/530add4ebe4899e401d232639cc55a7038962ccc))
* temporarily hardcode node version in docker build ([a6da18c](https://www.github.com/aeternity/ae_mdw/commit/a6da18ce84937b181df6cb90453ecfbc9f3f8a35))
* treat AENS.update calls name_ttl as an absolute height ([#872](https://www.github.com/aeternity/ae_mdw/issues/872)) ([89bf5d2](https://www.github.com/aeternity/ae_mdw/commit/89bf5d237dffca4c007168131c2570c275ef2c6e))


### Refactorings

* add type definitions to Model records ([#868](https://www.github.com/aeternity/ae_mdw/issues/868)) ([f3a9475](https://www.github.com/aeternity/ae_mdw/commit/f3a9475143b72051410ce5a523a3ca056e6c07f7))


### Miscellaneous

* add micro_blocks to /v2/blocks/{height} ([#876](https://www.github.com/aeternity/ae_mdw/issues/876)) ([01aba8a](https://www.github.com/aeternity/ae_mdw/commit/01aba8a062535c1ab6dcb641adfdf9a07124fdaf))
* update aex141 metadata signature ([#874](https://www.github.com/aeternity/ae_mdw/issues/874)) ([22066aa](https://www.github.com/aeternity/ae_mdw/commit/22066aa1d99bef31553465356e683b68bd366ec5))


### Testing

* add cases for rocksdb multiple dirty delete calls ([#867](https://www.github.com/aeternity/ae_mdw/issues/867)) ([27071f4](https://www.github.com/aeternity/ae_mdw/commit/27071f45fc7cc706e949154ac7b389cb4bfc84db))
* update oracle and aex9 integration tests ([#871](https://www.github.com/aeternity/ae_mdw/issues/871)) ([78467bd](https://www.github.com/aeternity/ae_mdw/commit/78467bd33e1e49a78029ab7c1be943ba733640f1))

## [1.18.0](https://www.github.com/aeternity/ae_mdw/compare/v1.17.0...v1.18.0) (2022-08-23)


### Features

* log open/closed channels together with their locked AE ([#840](https://www.github.com/aeternity/ae_mdw/issues/840)) ([d965275](https://www.github.com/aeternity/ae_mdw/commit/d965275c5173e8406ceb6f546bb054a38f30df2d))


### Bug Fixes

* check for nil before encoding contract pks ([#855](https://www.github.com/aeternity/ae_mdw/issues/855)) ([dcd4c68](https://www.github.com/aeternity/ae_mdw/commit/dcd4c68342e10d0c0e964f4c679df5031c3d62a8))
* filter contracts after account balance dry-run on blockhash ([#861](https://www.github.com/aeternity/ae_mdw/issues/861)) ([40da750](https://www.github.com/aeternity/ae_mdw/commit/40da750a3a3a0d2d1b6355d2066926aee251ed02))
* query aexn by exact name or symbol on v1 and v2 ([#862](https://www.github.com/aeternity/ae_mdw/issues/862)) ([d97058f](https://www.github.com/aeternity/ae_mdw/commit/d97058fd34e686617a0a097d619a18f67d946847))
* use block_index on v1 aex9 height balances ([#852](https://www.github.com/aeternity/ae_mdw/issues/852)) ([77bb961](https://www.github.com/aeternity/ae_mdw/commit/77bb961426b6313759f663bb0200ddcf5db3ffb4))


### Miscellaneous

* add progress indicator on name fees migration ([#856](https://www.github.com/aeternity/ae_mdw/issues/856)) ([53f7bfc](https://www.github.com/aeternity/ae_mdw/commit/53f7bfcd94b394259dd4131555a6a27d3b6b87f3))
* set dry run gas upper limit ([#845](https://www.github.com/aeternity/ae_mdw/issues/845)) ([540f6d7](https://www.github.com/aeternity/ae_mdw/commit/540f6d7c1495b4f1fa88c53a1d64d6a4d3c34e62))
* sorts aex9 account balances from last to first ([#858](https://www.github.com/aeternity/ae_mdw/issues/858)) ([0e81e25](https://www.github.com/aeternity/ae_mdw/commit/0e81e2545a56749230d489f0363f6f7c1f7ed715))


### Testing

* complement to missing unit tests for AEX-141 ([#843](https://www.github.com/aeternity/ae_mdw/issues/843)) ([900636d](https://www.github.com/aeternity/ae_mdw/commit/900636d183925a7c67e4bdf6045ec00a22a7f967))
* skip creating a store on integration tests ([#857](https://www.github.com/aeternity/ae_mdw/issues/857)) ([654228e](https://www.github.com/aeternity/ae_mdw/commit/654228ecb3a13b69ce602c75247ce6c715d6c932))
* update hardfork accounts integration case ([#859](https://www.github.com/aeternity/ae_mdw/issues/859)) ([8450d0a](https://www.github.com/aeternity/ae_mdw/commit/8450d0a005aae3a701145c3ededd36cffedc3cc8))
* update integration test regardin aex9 missing presence ([#853](https://www.github.com/aeternity/ae_mdw/issues/853)) ([5c904f6](https://www.github.com/aeternity/ae_mdw/commit/5c904f6caa37882acb9d3e453b391e36f2fa987d))

## [1.17.0](https://www.github.com/aeternity/ae_mdw/compare/v1.16.1...v1.17.0) (2022-08-18)


### Features

* add txs per second stat on /stats ([#834](https://www.github.com/aeternity/ae_mdw/issues/834)) ([1e010de](https://www.github.com/aeternity/ae_mdw/commit/1e010deb79fb27e999d16f84dc7babe0755d6a66))
* complement to migrated tokens ([#838](https://www.github.com/aeternity/ae_mdw/issues/838)) ([7d6de8b](https://www.github.com/aeternity/ae_mdw/commit/7d6de8b8a968187f1198895dec27af8189be0de2))
* expose names locked/burned fees on stats ([#822](https://www.github.com/aeternity/ae_mdw/issues/822)) ([d75d45f](https://www.github.com/aeternity/ae_mdw/commit/d75d45f78ad6c2428a69cccf3dff7bfaf4acbfd8))
* synchronize async tasks write ([#818](https://www.github.com/aeternity/ae_mdw/issues/818)) ([407576e](https://www.github.com/aeternity/ae_mdw/commit/407576ea93fa9c19666a49710ac75799dc0f4d36))


### Bug Fixes

* decrease async task producer dequeue time ([#832](https://www.github.com/aeternity/ae_mdw/issues/832)) ([8b7a655](https://www.github.com/aeternity/ae_mdw/commit/8b7a655a86d344bd4d065ad2a8720820bc8e561a))
* dequeue async tasks non-preemptively ([#841](https://www.github.com/aeternity/ae_mdw/issues/841)) ([5868472](https://www.github.com/aeternity/ae_mdw/commit/586847287a530c8a06e35e461644796a9d929a9e))
* handle dry-run error when contract is not present ([#835](https://www.github.com/aeternity/ae_mdw/issues/835)) ([26b4bd4](https://www.github.com/aeternity/ae_mdw/commit/26b4bd4f5472517b79eda9d00730dd1cccc14617))
* increase auctions started stat only once ([#826](https://www.github.com/aeternity/ae_mdw/issues/826)) ([278e5ee](https://www.github.com/aeternity/ae_mdw/commit/278e5ee4d882d2ab718cd66ec8f3272c7f57513f))
* increase long tasks throughput ([f93d72b](https://www.github.com/aeternity/ae_mdw/commit/f93d72b3d3d90566240df0ce3b420e4faddd1d0b))
* rerun failed task and fix processing state ([#848](https://www.github.com/aeternity/ae_mdw/issues/848)) ([8afcb9f](https://www.github.com/aeternity/ae_mdw/commit/8afcb9f5711c3a7856655b017afbb4e69f66251c))
* update opts usage on Names.fetch_previous_list/2 ([#825](https://www.github.com/aeternity/ae_mdw/issues/825)) ([c5e7f40](https://www.github.com/aeternity/ae_mdw/commit/c5e7f4044bd72dcbc2a42a35b3d7da0e45718a4c))


### Miscellaneous

* adapt to AEX-141 standard change ([#829](https://www.github.com/aeternity/ae_mdw/issues/829)) ([45f184f](https://www.github.com/aeternity/ae_mdw/commit/45f184f21a6d528449bae761c38af7935033d987))


### Refactorings

* decrease consumer async server wait and sleep ([#833](https://www.github.com/aeternity/ae_mdw/issues/833)) ([a34ff73](https://www.github.com/aeternity/ae_mdw/commit/a34ff73e4fcc6725e40c12ccecd430f6ed0b5b8c))

### [1.16.1](https://www.github.com/aeternity/ae_mdw/compare/v1.16.0...v1.16.1) (2022-08-03)


### Bug Fixes

* include ga_attach_tx when counting contracts ([#819](https://www.github.com/aeternity/ae_mdw/issues/819)) ([e0650b5](https://www.github.com/aeternity/ae_mdw/commit/e0650b50245d84dc493a4ea488f09767bdd585c5))
* include tx-type-specific data inside "tx" attribute ([#820](https://www.github.com/aeternity/ae_mdw/issues/820)) ([af64624](https://www.github.com/aeternity/ae_mdw/commit/af64624dbd1c33107417b7a0f5b032b989255505))
* send duplicated tx websocekt message if sources differ ([#813](https://www.github.com/aeternity/ae_mdw/issues/813)) ([d99bd16](https://www.github.com/aeternity/ae_mdw/commit/d99bd1654c9d06bd06974432ae93f399113cf18e))
* update stats caching condition to only do it once per kb ([#814](https://www.github.com/aeternity/ae_mdw/issues/814)) ([e7626d7](https://www.github.com/aeternity/ae_mdw/commit/e7626d7bc6957f9421272fd0cfab3a9c8234560f))


### Miscellaneous

* add typing and credo fixes to ets module ([#815](https://www.github.com/aeternity/ae_mdw/issues/815)) ([c397067](https://www.github.com/aeternity/ae_mdw/commit/c3970678ecdc0a45b1e4fcc78961a022f33cec22))

## [1.16.0](https://www.github.com/aeternity/ae_mdw/compare/v1.15.0...v1.16.0) (2022-08-01)


### Features

* imports hardforks preset accounts ([#805](https://www.github.com/aeternity/ae_mdw/issues/805)) ([2806136](https://www.github.com/aeternity/ae_mdw/commit/2806136835427359f7c99f7b9b70f0de7df8ca77))


### Bug Fixes

* broadcast in-memory blocks ([#809](https://www.github.com/aeternity/ae_mdw/issues/809)) ([22bfcf6](https://www.github.com/aeternity/ae_mdw/commit/22bfcf6c29802f7202d7cefebdd782bd8f7a71c3))


### Miscellaneous

* remove unused supervisor ([#811](https://www.github.com/aeternity/ae_mdw/issues/811)) ([bfa532a](https://www.github.com/aeternity/ae_mdw/commit/bfa532ab7e9d2d89377c8402785b5016cbb8b7fc))
* remove unusued Sync.Server gens_per_min field ([#812](https://www.github.com/aeternity/ae_mdw/issues/812)) ([3078c36](https://www.github.com/aeternity/ae_mdw/commit/3078c367dbd43c228ca41da172470e0a26175c2d))

## [1.15.0](https://www.github.com/aeternity/ae_mdw/compare/v1.14.0...v1.15.0) (2022-07-27)


### Features

* add new store kind to serve async tasks ([#793](https://www.github.com/aeternity/ae_mdw/issues/793)) ([dde85c0](https://www.github.com/aeternity/ae_mdw/commit/dde85c060719fb02a7d76a8a4c9e4c5d235b0153))
* add new type count index for /txs/count?type=x ([#800](https://www.github.com/aeternity/ae_mdw/issues/800)) ([9388279](https://www.github.com/aeternity/ae_mdw/commit/93882796b52f9e24c6bccba03e6cc8566d15f8f3))
* allow filtering transactions count by scope ([#798](https://www.github.com/aeternity/ae_mdw/issues/798)) ([cae1dc3](https://www.github.com/aeternity/ae_mdw/commit/cae1dc31cc30a462464f2e376811394bb642349d))
* display tx hash instead of txi when tx_hash=true ([#789](https://www.github.com/aeternity/ae_mdw/issues/789)) ([295da57](https://www.github.com/aeternity/ae_mdw/commit/295da5791195f86a18a873c80dabbd64e41c6765))
* runs dry-run only once per contract and block ([#778](https://www.github.com/aeternity/ae_mdw/issues/778)) ([5690902](https://www.github.com/aeternity/ae_mdw/commit/5690902e21c711f309d662baed60cb821eae75f7))
* sort active names by activation height ([#760](https://www.github.com/aeternity/ae_mdw/issues/760)) ([a57cf3c](https://www.github.com/aeternity/ae_mdw/commit/a57cf3cc5795f87defe8795662b3e8cb8fff5437))
* sync latest gens in-memory for instant invalidation ([#676](https://www.github.com/aeternity/ae_mdw/issues/676)) ([af95379](https://www.github.com/aeternity/ae_mdw/commit/af9537973e9ed34919d19b750734984004b6bf4c))
* sync up to latest micro-block ([#726](https://www.github.com/aeternity/ae_mdw/issues/726)) ([bff7d0f](https://www.github.com/aeternity/ae_mdw/commit/bff7d0f2a7491cd95300ad1648f6ce468173b24c))


### Bug Fixes

* adjust inactive name owner table ([#767](https://www.github.com/aeternity/ae_mdw/issues/767)) ([f9825d6](https://www.github.com/aeternity/ae_mdw/commit/f9825d6b5c641318cc5fc3e1e38df7b76b031bfc))
* avoid dirty reads when using iterator ([#781](https://www.github.com/aeternity/ae_mdw/issues/781)) ([f7b0da0](https://www.github.com/aeternity/ae_mdw/commit/f7b0da075b1556cbbccd30e12ae54680737938e9))
* avoid erasing mem state when State.commit/2 ([#801](https://www.github.com/aeternity/ae_mdw/issues/801)) ([f059238](https://www.github.com/aeternity/ae_mdw/commit/f059238e70a65cfa08ad3a00e39e3341e31d84d3))
* avoid returning results from other tables on AsyncStore.next/prev ([#806](https://www.github.com/aeternity/ae_mdw/issues/806)) ([048757e](https://www.github.com/aeternity/ae_mdw/commit/048757e6732e641361b5228f0190c3ae8c386f20))
* consider empty generations on mdw height ([#766](https://www.github.com/aeternity/ae_mdw/issues/766)) ([a3d8621](https://www.github.com/aeternity/ae_mdw/commit/a3d8621209b5934265397b87bf5b1a5faef027ca))
* ignore tx_hash when iterating through queries ([#795](https://www.github.com/aeternity/ae_mdw/issues/795)) ([6be2041](https://www.github.com/aeternity/ae_mdw/commit/6be2041d79333cb9926da820dfda11fde4d358fa))
* remove blocks cache displayed on /v2/blocks ([#787](https://www.github.com/aeternity/ae_mdw/issues/787)) ([f1672c4](https://www.github.com/aeternity/ae_mdw/commit/f1672c46b7782df9201156e6538cb708254b831c))
* use single-block transactions to avoid duplicated deletions ([#786](https://www.github.com/aeternity/ae_mdw/issues/786)) ([49cf42f](https://www.github.com/aeternity/ae_mdw/commit/49cf42f023be06eaf5408e9e04781fe2ce5f53a4))


### Refactorings

* extract expand/top params into the PaginationPlug ([#788](https://www.github.com/aeternity/ae_mdw/issues/788)) ([98e1804](https://www.github.com/aeternity/ae_mdw/commit/98e180459cbfcbd2a69a1b9fc17367e9f4f350af))
* move formatting to main render functions ([#775](https://www.github.com/aeternity/ae_mdw/issues/775)) ([2406543](https://www.github.com/aeternity/ae_mdw/commit/24065439972011acd274c4237eafe38f99afb7f1))
* save only the used txi on aex9 presence ([#777](https://www.github.com/aeternity/ae_mdw/issues/777)) ([1c678b5](https://www.github.com/aeternity/ae_mdw/commit/1c678b5d2a6dfd8772f23808b54f61fd6c5dd2a5))


### Testing

* add helper with_state/2 function for declarative tests ([#796](https://www.github.com/aeternity/ae_mdw/issues/796)) ([c57056a](https://www.github.com/aeternity/ae_mdw/commit/c57056a946ce3c40768bdc2c11447a49cabe204e))
* add name sync tests for more scenarios ([#785](https://www.github.com/aeternity/ae_mdw/issues/785)) ([e2f728a](https://www.github.com/aeternity/ae_mdw/commit/e2f728a962ce05910bef74890357953fabd1ffec))
* assert decimal is nil on out_of_gas_error ([#769](https://www.github.com/aeternity/ae_mdw/issues/769)) ([af41a5c](https://www.github.com/aeternity/ae_mdw/commit/af41a5cfdb63981ad3643549375fd18c40835edd))
* fix random non-deterministic test failures ([#802](https://www.github.com/aeternity/ae_mdw/issues/802)) ([d5c52b3](https://www.github.com/aeternity/ae_mdw/commit/d5c52b35305a56a92563eef0016662de213977ea))


### Miscellaneous

* add aex9 validation to v1 hash endpoints ([#779](https://www.github.com/aeternity/ae_mdw/issues/779)) ([62e7c75](https://www.github.com/aeternity/ae_mdw/commit/62e7c7589ecc1b07ca2424ddc4cf9289a09aeb87))
* add aex9 validation to v1 range endpoints ([#784](https://www.github.com/aeternity/ae_mdw/issues/784)) ([c56e9c4](https://www.github.com/aeternity/ae_mdw/commit/c56e9c4c1f8947813878de551a5192d2799c3b75))
* add mistakenly removed async in-mem tasks ([#757](https://www.github.com/aeternity/ae_mdw/issues/757)) ([b607abb](https://www.github.com/aeternity/ae_mdw/commit/b607abbe52fae9ff6ca524e23bf250a672db06ce))
* clear state hash for every key block ([#790](https://www.github.com/aeternity/ae_mdw/issues/790)) ([2a4c3d9](https://www.github.com/aeternity/ae_mdw/commit/2a4c3d9bd0c109135188757d810d303fbf860e86))
* encapsulate all Database calls through State ([#762](https://www.github.com/aeternity/ae_mdw/issues/762)) ([922f7d8](https://www.github.com/aeternity/ae_mdw/commit/922f7d850e66ecd91a82dae09d2cdec4689de18a))
* present aexn tokens using state from the StatePlug ([#759](https://www.github.com/aeternity/ae_mdw/issues/759)) ([68f04f5](https://www.github.com/aeternity/ae_mdw/commit/68f04f57aca41f44cfdf0443aed0e186e0ca95f9))
* raise detailed message when deleting txn missing key ([#792](https://www.github.com/aeternity/ae_mdw/issues/792)) ([e6f0366](https://www.github.com/aeternity/ae_mdw/commit/e6f0366a2326a93be76a99cf408f8d134f1805b7))
* raise exception when transaction commit fails ([#783](https://www.github.com/aeternity/ae_mdw/issues/783)) ([84a5110](https://www.github.com/aeternity/ae_mdw/commit/84a5110320afc26f5990c97f8a545dbc184cf5b0))
* remove migrations and old aex9 tables ([#773](https://www.github.com/aeternity/ae_mdw/issues/773)) ([19114fa](https://www.github.com/aeternity/ae_mdw/commit/19114fa99eaa124ca5af19aadbf2474db8841726))
* remove unused Db.Util functions ([#791](https://www.github.com/aeternity/ae_mdw/issues/791)) ([1b172ae](https://www.github.com/aeternity/ae_mdw/commit/1b172aec9b4014a6fffb93b67677e523fbb1f5fa))
* remove unused ets tables ([#804](https://www.github.com/aeternity/ae_mdw/issues/804)) ([d909dd7](https://www.github.com/aeternity/ae_mdw/commit/d909dd7ae8955d07bfd5035d3a5bb29537e370fd))
* remove unused Invalidate.invalidate/1 function ([#761](https://www.github.com/aeternity/ae_mdw/issues/761)) ([e172833](https://www.github.com/aeternity/ae_mdw/commit/e1728339098f4044fe3f73e7e705a72eb43f7d61))
* rename file to match module name ([#799](https://www.github.com/aeternity/ae_mdw/issues/799)) ([1476e85](https://www.github.com/aeternity/ae_mdw/commit/1476e852a35ad8f57547fb36c5ac78083130cb8c))
* use latest State on NamesExpirationMutation ([#782](https://www.github.com/aeternity/ae_mdw/issues/782)) ([321308c](https://www.github.com/aeternity/ae_mdw/commit/321308cd34c7e802d59ad6e55f198f90533c9781))

## [1.14.0](https://www.github.com/aeternity/ae_mdw/compare/v1.13.1...v1.14.0) (2022-06-29)


### Features

* add nft holder endpoints ([#743](https://www.github.com/aeternity/ae_mdw/issues/743)) ([483b9d5](https://www.github.com/aeternity/ae_mdw/commit/483b9d5bb929de0fb97a9183ec89a7ac6c46aaa6))


### Bug Fixes

* use block/hash param on account balances ([#745](https://www.github.com/aeternity/ae_mdw/issues/745)) ([f62033c](https://www.github.com/aeternity/ae_mdw/commit/f62033c12b3feec1183841be7b12661cabb34501))
* verify if task was concurrently deleted ([#750](https://www.github.com/aeternity/ae_mdw/issues/750)) ([17e7be7](https://www.github.com/aeternity/ae_mdw/commit/17e7be76382c90084a00a8fb004fcf1b3c4476a7))

### [1.13.1](https://www.github.com/aeternity/ae_mdw/compare/v1.13.0...v1.13.1) (2022-06-27)


### Bug Fixes

* dedup aex9 presence ([#737](https://www.github.com/aeternity/ae_mdw/issues/737)) ([25b0e20](https://www.github.com/aeternity/ae_mdw/commit/25b0e20f04ba8d4ab36ff04cc03060ed9af646f6))

## [1.13.0](https://www.github.com/aeternity/ae_mdw/compare/v1.12.0...v1.13.0) (2022-06-23)


### Features

* truncate aexn name and symbol sorting fields ([#724](https://www.github.com/aeternity/ae_mdw/issues/724)) ([5e701bf](https://www.github.com/aeternity/ae_mdw/commit/5e701bf8e30d078ca24236c0613a55d229037b22))


### Bug Fixes

* add swagger files in docker image build ([8b806d8](https://www.github.com/aeternity/ae_mdw/commit/8b806d8ecf80fbebd0c263b2ac27d6236ba955b0))
* truncate aexn cursor ([8a116e8](https://www.github.com/aeternity/ae_mdw/commit/8a116e809ddaf8e4c62524dff90d46ecfeb2cf09))


### Miscellaneous

* add truncate metainfo migration ([#733](https://www.github.com/aeternity/ae_mdw/issues/733)) ([6d233bb](https://www.github.com/aeternity/ae_mdw/commit/6d233bbd8eaf43d6b52bdcc557f5dd03671c0224))

## [1.12.0](https://www.github.com/aeternity/ae_mdw/compare/v1.11.1...v1.12.0) (2022-06-20)


### Features

* include tx_hash when listing AEx9 transfers ([#727](https://www.github.com/aeternity/ae_mdw/issues/727)) ([b1695bb](https://www.github.com/aeternity/ae_mdw/commit/b1695bbed6bbac217203b81fe819dde34a6e6102))

### [1.11.1](https://www.github.com/aeternity/ae_mdw/compare/v1.11.0...v1.11.1) (2022-06-14)


### Bug Fixes

* handle names search endpoint when no prefix ([#720](https://www.github.com/aeternity/ae_mdw/issues/720)) ([d8c131e](https://www.github.com/aeternity/ae_mdw/commit/d8c131e558f6bbf9c7d2382c0b608af202fbb474)), closes [#714](https://www.github.com/aeternity/ae_mdw/issues/714)
* use valid name auction route as specified in docs ([#717](https://www.github.com/aeternity/ae_mdw/issues/717)) ([89138c6](https://www.github.com/aeternity/ae_mdw/commit/89138c63ced3d0d1b2783bb3217ece51222b89b9))


### Miscellaneous

* enable credo and remove unused code ([#716](https://www.github.com/aeternity/ae_mdw/issues/716)) ([f2041ae](https://www.github.com/aeternity/ae_mdw/commit/f2041aefede2b64e4aa5bcea5298fe65f4e571ee))
* reduce gas limit to Node base gas ([#722](https://www.github.com/aeternity/ae_mdw/issues/722)) ([d47b1a5](https://www.github.com/aeternity/ae_mdw/commit/d47b1a566efe27ef93fbe249a40dfbbcd97717af))

## [1.11.0](https://www.github.com/aeternity/ae_mdw/compare/v1.10.1...v1.11.0) (2022-06-10)


### Features

* add endpoints to list aex141/nft contracts ([#704](https://www.github.com/aeternity/ae_mdw/issues/704)) ([6d597dc](https://www.github.com/aeternity/ae_mdw/commit/6d597dcaf874ffcdc93d8174665a8ae06d3e26df))
* save and display aexn extensions ([#710](https://www.github.com/aeternity/ae_mdw/issues/710)) ([bb2ff95](https://www.github.com/aeternity/ae_mdw/commit/bb2ff9546dc51c130b26abea5df0067e360cb521))
* set low gas limit according to Node base gas ([#715](https://www.github.com/aeternity/ae_mdw/issues/715)) ([81beaf0](https://www.github.com/aeternity/ae_mdw/commit/81beaf093a771a0c08635ec60492a6b0ecf141cf))


### Bug Fixes

* display unencoded block hash when not found ([#712](https://www.github.com/aeternity/ae_mdw/issues/712)) ([d718c0a](https://www.github.com/aeternity/ae_mdw/commit/d718c0a71e9287e014cf3e44370920df5366c698))


### Testing

* fix name/stats integration tests ([#711](https://www.github.com/aeternity/ae_mdw/issues/711)) ([9b416e7](https://www.github.com/aeternity/ae_mdw/commit/9b416e76936404db95925b92beb65204d2c71b03))


### Refactorings

* add StatePlug to deal with endpoint responses ([#702](https://www.github.com/aeternity/ae_mdw/issues/702)) ([969d84c](https://www.github.com/aeternity/ae_mdw/commit/969d84c562ce18d054bdbe9bce6d056ff614d0c2))
* generalize aexn create contract mutation ([#699](https://www.github.com/aeternity/ae_mdw/issues/699)) ([57c0070](https://www.github.com/aeternity/ae_mdw/commit/57c00704f5371503e9bd2f31b91575fca492f7df))

### [1.10.1](https://www.github.com/aeternity/ae_mdw/compare/v1.10.0...v1.10.1) (2022-06-01)


### Bug Fixes

* handle update aex9 state on contract create logs ([#698](https://www.github.com/aeternity/ae_mdw/issues/698)) ([c120449](https://www.github.com/aeternity/ae_mdw/commit/c120449a0c86ba77820224c3bdd14eb4ecb6a460))
* retrieve block hash for name ptr_resolve from state ([#700](https://www.github.com/aeternity/ae_mdw/issues/700)) ([9fec9bf](https://www.github.com/aeternity/ae_mdw/commit/9fec9bf5a929480e9fe66a53898f8fc083ccde6e))


### Miscellaneous

* add independent static swagger v1 and v2 files ([#697](https://www.github.com/aeternity/ae_mdw/issues/697)) ([739b80b](https://www.github.com/aeternity/ae_mdw/commit/739b80bbedf8b77910df79b2736d4836b52367b1))

## [1.10.0](https://www.github.com/aeternity/ae_mdw/compare/v1.9.2...v1.10.0) (2022-05-27)


### Features

* update aex9 state with logs ([#692](https://www.github.com/aeternity/ae_mdw/issues/692)) ([9c1253e](https://www.github.com/aeternity/ae_mdw/commit/9c1253ec9dfe416f15f8e0244dbb56cafbd407db))


### Bug Fixes

* include ga_attach_tx when trying to find call origins ([#696](https://www.github.com/aeternity/ae_mdw/issues/696)) ([ea57b49](https://www.github.com/aeternity/ae_mdw/commit/ea57b492a1c8ee3f1e8270123f71fee021516d06)), closes [#693](https://www.github.com/aeternity/ae_mdw/issues/693)


### Refactorings

* invalidate aexn contract ([#678](https://www.github.com/aeternity/ae_mdw/issues/678)) ([8651dd5](https://www.github.com/aeternity/ae_mdw/commit/8651dd5ba2322f51756b045a62189cb7beaed8c0))
* replace aex9 sync cache with non deduped params ([#670](https://www.github.com/aeternity/ae_mdw/issues/670)) ([e678a02](https://www.github.com/aeternity/ae_mdw/commit/e678a02ac44856da5bc6b325726635c4c852c4e1))

### [1.9.2](https://www.github.com/aeternity/ae_mdw/compare/v1.9.1...v1.9.2) (2022-05-23)


### Bug Fixes

* update v1 auction bids structure in Format module ([#690](https://www.github.com/aeternity/ae_mdw/issues/690)) ([8b4304f](https://www.github.com/aeternity/ae_mdw/commit/8b4304f7aec9e0bab3b981a80366290e3222aaf2))
* use correct key format for listing name owner tables ([#688](https://www.github.com/aeternity/ae_mdw/issues/688)) ([5d480bf](https://www.github.com/aeternity/ae_mdw/commit/5d480bf929be91eda35d4eb86082f91f018ab8da))


### Miscellaneous

* revert swagger name operation names ([#691](https://www.github.com/aeternity/ae_mdw/issues/691)) ([803ab00](https://www.github.com/aeternity/ae_mdw/commit/803ab00e89bd5a16be888baa7fdb4603552e9c61)), closes [#179](https://www.github.com/aeternity/ae_mdw/issues/179)

### [1.9.1](https://www.github.com/aeternity/ae_mdw/compare/v1.9.0...v1.9.1) (2022-05-18)


### Bug Fixes

* fetch key hash using aec_chain on update_aex9_presence ([#671](https://www.github.com/aeternity/ae_mdw/issues/671)) ([8f52477](https://www.github.com/aeternity/ae_mdw/commit/8f52477d512d2ae1cfb0562dc6307f21892296a8))
* handle /tx/:hash endpoint when tx doesn't exist ([#686](https://www.github.com/aeternity/ae_mdw/issues/686)) ([040c120](https://www.github.com/aeternity/ae_mdw/commit/040c1202409438cd7b8d4b6bdb26f724ff70e363))
* handle aex9_controller errors with FallbackController ([#685](https://www.github.com/aeternity/ae_mdw/issues/685)) ([f944f04](https://www.github.com/aeternity/ae_mdw/commit/f944f043c15052171e9113ffaae65e26b094cbcf))
* handle prev/next when key_boundary is nil ([#679](https://www.github.com/aeternity/ae_mdw/issues/679)) ([a8fe572](https://www.github.com/aeternity/ae_mdw/commit/a8fe57221309f6e665316b8f058c485bbce43911))
* ignore aex9 balances only when there's a single <<>> balance ([#677](https://www.github.com/aeternity/ae_mdw/issues/677)) ([f55742d](https://www.github.com/aeternity/ae_mdw/commit/f55742d757f893671f932a33486146f4807ccbe9))
* remove aex9 presence for remote calls ([#683](https://www.github.com/aeternity/ae_mdw/issues/683)) ([7d11889](https://www.github.com/aeternity/ae_mdw/commit/7d1188954bfa132b3830fe723b6b43a444016727))
* revert change on prev key iteration ([#681](https://www.github.com/aeternity/ae_mdw/issues/681)) ([5117fad](https://www.github.com/aeternity/ae_mdw/commit/5117fad7cc1207a8d86d109ea17c821a885f6540))


### Refactorings

* dirty reads + add Store abstraction ([#659](https://www.github.com/aeternity/ae_mdw/issues/659)) ([996b686](https://www.github.com/aeternity/ae_mdw/commit/996b686e9fc665d07fbc6491d4ae710ea83406c5))
* generalize aex9 meta info with aexn contract ([#667](https://www.github.com/aeternity/ae_mdw/issues/667)) ([71dc396](https://www.github.com/aeternity/ae_mdw/commit/71dc396862097fe0cf092773bee45529343c8926))
* generalize fetch aexn tokens ([#680](https://www.github.com/aeternity/ae_mdw/issues/680)) ([e7cf6e8](https://www.github.com/aeternity/ae_mdw/commit/e7cf6e8a468b5d9f117449b6d400016859414008))
* move aex9 contract pubkeys to aexn records ([#660](https://www.github.com/aeternity/ae_mdw/issues/660)) ([d392510](https://www.github.com/aeternity/ae_mdw/commit/d3925107994eafdfb23ffa289cf9106b4554c05c))


### Miscellaneous

* add fallback for mismatched presence to balance ([#687](https://www.github.com/aeternity/ae_mdw/issues/687)) ([6b78a88](https://www.github.com/aeternity/ae_mdw/commit/6b78a88316bde45d14df6ea2a49e0a1deac96217))
* replace aex9 migrations by one that creates all aex9 contracts ([#668](https://www.github.com/aeternity/ae_mdw/issues/668)) ([a496d72](https://www.github.com/aeternity/ae_mdw/commit/a496d7211a718d551afedb5152652d1aed82edd8))

## [1.9.0](https://www.github.com/aeternity/ae_mdw/compare/v1.8.1...v1.9.0) (2022-05-04)


### Features

* add Ping operation to websocket ([#664](https://www.github.com/aeternity/ae_mdw/issues/664)) ([2a02db4](https://www.github.com/aeternity/ae_mdw/commit/2a02db4d808409d8964b5565410d4d096ea2c36d)), closes [#638](https://www.github.com/aeternity/ae_mdw/issues/638)
* display mdw gens processed per min on the status page ([#650](https://www.github.com/aeternity/ae_mdw/issues/650)) ([8c9e56f](https://www.github.com/aeternity/ae_mdw/commit/8c9e56f353e6643ff353a79ecbd6ea2a139176de))


### Bug Fixes

* allow contract call to GA contract ([#645](https://www.github.com/aeternity/ae_mdw/issues/645)) ([0934873](https://www.github.com/aeternity/ae_mdw/commit/0934873dea9499abbb0aed942693b59248848e9d))
* docker include priv volume for migrations to be found ([#662](https://www.github.com/aeternity/ae_mdw/issues/662)) ([d8c838b](https://www.github.com/aeternity/ae_mdw/commit/d8c838b7930b09a3a7caa0c8279d39b7ade4bfc2))
* handle requests for blocks that don't exist gracefully ([#646](https://www.github.com/aeternity/ae_mdw/issues/646)) ([eebe129](https://www.github.com/aeternity/ae_mdw/commit/eebe129323b9f8a26a887e71db43272c8537f8bf))
* handle stating server when syncing from scratch ([#647](https://www.github.com/aeternity/ae_mdw/issues/647)) ([54f9d59](https://www.github.com/aeternity/ae_mdw/commit/54f9d596de8825f6b2f70fa7c116826ab5cf0764))
* rearrange aex9 transfer pubkeys for pair transfer ([#649](https://www.github.com/aeternity/ae_mdw/issues/649)) ([809e058](https://www.github.com/aeternity/ae_mdw/commit/809e05883369d5a34d0f2b48280f3f795286c25e))
* write block_index to aex9 balance ([#657](https://www.github.com/aeternity/ae_mdw/issues/657)) ([1ed2811](https://www.github.com/aeternity/ae_mdw/commit/1ed2811e04d0740497b11c6ac5c5b06214c38740))


### Testing

* add aex9 tests iterating throughout all contracts ([#655](https://www.github.com/aeternity/ae_mdw/issues/655)) ([f665330](https://www.github.com/aeternity/ae_mdw/commit/f665330723d552b8d542d894ac085b726535fbbc))
* refactor integration tests to unit tests ([#633](https://www.github.com/aeternity/ae_mdw/issues/633)) ([5947784](https://www.github.com/aeternity/ae_mdw/commit/5947784a4e98bea6143ebcb9ae53dbbe18a15948))


### Refactorings

* restructure AuctionBid table for better indexing ([#652](https://www.github.com/aeternity/ae_mdw/issues/652)) ([4688dd4](https://www.github.com/aeternity/ae_mdw/commit/4688dd4c512b16456ae9ecc2e6ded4042ad2b632))
* use aex9 balance records on account endpoints ([#658](https://www.github.com/aeternity/ae_mdw/issues/658)) ([4854894](https://www.github.com/aeternity/ae_mdw/commit/4854894d0cf2e612e15dbeccb289d12913bd83b2))
* use declarative state for executing mutations ([#621](https://www.github.com/aeternity/ae_mdw/issues/621)) ([02132ff](https://www.github.com/aeternity/ae_mdw/commit/02132ff03146fd22c194138d293e67f03b28dcd9))
* use State for building database streams ([#654](https://www.github.com/aeternity/ae_mdw/issues/654)) ([adc2024](https://www.github.com/aeternity/ae_mdw/commit/adc2024257b2a95fdcc419742d9a90c49daa41a3))


### Miscellaneous

* include priv dir for db migrations ([392b171](https://www.github.com/aeternity/ae_mdw/commit/392b17103ebc987c7287a7259c21569758924f53))
* remove unused node and db stream code ([#656](https://www.github.com/aeternity/ae_mdw/issues/656)) ([5dce45b](https://www.github.com/aeternity/ae_mdw/commit/5dce45b0c484156f8794d46e4859f20b2a5fad1b))

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
