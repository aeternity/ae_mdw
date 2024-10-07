# Changelog

## [1.89.0](https://www.github.com/aeternity/ae_mdw/compare/v1.88.0...v1.89.0) (2024-10-07)


### Features

* add claims count on names/auctions ([#1953](https://www.github.com/aeternity/ae_mdw/issues/1953)) ([1b6cbf2](https://www.github.com/aeternity/ae_mdw/commit/1b6cbf27d7e203b0e248bf7d5eecb42e25ae0439))
* add contracts count stats endpoint ([#1936](https://www.github.com/aeternity/ae_mdw/issues/1936)) ([9458297](https://www.github.com/aeternity/ae_mdw/commit/9458297c2a100ca4e303e55d48b92bff240290c8))


### Bug Fixes

* add empty chain key-blocks validation ([#1956](https://www.github.com/aeternity/ae_mdw/issues/1956)) ([1c82965](https://www.github.com/aeternity/ae_mdw/commit/1c829651f8506510289b04943aeef7633e96fc3d))


### Miscellaneous

* make dev container retain bash and iex history, updated logger ([#1959](https://www.github.com/aeternity/ae_mdw/issues/1959)) ([7527ce9](https://www.github.com/aeternity/ae_mdw/commit/7527ce9be1c8e59be22145a2b79bea703d227998))

## [1.88.0](https://www.github.com/aeternity/ae_mdw/compare/v1.87.0...v1.88.0) (2024-09-23)


### Features

* add minutes per block in stats ([#1947](https://www.github.com/aeternity/ae_mdw/issues/1947)) ([19b2fc3](https://www.github.com/aeternity/ae_mdw/commit/19b2fc3225d7f7e5640873fa8416e384fc520ff5))
* sort aexn transfers by txi_idx ([#1945](https://www.github.com/aeternity/ae_mdw/issues/1945)) ([b32a95c](https://www.github.com/aeternity/ae_mdw/commit/b32a95ca36f385e5277f04ef5edfe83e1c434d22))


### Bug Fixes

* activities cursor for gen streams ([#1944](https://www.github.com/aeternity/ae_mdw/issues/1944)) ([2d6909c](https://www.github.com/aeternity/ae_mdw/commit/2d6909cd6dc604f540cf0c8f851650efb2f319cb))
* contemplate case sensitivity when looking for names ([#1952](https://www.github.com/aeternity/ae_mdw/issues/1952)) ([c713483](https://www.github.com/aeternity/ae_mdw/commit/c713483b3cd23a636e1b362c69c6a764ae57a572))


### Testing

* adjust new aexn transfers format on activities test ([#1949](https://www.github.com/aeternity/ae_mdw/issues/1949)) ([4452cac](https://www.github.com/aeternity/ae_mdw/commit/4452cacd4c9152b4a2aab8361c8f49ee3b804b99))


### Miscellaneous

* add default padding to base64 oracles response/queries ([#1937](https://www.github.com/aeternity/ae_mdw/issues/1937)) ([1783f0d](https://www.github.com/aeternity/ae_mdw/commit/1783f0d541364a620b57061d674de0845fa99fc1))
* remove deprecated 2023 migrations ([#1951](https://www.github.com/aeternity/ae_mdw/issues/1951)) ([dd788b4](https://www.github.com/aeternity/ae_mdw/commit/dd788b43055cc42f5bb514384c608604464c9d17))
* remove v1 unused routes ([#1939](https://www.github.com/aeternity/ae_mdw/issues/1939)) ([8602169](https://www.github.com/aeternity/ae_mdw/commit/8602169aab6a423e8f7c4955fe49fac263e54636))

## [1.87.0](https://www.github.com/aeternity/ae_mdw/compare/v1.86.0...v1.87.0) (2024-09-12)


### Features

* include metadata and owner on aex141 token request ([#1920](https://www.github.com/aeternity/ae_mdw/issues/1920)) ([338ada9](https://www.github.com/aeternity/ae_mdw/commit/338ada921190ada77d1dea4f2eb190092cfe4ede))
* make auctions endpoints use name and hash ([#1923](https://www.github.com/aeternity/ae_mdw/issues/1923)) ([d294fa9](https://www.github.com/aeternity/ae_mdw/commit/d294fa9d31c1b8f7ba0e3dc5bd6dd72c45b34c12))


### Bug Fixes

* aexn transfer activities ([#1940](https://www.github.com/aeternity/ae_mdw/issues/1940)) ([f4f73b3](https://www.github.com/aeternity/ae_mdw/commit/f4f73b355fc9c3d74165d0c3df9528402ec7a25d))
* missing delta stat entry for last key block ([#1927](https://www.github.com/aeternity/ae_mdw/issues/1927)) ([1aba034](https://www.github.com/aeternity/ae_mdw/commit/1aba034eefdef789dbd58179fbfcf51e6193002e))
* move console log config outside of json logs if ([#1922](https://www.github.com/aeternity/ae_mdw/issues/1922)) ([5694232](https://www.github.com/aeternity/ae_mdw/commit/5694232aefc821dc2262c42379bdc848bfa277ab))
* repopulate dex swaps ([#1935](https://www.github.com/aeternity/ae_mdw/issues/1935)) ([f76137e](https://www.github.com/aeternity/ae_mdw/commit/f76137e5a4c3ac900b4e8ac5b1cb427f8c4e95d2))


### Miscellaneous

* publish ARM images to dockerhub ([#1934](https://www.github.com/aeternity/ae_mdw/issues/1934)) ([42ba1b5](https://www.github.com/aeternity/ae_mdw/commit/42ba1b50b4b635c9c2dba6b7911f5042e380245e))


### Testing

* fix randomly failing transfers tests ([#1929](https://www.github.com/aeternity/ae_mdw/issues/1929)) ([fbc084c](https://www.github.com/aeternity/ae_mdw/commit/fbc084c2d4235884192a039523df7a59384dc64f))

## [1.86.0](https://www.github.com/aeternity/ae_mdw/compare/v1.85.0...v1.86.0) (2024-09-02)


### Features

* add support for handling WAE contracts as special AEx9 ones ([#1913](https://www.github.com/aeternity/ae_mdw/issues/1913)) ([7b76954](https://www.github.com/aeternity/ae_mdw/commit/7b769542ca5e5bcf460b0d912d6363c6a23225ab))

## [1.85.0](https://www.github.com/aeternity/ae_mdw/compare/v1.84.0...v1.85.0) (2024-09-02)


### Features

* Add block dificulty stat ([#1911](https://www.github.com/aeternity/ae_mdw/issues/1911)) ([d2c8b00](https://www.github.com/aeternity/ae_mdw/commit/d2c8b00a58e0a28930013078855a26c68bf3cf07))
* add hashrate stats endpoint ([#1918](https://www.github.com/aeternity/ae_mdw/issues/1918)) ([c304bfe](https://www.github.com/aeternity/ae_mdw/commit/c304bfe0e714e0294c8ad2d278d171b1db743e10))


### Bug Fixes

* dex contract swaps ([#1912](https://www.github.com/aeternity/ae_mdw/issues/1912)) ([ca0d83c](https://www.github.com/aeternity/ae_mdw/commit/ca0d83c14c3c8c8a51c16bb1c05b6ec788f04bab))


### Miscellaneous

* add generation of key boundaries ([#1915](https://www.github.com/aeternity/ae_mdw/issues/1915)) ([cfaac71](https://www.github.com/aeternity/ae_mdw/commit/cfaac71bc257e15ca788f24527c6e0de39c9e3a3))
* make lima files not required ([#1924](https://www.github.com/aeternity/ae_mdw/issues/1924)) ([9695796](https://www.github.com/aeternity/ae_mdw/commit/9695796e26645d53b71078bbf26eb4091e7e9392))

## [1.84.0](https://www.github.com/aeternity/ae_mdw/compare/v1.83.0...v1.84.0) (2024-08-26)


### Features

* add beneficiary reward to key block response ([#1905](https://www.github.com/aeternity/ae_mdw/issues/1905)) ([d06934b](https://www.github.com/aeternity/ae_mdw/commit/d06934bee98c97f2cccdb642469e27a86af1a395))
* add block height to aex141 ([#1906](https://www.github.com/aeternity/ae_mdw/issues/1906)) ([11c8475](https://www.github.com/aeternity/ae_mdw/commit/11c84750a40c4933759cf1fccd555609ab0a59cf))
* add node schemas to swagger definitions for mdw ([#1862](https://www.github.com/aeternity/ae_mdw/issues/1862)) ([ffa7238](https://www.github.com/aeternity/ae_mdw/commit/ffa7238137c7dbec8a3608d85aab33e1a6c4dd04))
* handle dex swaps scoping ([#1886](https://www.github.com/aeternity/ae_mdw/issues/1886)) ([6248a65](https://www.github.com/aeternity/ae_mdw/commit/6248a656b39f0d16a824f61ed6a6174b00a01102))


### Bug Fixes

* activities pagination ([#1900](https://www.github.com/aeternity/ae_mdw/issues/1900)) ([9d70528](https://www.github.com/aeternity/ae_mdw/commit/9d705288544be7a65cbe29d276bbebfdcef2aa32))
* inconsistent micro time naming ([#1902](https://www.github.com/aeternity/ae_mdw/issues/1902)) ([d5a259f](https://www.github.com/aeternity/ae_mdw/commit/d5a259fbac7ba9709d44fc78886060fe88e8f91e))
* new stats paths in openapi ([#1904](https://www.github.com/aeternity/ae_mdw/issues/1904)) ([9e5e305](https://www.github.com/aeternity/ae_mdw/commit/9e5e305c0a21b53035c8802a91494a728d9888d4))
* specify right aex9 contract to count aex9 logs ([#1908](https://www.github.com/aeternity/ae_mdw/issues/1908)) ([0e223fe](https://www.github.com/aeternity/ae_mdw/commit/0e223fe3e62c631f5ea639ff1f012510f17f16aa))


### Miscellaneous

* structure oracle response as base64 ([#1889](https://www.github.com/aeternity/ae_mdw/issues/1889)) ([b213694](https://www.github.com/aeternity/ae_mdw/commit/b2136943586965158e55808002265fe8beab14cd))

## [1.83.0](https://www.github.com/aeternity/ae_mdw/compare/v1.82.2...v1.83.0) (2024-08-13)


### Features

* add ability to roll back database on dev env ([#1839](https://www.github.com/aeternity/ae_mdw/issues/1839)) ([56fba66](https://www.github.com/aeternity/ae_mdw/commit/56fba6628b866cd2b3d4b69132e8dd6518862bb0))
* add amount and name to activities info ([#1838](https://www.github.com/aeternity/ae_mdw/issues/1838)) ([fe0975a](https://www.github.com/aeternity/ae_mdw/commit/fe0975a2e8f7889c24065d6310f9ec773135c680))
* add dex action field ([#1885](https://www.github.com/aeternity/ae_mdw/issues/1885)) ([27d1901](https://www.github.com/aeternity/ae_mdw/commit/27d1901bce9c7b5f7f36c4b177b7d0e61e9473bd))
* add openapi missing stats route ([#1863](https://www.github.com/aeternity/ae_mdw/issues/1863)) ([232723b](https://www.github.com/aeternity/ae_mdw/commit/232723b6085a638fb615a9b307eb7a50c3f72220))
* simplify setup for testnet ([#1875](https://www.github.com/aeternity/ae_mdw/issues/1875)) ([07db9c6](https://www.github.com/aeternity/ae_mdw/commit/07db9c6db7e572db1237785a42011d52fe5917ba))
* transfer transactions count summary to v3 ([#1878](https://www.github.com/aeternity/ae_mdw/issues/1878)) ([76a6d33](https://www.github.com/aeternity/ae_mdw/commit/76a6d33ddef83349b32e7ec8acc72f15bdd4e68d))


### Bug Fixes

* handle invalid unix dates in filter ([#1870](https://www.github.com/aeternity/ae_mdw/issues/1870)) ([bb44c54](https://www.github.com/aeternity/ae_mdw/commit/bb44c544ba7fc24111b5b2d09330ba96c99053dc))
* oracles v3 endpoint was returning v2 data ([#1874](https://www.github.com/aeternity/ae_mdw/issues/1874)) ([f44d45a](https://www.github.com/aeternity/ae_mdw/commit/f44d45ab0aaa3cfc42a314ecacdf9d58fabc127b))


### Miscellaneous

* fetch aexn tokens on render only ([#1851](https://www.github.com/aeternity/ae_mdw/issues/1851)) ([761b635](https://www.github.com/aeternity/ae_mdw/commit/761b635fd0dc7989b6954ff7af4aa84bbddc506c))
* redefine node module functions directly and avoid SmartGlobal ([#1876](https://www.github.com/aeternity/ae_mdw/issues/1876)) ([e4daf3f](https://www.github.com/aeternity/ae_mdw/commit/e4daf3f4d0799d63f377efec3dcf88aeb52af04c))
* rename statistics to stats to remain consistent ([#1880](https://www.github.com/aeternity/ae_mdw/issues/1880)) ([6988432](https://www.github.com/aeternity/ae_mdw/commit/69884325b5c7c5dd04c13a20884a925d4749608b))
* sort DEX swaps by creation instead of contract creation ([#1882](https://www.github.com/aeternity/ae_mdw/issues/1882)) ([5bdcf70](https://www.github.com/aeternity/ae_mdw/commit/5bdcf709dd65045dbd3aeae4271b92191846eef2))
* update node version to 1.72 ([#1881](https://www.github.com/aeternity/ae_mdw/issues/1881)) ([e53cee5](https://www.github.com/aeternity/ae_mdw/commit/e53cee5c9317472275ad9568c04bf9b7f4184523))

### [1.82.2](https://www.github.com/aeternity/ae_mdw/compare/v1.82.1...v1.82.2) (2024-07-25)


### Bug Fixes

* filter aex9 balances by amount correctly ([#1867](https://www.github.com/aeternity/ae_mdw/issues/1867)) ([d689d47](https://www.github.com/aeternity/ae_mdw/commit/d689d47b5e7db923b0bbb3c5ef8081053501a7c3))
* take max expiration between extension and prev expiration ([#1871](https://www.github.com/aeternity/ae_mdw/issues/1871)) ([7dd50b8](https://www.github.com/aeternity/ae_mdw/commit/7dd50b8bc44a9defe9236469dbd0ab885dc90061))


### Miscellaneous

* remove overwrite of network_id and use values from aeternity.yaml ([#1848](https://www.github.com/aeternity/ae_mdw/issues/1848)) ([3ee3b28](https://www.github.com/aeternity/ae_mdw/commit/3ee3b289955bc63a3b40f0260612cdaa9aebc2d0))

### [1.82.1](https://www.github.com/aeternity/ae_mdw/compare/v1.82.0...v1.82.1) (2024-07-24)


### Bug Fixes

* calculate auction expiration correctly when extension present ([#1866](https://www.github.com/aeternity/ae_mdw/issues/1866)) ([847dab4](https://www.github.com/aeternity/ae_mdw/commit/847dab41f2860fc8ecd864c81006b9d31b9a95ab))
* rename aex141 token path to conform to the others ([#1864](https://www.github.com/aeternity/ae_mdw/issues/1864)) ([a7de382](https://www.github.com/aeternity/ae_mdw/commit/a7de3825fcdb03b05d80785c75518ec4a8fc7272))

## [1.82.0](https://www.github.com/aeternity/ae_mdw/compare/v1.81.0...v1.82.0) (2024-07-22)


### Features

* make aexn prefix search case insensitive ([#1836](https://www.github.com/aeternity/ae_mdw/issues/1836)) ([982e12a](https://www.github.com/aeternity/ae_mdw/commit/982e12a6135dd8b0ec55681ab70b922f5344cb5c))


### Bug Fixes

* correct url in openapi specs ([#1837](https://www.github.com/aeternity/ae_mdw/issues/1837)) ([bb895ed](https://www.github.com/aeternity/ae_mdw/commit/bb895edba8e739d8fe84e67f229b5630a5dece38))
* dex swaps retrieval ([#1846](https://www.github.com/aeternity/ae_mdw/issues/1846)) ([503ad87](https://www.github.com/aeternity/ae_mdw/commit/503ad877d3f1f1f700e4f37037fda772bccc4fab))
* use same format for pointers as the node ([#1830](https://www.github.com/aeternity/ae_mdw/issues/1830)) ([a15c74c](https://www.github.com/aeternity/ae_mdw/commit/a15c74c977603ad90def980150c3293f5b5c470c))


### Testing

* simplify intermittent name count test ([#1843](https://www.github.com/aeternity/ae_mdw/issues/1843)) ([dbe35de](https://www.github.com/aeternity/ae_mdw/commit/dbe35de66e484150b0f9942e5529daceb2bf70cc))


### Miscellaneous

* add MIX_ENV=prod when building for SDK usage ([#1847](https://www.github.com/aeternity/ae_mdw/issues/1847)) ([6f6f747](https://www.github.com/aeternity/ae_mdw/commit/6f6f7477a0f66dea65c8610708015df4243294f5))

## [1.81.0](https://www.github.com/aeternity/ae_mdw/compare/v1.80.0...v1.81.0) (2024-07-10)


### Features

* add endpoint to get names count ([#1737](https://www.github.com/aeternity/ae_mdw/issues/1737)) ([9cbd5e6](https://www.github.com/aeternity/ae_mdw/commit/9cbd5e6debbb73072121eed5e7b2a094bc1da4bc))
* add v3 for websockets ([#1828](https://www.github.com/aeternity/ae_mdw/issues/1828)) ([219417b](https://www.github.com/aeternity/ae_mdw/commit/219417b6e5ecdc93d8210875c990f84bcb99ff0b))
* additional fields to dex endpoints ([#1835](https://www.github.com/aeternity/ae_mdw/issues/1835)) ([1f6835c](https://www.github.com/aeternity/ae_mdw/commit/1f6835c4782aecf5965d5f1a71ecbf79a56a2671))
* update node to 7.1.0 ([#1826](https://www.github.com/aeternity/ae_mdw/issues/1826)) ([56d2150](https://www.github.com/aeternity/ae_mdw/commit/56d215021fb0b04e5fbe3e672b49624eedf0dda6))


### Bug Fixes

* add missing mutations in profile sync ([#1832](https://www.github.com/aeternity/ae_mdw/issues/1832)) ([e8514fa](https://www.github.com/aeternity/ae_mdw/commit/e8514fafbebfda959803ec70b3347c3bc3217ea8))
* handle parent contract DEX swaps ([#1831](https://www.github.com/aeternity/ae_mdw/issues/1831)) ([c1c3abd](https://www.github.com/aeternity/ae_mdw/commit/c1c3abd9a83753d46129ffe6fea0dba5abd3ff19))


### Miscellaneous

* add MIX_ENV=dev on docker-compose-dev ([#1834](https://www.github.com/aeternity/ae_mdw/issues/1834)) ([b2cbe8c](https://www.github.com/aeternity/ae_mdw/commit/b2cbe8c75a7b0dce9b8f40adb8277cb59431d9a4))

## [1.80.0](https://www.github.com/aeternity/ae_mdw/compare/v1.79.0...v1.80.0) (2024-06-28)


### Features

* add oracle extends endpoint on v3 ([#1824](https://www.github.com/aeternity/ae_mdw/issues/1824)) ([e8c077f](https://www.github.com/aeternity/ae_mdw/commit/e8c077ff3f0918bee14f8b6bc53a49e7706ed0e0))


### Bug Fixes

* ignore nil mutations in sync server ([#1827](https://www.github.com/aeternity/ae_mdw/issues/1827)) ([078356f](https://www.github.com/aeternity/ae_mdw/commit/078356f054507c790f6a7518caef440c42f368af))

## [1.79.0](https://www.github.com/aeternity/ae_mdw/compare/v1.78.1...v1.79.0) (2024-06-25)


### Features

* add flag to disable ipv6 ([#1822](https://www.github.com/aeternity/ae_mdw/issues/1822)) ([a3233ed](https://www.github.com/aeternity/ae_mdw/commit/a3233ed81703626fb23d7bb2227d30ce6bd8ef2b))


### Bug Fixes

* use the correct structure for mutations when syncing ([#1820](https://www.github.com/aeternity/ae_mdw/issues/1820)) ([9ee2181](https://www.github.com/aeternity/ae_mdw/commit/9ee2181d158df9772454256fae28617b4b87bb62))

### [1.78.1](https://www.github.com/aeternity/ae_mdw/compare/v1.78.0...v1.78.1) (2024-06-19)


### Bug Fixes

* remove destructuring of gen_mutations for mem mutations ([#1817](https://www.github.com/aeternity/ae_mdw/issues/1817)) ([a1b84c5](https://www.github.com/aeternity/ae_mdw/commit/a1b84c50b103b6e3a133eb01c19745695ac3a261))

## [1.78.0](https://www.github.com/aeternity/ae_mdw/compare/v1.77.5...v1.78.0) (2024-06-19)


### Features

* add contract calls/logs nested routes ([#1812](https://www.github.com/aeternity/ae_mdw/issues/1812)) ([80d4b58](https://www.github.com/aeternity/ae_mdw/commit/80d4b58ae27fd30803430a28cddecb878fe8ec9e))
* add creation time and block hash to nft ([#1808](https://www.github.com/aeternity/ae_mdw/issues/1808)) ([d359312](https://www.github.com/aeternity/ae_mdw/commit/d359312b111982ae4085ac822b7f473673d77fa1))
* mark aex9 as invalid ([#1799](https://www.github.com/aeternity/ae_mdw/issues/1799)) ([f6e1e5b](https://www.github.com/aeternity/ae_mdw/commit/f6e1e5b5b2631525ae290d2ed6b997449eb8ecb0))
* more explicit dex amount representation ([#1814](https://www.github.com/aeternity/ae_mdw/issues/1814)) ([8e06ba5](https://www.github.com/aeternity/ae_mdw/commit/8e06ba5d4681ce5f88272be6c505ffff0b4d9b5e))


### Bug Fixes

* include opt_txi_idx when rendering transfers cursor too ([#1796](https://www.github.com/aeternity/ae_mdw/issues/1796)) ([0511351](https://www.github.com/aeternity/ae_mdw/commit/05113512958388d560ea52da131ed9f4086efc36))
* retrieve pair from external contract when external log ([#1813](https://www.github.com/aeternity/ae_mdw/issues/1813)) ([2767a18](https://www.github.com/aeternity/ae_mdw/commit/2767a18711f18351274e26dffc5f7c9d72f291d6))


### Testing

* randmly failing tests and warnings ([#1801](https://www.github.com/aeternity/ae_mdw/issues/1801)) ([6e13a42](https://www.github.com/aeternity/ae_mdw/commit/6e13a4201ed7c660a3910c4758d117d54c49a2c6))


### Miscellaneous

* make the wealth rank task work with the database instead of AsyncStore and ets ([#1792](https://www.github.com/aeternity/ae_mdw/issues/1792)) ([42ee54f](https://www.github.com/aeternity/ae_mdw/commit/42ee54f1da4fa374ebc5cdc88e557d0984c2e9f0))
* move aexn tokens rendering to contract modules ([#1807](https://www.github.com/aeternity/ae_mdw/issues/1807)) ([6d676cf](https://www.github.com/aeternity/ae_mdw/commit/6d676cfc995f8b3e5a0105d945190ee3ae791a71))
* restructure DEX endpoints ([#1811](https://www.github.com/aeternity/ae_mdw/issues/1811)) ([6d78af8](https://www.github.com/aeternity/ae_mdw/commit/6d78af88a3c7a536e44ba9357e2338dd001e60d2))
* task for generating migrations ([#1800](https://www.github.com/aeternity/ae_mdw/issues/1800)) ([4d5949e](https://www.github.com/aeternity/ae_mdw/commit/4d5949eb905c52253f86de776539179600ddca88))

### [1.77.5](https://www.github.com/aeternity/ae_mdw/compare/v1.77.4...v1.77.5) (2024-06-05)


### Bug Fixes

* rename 20240528120000_sync_account_balances.ex to 20240528120001_sync_account_balances.ex ([#1797](https://www.github.com/aeternity/ae_mdw/issues/1797)) ([2f330e9](https://www.github.com/aeternity/ae_mdw/commit/2f330e980b2503ea8fb57b048923b08f35e3403a))

### [1.77.4](https://www.github.com/aeternity/ae_mdw/compare/v1.77.3...v1.77.4) (2024-06-05)


### Bug Fixes

* aexn openapi schemas ([#1791](https://www.github.com/aeternity/ae_mdw/issues/1791)) ([acc9ba6](https://www.github.com/aeternity/ae_mdw/commit/acc9ba662ff4b0b0bf429809c6b8c287faf8e51d))
* handle transfers txi_idx ref tuple ([#1794](https://www.github.com/aeternity/ae_mdw/issues/1794)) ([15ce77f](https://www.github.com/aeternity/ae_mdw/commit/15ce77fc87fdac2e20064898ca107799646b1b77))
* reorder the PairCreated arguments for DEX events ([#1790](https://www.github.com/aeternity/ae_mdw/issues/1790)) ([0a40932](https://www.github.com/aeternity/ae_mdw/commit/0a40932e75e22ec1dda4040b1837e6a5079eda83))

### [1.77.3](https://www.github.com/aeternity/ae_mdw/compare/v1.77.2...v1.77.3) (2024-05-29)


### Bug Fixes

* rename migration file so it runs again ([#1788](https://www.github.com/aeternity/ae_mdw/issues/1788)) ([eb95c2f](https://www.github.com/aeternity/ae_mdw/commit/eb95c2f4175778705ed9da70a1d316206f2a2b13))
* update aex141 and names swagger ([#1776](https://www.github.com/aeternity/ae_mdw/issues/1776)) ([0f2d9fc](https://www.github.com/aeternity/ae_mdw/commit/0f2d9fc2729efc2e5909af9ad1b39d738500da14))

### [1.77.2](https://www.github.com/aeternity/ae_mdw/compare/v1.77.1...v1.77.2) (2024-05-27)


### Bug Fixes

* chunk dex_swaps migration and fix pattern match ([#1787](https://www.github.com/aeternity/ae_mdw/issues/1787)) ([66cf9af](https://www.github.com/aeternity/ae_mdw/commit/66cf9af0427b7c93badfce3442fec378dff6aadb))
* rename migrations ([#1785](https://www.github.com/aeternity/ae_mdw/issues/1785)) ([7e84fd4](https://www.github.com/aeternity/ae_mdw/commit/7e84fd41ec07e4a3a537b93b9f38405e85ad677e))

### [1.77.1](https://www.github.com/aeternity/ae_mdw/compare/v1.77.0...v1.77.1) (2024-05-27)


### Bug Fixes

* create migration to sync account balances ([#1779](https://www.github.com/aeternity/ae_mdw/issues/1779)) ([f9d40fd](https://www.github.com/aeternity/ae_mdw/commit/f9d40fd354bae803401de9579d89f12e1e3e54f8))

## [1.77.0](https://www.github.com/aeternity/ae_mdw/compare/v1.76.0...v1.77.0) (2024-05-27)


### Features

* add new name pointees endpoint to v3 ([#1777](https://www.github.com/aeternity/ae_mdw/issues/1777)) ([2d1ef20](https://www.github.com/aeternity/ae_mdw/commit/2d1ef2038e2b33cb8ea6cfe932e3a3c69642eae7))


### Bug Fixes

* create RevTransfer on aex9 minting ([#1781](https://www.github.com/aeternity/ae_mdw/issues/1781)) ([6fc8d0f](https://www.github.com/aeternity/ae_mdw/commit/6fc8d0fb7985ec321be364d812497fd8d20760d6))

## [1.76.0](https://www.github.com/aeternity/ae_mdw/compare/v1.75.0...v1.76.0) (2024-05-21)


### Features

* add aex141 contract transfers to v3 api ([#1770](https://www.github.com/aeternity/ae_mdw/issues/1770)) ([76d52c3](https://www.github.com/aeternity/ae_mdw/commit/76d52c3dd58663ee0dfb096cf5e72aa51dd4c74e))
* add route for dex swaps by contract_id ([#1762](https://www.github.com/aeternity/ae_mdw/issues/1762)) ([e3ce830](https://www.github.com/aeternity/ae_mdw/commit/e3ce8301e54415b5249740547073e19b9e7d1e8d))
* allow filtering names by prefix (case-insenstive) ([#1772](https://www.github.com/aeternity/ae_mdw/issues/1772)) ([bd78e3c](https://www.github.com/aeternity/ae_mdw/commit/bd78e3c51a4987fe86bd0daa1368ec2222444aca))
* dex new swaps table ([#1775](https://www.github.com/aeternity/ae_mdw/issues/1775)) ([f7e2c09](https://www.github.com/aeternity/ae_mdw/commit/f7e2c09d7a91471166f67c915375fa8a8e0f3adb))
* restructure aexn routing for v3 ([#1774](https://www.github.com/aeternity/ae_mdw/issues/1774)) ([011c4b4](https://www.github.com/aeternity/ae_mdw/commit/011c4b4a954d54b38f506bff2c2d49e18aa39e28))


### Bug Fixes

* arm docker incompatibility ([#1773](https://www.github.com/aeternity/ae_mdw/issues/1773)) ([826b877](https://www.github.com/aeternity/ae_mdw/commit/826b877c5ec40b5f119f98a3769ce855b68e3a58))
* handle empty transactions count ([#1766](https://www.github.com/aeternity/ae_mdw/issues/1766)) ([3d55193](https://www.github.com/aeternity/ae_mdw/commit/3d551936212377b4b52b1851ae9b5897c24d56d6))
* make all operationIds in swagger_v3 PascalCase ([#1741](https://www.github.com/aeternity/ae_mdw/issues/1741)) ([3dc584e](https://www.github.com/aeternity/ae_mdw/commit/3dc584e95365b836255994b158c1588ac8f4c976))


### Miscellaneous

* update credo to get rid of warnings ([#1769](https://www.github.com/aeternity/ae_mdw/issues/1769)) ([f00fa29](https://www.github.com/aeternity/ae_mdw/commit/f00fa294c6dff991fce3a248b593e7c9183efc2a))
* update openapi schema ([#1771](https://www.github.com/aeternity/ae_mdw/issues/1771)) ([cb78b3e](https://www.github.com/aeternity/ae_mdw/commit/cb78b3e560e05d4c8eba1aa556c26af98ec6ba3b))

## [1.75.0](https://www.github.com/aeternity/ae_mdw/compare/v1.74.4...v1.75.0) (2024-05-01)


### Features

* add average of transaction fees for last 24 hours with trend ([#1749](https://www.github.com/aeternity/ae_mdw/issues/1749)) ([eac8a60](https://www.github.com/aeternity/ae_mdw/commit/eac8a60dab5b928976bbad9e36c017a0fca3c53f))
* add openapi schema for dex controller ([#1754](https://www.github.com/aeternity/ae_mdw/issues/1754)) ([301f76f](https://www.github.com/aeternity/ae_mdw/commit/301f76ffdb9527c88b0de64cca89ef54f5bad88e))


### Bug Fixes

* extend auctions only if the extension is longer that the timeout ([#1753](https://www.github.com/aeternity/ae_mdw/issues/1753)) ([e08dbf5](https://www.github.com/aeternity/ae_mdw/commit/e08dbf5b3299c5d090d7027170f8cf00785356f1))
* handle not found auction bids ([#1746](https://www.github.com/aeternity/ae_mdw/issues/1746)) ([1d788af](https://www.github.com/aeternity/ae_mdw/commit/1d788afbbbc68f5482a2e0048e9baf4d77527d9e))


### Miscellaneous

* bump otp version ([#1752](https://www.github.com/aeternity/ae_mdw/issues/1752)) ([a2c027e](https://www.github.com/aeternity/ae_mdw/commit/a2c027eb9a43f7e495022c65fe7e59282d22dcac))
* bump version to 7.0.0 ([#1751](https://www.github.com/aeternity/ae_mdw/issues/1751)) ([7f2647a](https://www.github.com/aeternity/ae_mdw/commit/7f2647a8cf845e437dbae6ea20767a643f7695c0))

### [1.74.4](https://www.github.com/aeternity/ae_mdw/compare/v1.74.3...v1.74.4) (2024-04-24)


### Bug Fixes

* add int-as-string on pagination next/prev urls ([#1745](https://www.github.com/aeternity/ae_mdw/issues/1745)) ([635249b](https://www.github.com/aeternity/ae_mdw/commit/635249bcd6de48938873deadc913a8cd0d157a75))
* extend auction properly ([#1743](https://www.github.com/aeternity/ae_mdw/issues/1743)) ([21d942e](https://www.github.com/aeternity/ae_mdw/commit/21d942e69f5a24a1f3570099031f2a283a2d8605))

### [1.74.3](https://www.github.com/aeternity/ae_mdw/compare/v1.74.2...v1.74.3) (2024-04-23)


### Miscellaneous

* update node to 7.0.0-rc1 ([#1738](https://www.github.com/aeternity/ae_mdw/issues/1738)) ([a37a79f](https://www.github.com/aeternity/ae_mdw/commit/a37a79fb6d7fbb411771244728c1376e85ec9529))

### [1.74.2](https://www.github.com/aeternity/ae_mdw/compare/v1.74.1...v1.74.2) (2024-04-23)


### Miscellaneous

* update node to version 6.13 ([#1732](https://www.github.com/aeternity/ae_mdw/issues/1732)) ([0828e4b](https://www.github.com/aeternity/ae_mdw/commit/0828e4b65cf634cb475debf741cdeb6dcc6ac70e))

### [1.74.1](https://www.github.com/aeternity/ae_mdw/compare/v1.74.0...v1.74.1) (2024-04-22)


### Bug Fixes

* add support for paying_for txs on contract calls migration ([#1734](https://www.github.com/aeternity/ae_mdw/issues/1734)) ([881c994](https://www.github.com/aeternity/ae_mdw/commit/881c994827e336c469ee2f4263cf87627f2d9d0c))

## [1.74.0](https://www.github.com/aeternity/ae_mdw/compare/v1.73.0...v1.74.0) (2024-04-18)


### Features

* add reverted calls migration to update fun/args ([#1731](https://www.github.com/aeternity/ae_mdw/issues/1731)) ([d58d752](https://www.github.com/aeternity/ae_mdw/commit/d58d75286151d1060b28ad5613320e1f78ebb525))


### Bug Fixes

* remove hardcoded node log level in favor of aeternity.yaml config ([#1729](https://www.github.com/aeternity/ae_mdw/issues/1729)) ([8b34e16](https://www.github.com/aeternity/ae_mdw/commit/8b34e16f4a05e5c1a2e98e1d4786ac44d28c5c4a))
* store function name for reverted contract calls ([#1728](https://www.github.com/aeternity/ae_mdw/issues/1728)) ([0294ba6](https://www.github.com/aeternity/ae_mdw/commit/0294ba6d73e0f9daf96a27d67b32450c6c0979b2))

## [1.73.0](https://www.github.com/aeternity/ae_mdw/compare/v1.72.1...v1.73.0) (2024-04-15)


### Features

* add raw data pointers support for ceres ([#1708](https://www.github.com/aeternity/ae_mdw/issues/1708)) ([f220f48](https://www.github.com/aeternity/ae_mdw/commit/f220f4805c580172287fe0d32e8be10949a681db))
* include 0 count statistics throughout the network lifespan ([#1724](https://www.github.com/aeternity/ae_mdw/issues/1724)) ([dc7e145](https://www.github.com/aeternity/ae_mdw/commit/dc7e1450f144b45d46ef3c36070cf1d9606cdf43))
* resolve aens name to contract address when calling contract ([#1710](https://www.github.com/aeternity/ae_mdw/issues/1710)) ([65575cb](https://www.github.com/aeternity/ae_mdw/commit/65575cb6b6a224cbd1035cca8a386a2c0cef27bd))


### Bug Fixes

* move transactions count to v3 properly ([#1712](https://www.github.com/aeternity/ae_mdw/issues/1712)) ([df59b68](https://www.github.com/aeternity/ae_mdw/commit/df59b68ae697eb310cce769247d344a1da18b34f))
* update names and oracles to v3 ([#1725](https://www.github.com/aeternity/ae_mdw/issues/1725)) ([8f9af21](https://www.github.com/aeternity/ae_mdw/commit/8f9af21e0f13da86a98fb75e01c51e562e0e775a))
* use tx hash instead of index in v3 api version ([#1727](https://www.github.com/aeternity/ae_mdw/issues/1727)) ([e4e0f00](https://www.github.com/aeternity/ae_mdw/commit/e4e0f000e47bdc1b9b07c91634a58e0aa130e2db))


### Miscellaneous

* remove schemes from swagger v1 file ([#1715](https://www.github.com/aeternity/ae_mdw/issues/1715)) ([587844b](https://www.github.com/aeternity/ae_mdw/commit/587844b66b426980c810f909ae76371823a12381))

### [1.72.1](https://www.github.com/aeternity/ae_mdw/compare/v1.72.0...v1.72.1) (2024-04-02)


### Bug Fixes

* avoid converting to atom on runtime metrics formatter ([#1722](https://www.github.com/aeternity/ae_mdw/issues/1722)) ([1023ae1](https://www.github.com/aeternity/ae_mdw/commit/1023ae1bd4ad7ba69baec77d6d525313437c068b))


### Testing

* change tests using nonexisting column ([#1720](https://www.github.com/aeternity/ae_mdw/issues/1720)) ([7fcc55d](https://www.github.com/aeternity/ae_mdw/commit/7fcc55d0937c67a96a4198e2c34ad666c56c068a))

## [1.72.0](https://www.github.com/aeternity/ae_mdw/compare/v1.71.0...v1.72.0) (2024-03-29)


### Features

* add config to allow logging to console ([#1702](https://www.github.com/aeternity/ae_mdw/issues/1702)) ([d98b960](https://www.github.com/aeternity/ae_mdw/commit/d98b9608a736678084e7e9cd726cc31cbfb9ff10))
* allow none logger level configuration ([#1706](https://www.github.com/aeternity/ae_mdw/issues/1706)) ([84a6837](https://www.github.com/aeternity/ae_mdw/commit/84a683738436040c0a068946ed6f5d9c2e10c92f))
* render name_fee on names/auctions ([#1711](https://www.github.com/aeternity/ae_mdw/issues/1711)) ([21a6b8d](https://www.github.com/aeternity/ae_mdw/commit/21a6b8d0961b859427e324f2d3764a257a7dc92a))


### Bug Fixes

* docker logs mount bad permissions ([#1717](https://www.github.com/aeternity/ae_mdw/issues/1717)) ([af232e4](https://www.github.com/aeternity/ae_mdw/commit/af232e4f74a2997d62b06393299ede33794c4ad5))
* include local-idx cursor when paginating tx call activities ([#1707](https://www.github.com/aeternity/ae_mdw/issues/1707)) ([e0ba8ae](https://www.github.com/aeternity/ae_mdw/commit/e0ba8ae8bf2a5265ffe660345ce22d1a7e94a7b4))
* randomly failing tests ([#1718](https://www.github.com/aeternity/ae_mdw/issues/1718)) ([41e74c1](https://www.github.com/aeternity/ae_mdw/commit/41e74c132bfa105846238110207c5e1271d32d07))
* telemetry error when application starts ([#1716](https://www.github.com/aeternity/ae_mdw/issues/1716)) ([54b54ff](https://www.github.com/aeternity/ae_mdw/commit/54b54ff03f5015a98676e2c6ecfb57e3ba8f7640))
* use right index when querying next Time record on stats ([#1714](https://www.github.com/aeternity/ae_mdw/issues/1714)) ([6aedb5b](https://www.github.com/aeternity/ae_mdw/commit/6aedb5bcfca640bc5674ed26ef61427e2517e463))


### Miscellaneous

* add credo checks on config files too ([#1704](https://www.github.com/aeternity/ae_mdw/issues/1704)) ([b009208](https://www.github.com/aeternity/ae_mdw/commit/b009208b5873fd35f1d5ab05a316c8d48c704a9d))

## [1.71.0](https://www.github.com/aeternity/ae_mdw/compare/v1.70.0...v1.71.0) (2024-03-19)


### Features

* allow getting block-specific AEx9 balances ([#1701](https://www.github.com/aeternity/ae_mdw/issues/1701)) ([db4f45d](https://www.github.com/aeternity/ae_mdw/commit/db4f45d7a1aea46485cfa37a07b50c8447f7b12d))
* allow logger level configuration ([#1700](https://www.github.com/aeternity/ae_mdw/issues/1700)) ([75d945e](https://www.github.com/aeternity/ae_mdw/commit/75d945ecccc10b47b9ed8b910ff07d1826ce0799))


### Bug Fixes

* allow same creation block to be used on by-hash aex9 balances ([#1697](https://www.github.com/aeternity/ae_mdw/issues/1697)) ([797b1ef](https://www.github.com/aeternity/ae_mdw/commit/797b1efc7d45c48a3819d21221de014d22a84231))
* handle invalid hashes error ([#1705](https://www.github.com/aeternity/ae_mdw/issues/1705)) ([fae0967](https://www.github.com/aeternity/ae_mdw/commit/fae0967320b00944f33731980f51e55095e4c08e))
* use endpoint-specific ordering validation ([#1699](https://www.github.com/aeternity/ae_mdw/issues/1699)) ([3a214d9](https://www.github.com/aeternity/ae_mdw/commit/3a214d983d5376f2c383e9a8b1a144f595b0a067))


### Miscellaneous

* add logs message on deprecated routes ([#1696](https://www.github.com/aeternity/ae_mdw/issues/1696)) ([4f80b8b](https://www.github.com/aeternity/ae_mdw/commit/4f80b8b4f0b6aa2ede4867ab34b9530ceb4ffbc2))
* restructure v3 routes and remove tx_index ([#1695](https://www.github.com/aeternity/ae_mdw/issues/1695)) ([bc10039](https://www.github.com/aeternity/ae_mdw/commit/bc10039a22dc3e5a69f76e8b7a398b46a01c20cb))

## [1.70.0](https://www.github.com/aeternity/ae_mdw/compare/v1.69.1...v1.70.0) (2024-03-06)


### Features

* add remaining v3 routes without the ones deprecated ([#1683](https://www.github.com/aeternity/ae_mdw/issues/1683)) ([62065cc](https://www.github.com/aeternity/ae_mdw/commit/62065ccc183c32558fd7c26360aae8a5e4ff3920))
* allow encoding ints as strings via query parameter ([#1694](https://www.github.com/aeternity/ae_mdw/issues/1694)) ([f459a04](https://www.github.com/aeternity/ae_mdw/commit/f459a0414cfcd5285fbaf9aa1e79bfbbee69b73d))


### Bug Fixes

* process HC seed contracts with the correct format ([#1691](https://www.github.com/aeternity/ae_mdw/issues/1691)) ([9f5e850](https://www.github.com/aeternity/ae_mdw/commit/9f5e850706535f07c052e1b7811c88d53dc3a17f))
* return 404 when contract is not found ([#1687](https://www.github.com/aeternity/ae_mdw/issues/1687)) ([4bb632d](https://www.github.com/aeternity/ae_mdw/commit/4bb632d2879896a026d488aa068776204ceb62ff))

### [1.69.1](https://www.github.com/aeternity/ae_mdw/compare/v1.69.0...v1.69.1) (2024-02-26)


### Bug Fixes

* logging revoked name on sped ([#1686](https://www.github.com/aeternity/ae_mdw/issues/1686)) ([302202a](https://www.github.com/aeternity/ae_mdw/commit/302202ab67e9ff7eb062033a8d0173b00d64c40b))

## [1.69.0](https://www.github.com/aeternity/ae_mdw/compare/v1.68.2...v1.69.0) (2024-02-26)


### Features

* add v3 name and auction detail endpoint ([#1677](https://www.github.com/aeternity/ae_mdw/issues/1677)) ([6b145dc](https://www.github.com/aeternity/ae_mdw/commit/6b145dc4b3133b0fc3cd27a65411c48a4a723e9e))
* include 48hs transactions count trend on stats ([#1680](https://www.github.com/aeternity/ae_mdw/issues/1680)) ([1bb6d13](https://www.github.com/aeternity/ae_mdw/commit/1bb6d13e28fa372b614ce62361909de1b59f6dfa))


### Bug Fixes

* restructure aex141 activities meta_info match ([#1681](https://www.github.com/aeternity/ae_mdw/issues/1681)) ([4f55387](https://www.github.com/aeternity/ae_mdw/commit/4f55387c1a7d95378321e7c170cbc149649572ac))
* skip node call on empty db ([#1685](https://www.github.com/aeternity/ae_mdw/issues/1685)) ([02a9eaf](https://www.github.com/aeternity/ae_mdw/commit/02a9eaff736c6091fea08c063df31a240d3f537a))
* sync spend with revoked name ([#1684](https://www.github.com/aeternity/ae_mdw/issues/1684)) ([f9f8c4d](https://www.github.com/aeternity/ae_mdw/commit/f9f8c4df4154dd2a626f2c20e69921d41fa9f4e0))

### [1.68.2](https://www.github.com/aeternity/ae_mdw/compare/v1.68.1...v1.68.2) (2024-02-08)


### Miscellaneous

* migrate dex swap tokens ([#1675](https://www.github.com/aeternity/ae_mdw/issues/1675)) ([3afe25e](https://www.github.com/aeternity/ae_mdw/commit/3afe25ed977b82992b20416d2f9170c430e33242))
* update swagger.json schemes value ([#1679](https://www.github.com/aeternity/ae_mdw/issues/1679)) ([7983ed1](https://www.github.com/aeternity/ae_mdw/commit/7983ed16dbdc3f2b8e9e8ec44b594a593ab1ca01))

### [1.68.1](https://www.github.com/aeternity/ae_mdw/compare/v1.68.0...v1.68.1) (2024-02-02)


### Bug Fixes

* handle heavy endpoint timeout ([#1673](https://www.github.com/aeternity/ae_mdw/issues/1673)) ([91d29a8](https://www.github.com/aeternity/ae_mdw/commit/91d29a8123ad5b8529449a6ac2acf46a92ed29c4))
* ignore 0-gen db for name stats ([#1663](https://www.github.com/aeternity/ae_mdw/issues/1663)) ([4bc5776](https://www.github.com/aeternity/ae_mdw/commit/4bc5776f30519dee863e72d83d3937870fd94874))
* include all auction claims when closing up an auction ([#1674](https://www.github.com/aeternity/ae_mdw/issues/1674)) ([9ac9c87](https://www.github.com/aeternity/ae_mdw/commit/9ac9c873bc76128af40ce61a526175bc3eade7ba))

## [1.68.0](https://www.github.com/aeternity/ae_mdw/compare/v1.67.0...v1.68.0) (2023-12-28)


### Features

* index and fetch dex swap tokens ([#1628](https://www.github.com/aeternity/ae_mdw/issues/1628)) ([006503c](https://www.github.com/aeternity/ae_mdw/commit/006503c8fe10a7281a418f3d53889bdf0295ad50))


### Bug Fixes

* pick starting transaction from 24hs ago for counting ([#1652](https://www.github.com/aeternity/ae_mdw/issues/1652)) ([b7a073d](https://www.github.com/aeternity/ae_mdw/commit/b7a073d564d3f0fa9eec8fb0e92bed3b66b9c86f))


### Miscellaneous

* index name statistics using key blocks ([#1658](https://www.github.com/aeternity/ae_mdw/issues/1658)) ([f21c3e0](https://www.github.com/aeternity/ae_mdw/commit/f21c3e0620edee798d0a3820a0544d219bc71e98))

## [1.67.0](https://www.github.com/aeternity/ae_mdw/compare/v1.66.4...v1.67.0) (2023-12-20)


### Features

* add names approximate time on expire/activation ([#1639](https://www.github.com/aeternity/ae_mdw/issues/1639)) ([a64d2b1](https://www.github.com/aeternity/ae_mdw/commit/a64d2b135059abb931f544755b5984370b9d9e5f))


### Bug Fixes

* always return state on contract logs write ([#1645](https://www.github.com/aeternity/ae_mdw/issues/1645)) ([2875c61](https://www.github.com/aeternity/ae_mdw/commit/2875c617b38e0ca8a1c02342fd040ea6c6e4a0eb))
* check return_type instead of ret_value for errors ([#1648](https://www.github.com/aeternity/ae_mdw/issues/1648)) ([3d26843](https://www.github.com/aeternity/ae_mdw/commit/3d26843a7b28253fc0c6511c074ad94efa10e343))
* handle micro-block cursor properly ([#1646](https://www.github.com/aeternity/ae_mdw/issues/1646)) ([5f3b91d](https://www.github.com/aeternity/ae_mdw/commit/5f3b91d5f2dcfe164fca1d9d58b5476b2b15d9ad))


### Miscellaneous

* add cache manifest building on docker build ([#1640](https://www.github.com/aeternity/ae_mdw/issues/1640)) ([28e0531](https://www.github.com/aeternity/ae_mdw/commit/28e0531ecc4a9569af2262b5be373d28ba669cc0))

### [1.66.4](https://www.github.com/aeternity/ae_mdw/compare/v1.66.3...v1.66.4) (2023-12-13)


### Miscellaneous

* update node version to most recent 6.12.0 ([#1643](https://www.github.com/aeternity/ae_mdw/issues/1643)) ([da8e284](https://www.github.com/aeternity/ae_mdw/commit/da8e2844775bd19b6b3361c7f6f3ef5b2bd98f13))

### [1.66.3](https://www.github.com/aeternity/ae_mdw/compare/v1.66.2...v1.66.3) (2023-11-27)


### Bug Fixes

* use last gen status regardless of transaction index ([#1637](https://www.github.com/aeternity/ae_mdw/issues/1637)) ([07bd70a](https://www.github.com/aeternity/ae_mdw/commit/07bd70a5aa328ca0f8668700dcefab2b2b8bca78))


### Miscellaneous

* generalize json/view rendering ([#1627](https://www.github.com/aeternity/ae_mdw/issues/1627)) ([fdcf633](https://www.github.com/aeternity/ae_mdw/commit/fdcf6334e0b4591c82ae5454fe74e4dccae5be39))

### [1.66.2](https://www.github.com/aeternity/ae_mdw/compare/v1.66.1...v1.66.2) (2023-11-23)


### Bug Fixes

* fetch previous names before rendering them ([#1630](https://www.github.com/aeternity/ae_mdw/issues/1630)) ([65c2678](https://www.github.com/aeternity/ae_mdw/commit/65c2678c42e5bdce72ae2e40d73ff33fe3fc79e5))

### [1.66.1](https://www.github.com/aeternity/ae_mdw/compare/v1.66.0...v1.66.1) (2023-11-12)


### Bug Fixes

* ignore errored contract calls fun_arg_res when syncing ([#1625](https://www.github.com/aeternity/ae_mdw/issues/1625)) ([c3e8814](https://www.github.com/aeternity/ae_mdw/commit/c3e8814343aee96e2a5f8cc314598871c2e925a9))

## [1.66.0](https://www.github.com/aeternity/ae_mdw/compare/v1.65.0...v1.66.0) (2023-11-09)


### Features

* add last 24 hours transactions count ([#1623](https://www.github.com/aeternity/ae_mdw/issues/1623)) ([82a7943](https://www.github.com/aeternity/ae_mdw/commit/82a7943b2d5963aff83111963dc14eb95330980b))
* add name activation statistics ([#1620](https://www.github.com/aeternity/ae_mdw/issues/1620)) ([a1a0af5](https://www.github.com/aeternity/ae_mdw/commit/a1a0af5b9671d6c6e9fe2c335e4153f022907600))
* track dex pair creations ([#1621](https://www.github.com/aeternity/ae_mdw/issues/1621)) ([1156a98](https://www.github.com/aeternity/ae_mdw/commit/1156a9898bec3d26826642b243998bcf568412d4))


### Miscellaneous

* add syncing queue for async syncing requirements ([#1610](https://www.github.com/aeternity/ae_mdw/issues/1610)) ([6d89854](https://www.github.com/aeternity/ae_mdw/commit/6d8985484da387702aed80187b92424cd76379c1))
* filter all aex9 contract account transfers ([#1618](https://www.github.com/aeternity/ae_mdw/issues/1618)) ([6d65207](https://www.github.com/aeternity/ae_mdw/commit/6d65207e951e3c887d50bf411c7bf9332d775d37))
* make names restructuring migration async ([#1617](https://www.github.com/aeternity/ae_mdw/issues/1617)) ([9355e30](https://www.github.com/aeternity/ae_mdw/commit/9355e30a020bc2864aee18cef0c8854b2e394f37))
* unify pagination returns and cursor serialization ([#1619](https://www.github.com/aeternity/ae_mdw/issues/1619)) ([0c17998](https://www.github.com/aeternity/ae_mdw/commit/0c179987c7dbe0a03684f6edacbb92ae3858086d))

## [1.65.0](https://www.github.com/aeternity/ae_mdw/compare/v1.64.0...v1.65.0) (2023-10-12)


### Features

* add statistics date filtering ([#1607](https://www.github.com/aeternity/ae_mdw/issues/1607)) ([455084d](https://www.github.com/aeternity/ae_mdw/commit/455084db9f2467efe2f9a3673062770dfcfea584))


### Bug Fixes

* check contract creation for child contracts ([#1608](https://www.github.com/aeternity/ae_mdw/issues/1608)) ([ee77609](https://www.github.com/aeternity/ae_mdw/commit/ee776091f041a33de8f93f3aee67af20085fe7c4))
* update holders and contract balance on init ([#1606](https://www.github.com/aeternity/ae_mdw/issues/1606)) ([ead1621](https://www.github.com/aeternity/ae_mdw/commit/ead16210b4afaf4af938944da8dcfd4c01cfa635))


### Miscellaneous

* add open auction bids to name history ([#1601](https://www.github.com/aeternity/ae_mdw/issues/1601)) ([d3f0651](https://www.github.com/aeternity/ae_mdw/commit/d3f06519cecc13a0519dc60b1fcc6265af06128b))
* index aex9 mint and burn as transfer ([#1605](https://www.github.com/aeternity/ae_mdw/issues/1605)) ([d5bc9f0](https://www.github.com/aeternity/ae_mdw/commit/d5bc9f0c24f039eb8220a64058896d027d844ab0))
* move previous names into separate table ([#1598](https://www.github.com/aeternity/ae_mdw/issues/1598)) ([f9c0116](https://www.github.com/aeternity/ae_mdw/commit/f9c011613a0906334621e52877f29844a63cddf5))
* offloads app startup by async keys loading ([#1596](https://www.github.com/aeternity/ae_mdw/issues/1596)) ([cb07826](https://www.github.com/aeternity/ae_mdw/commit/cb07826e2f0d7b384fb5c3bd069ae0e0eb99ae75))

## [1.64.0](https://www.github.com/aeternity/ae_mdw/compare/v1.63.0...v1.64.0) (2023-09-18)


### Features

* count microblock txs ([#1594](https://www.github.com/aeternity/ae_mdw/issues/1594)) ([3539e95](https://www.github.com/aeternity/ae_mdw/commit/3539e95b5e8fb03532d991a6231d8a55571ff4de))
* index and query aex9 transfers by contract and account ([#1587](https://www.github.com/aeternity/ae_mdw/issues/1587)) ([0806849](https://www.github.com/aeternity/ae_mdw/commit/0806849eeed61e0277eb756b872edecafd3f6c83))
* sort aexn contracts by creation ([#1583](https://www.github.com/aeternity/ae_mdw/issues/1583)) ([daa4e53](https://www.github.com/aeternity/ae_mdw/commit/daa4e533944f9f5908f233c73a6397950c9a7ddc))


### Bug Fixes

* display only the current auction bids for a name ([#1589](https://www.github.com/aeternity/ae_mdw/issues/1589)) ([1e29e46](https://www.github.com/aeternity/ae_mdw/commit/1e29e46ce6c83b3c247ae8318a31597f24961c26))
* enable 1000 limit on block statistics endpoint ([#1586](https://www.github.com/aeternity/ae_mdw/issues/1586)) ([610ba26](https://www.github.com/aeternity/ae_mdw/commit/610ba261c2653b4555cfbb9fbca7fad2859bb691))


### Miscellaneous

* add aexn_type to contract txs ([#1591](https://www.github.com/aeternity/ae_mdw/issues/1591)) ([6fbf370](https://www.github.com/aeternity/ae_mdw/commit/6fbf3701cf4ba072cbd4f497b48ad56b5d5baddf))
* add functional error responses and tests cases for it ([#1571](https://www.github.com/aeternity/ae_mdw/issues/1571)) ([5a3bd21](https://www.github.com/aeternity/ae_mdw/commit/5a3bd21f1d410833b92014ac7eb915575a44795a))
* ensure suffix on name history ([#1582](https://www.github.com/aeternity/ae_mdw/issues/1582)) ([e2faf61](https://www.github.com/aeternity/ae_mdw/commit/e2faf616f56ec2efdb3062219a2b44acddfcc4fb))
* reverse call logs ([#1585](https://www.github.com/aeternity/ae_mdw/issues/1585)) ([67ea069](https://www.github.com/aeternity/ae_mdw/commit/67ea069e907037facb2bfd4d70247f5071ba24f9))

## [1.63.0](https://www.github.com/aeternity/ae_mdw/compare/v1.62.5...v1.63.0) (2023-09-06)


### Features

* add approximate_auction_end_time to auctions ([#1573](https://www.github.com/aeternity/ae_mdw/issues/1573)) ([dc0aecc](https://www.github.com/aeternity/ae_mdw/commit/dc0aeccf3c5059f94b69489bf445939fd4c602d0))


### Bug Fixes

* render sext encoded log ([#1579](https://www.github.com/aeternity/ae_mdw/issues/1579)) ([798a523](https://www.github.com/aeternity/ae_mdw/commit/798a523014b291b8b9182acf1ef4c3dc89b20813))


### Miscellaneous

* add allowance and approval events ([#1575](https://www.github.com/aeternity/ae_mdw/issues/1575)) ([d44e047](https://www.github.com/aeternity/ae_mdw/commit/d44e047faa2d1bb7c883a12139682eeab27df746))
* enable V3 routes for all envs ([#1578](https://www.github.com/aeternity/ae_mdw/issues/1578)) ([121cd28](https://www.github.com/aeternity/ae_mdw/commit/121cd28e8173578f7ce0b2af4e95ba5c4230e5b3))
* upgrade to node 6.11 ([#1483](https://www.github.com/aeternity/ae_mdw/issues/1483)) ([dc4d90d](https://www.github.com/aeternity/ae_mdw/commit/dc4d90d3cdcefc1eafdb7f222343e4971f36f4cf))

### [1.62.5](https://www.github.com/aeternity/ae_mdw/compare/v1.62.4...v1.62.5) (2023-08-30)


### Bug Fixes

* handle aex141 templates without tokens count ([#1569](https://www.github.com/aeternity/ae_mdw/issues/1569)) ([5b0d867](https://www.github.com/aeternity/ae_mdw/commit/5b0d867ba6919bb877b68cd2fd448dc295961b90))

### [1.62.4](https://www.github.com/aeternity/ae_mdw/compare/v1.62.3...v1.62.4) (2023-08-27)


### Miscellaneous

* add contract_id to create internal calls ([#1567](https://www.github.com/aeternity/ae_mdw/issues/1567)) ([8d783bd](https://www.github.com/aeternity/ae_mdw/commit/8d783bd48d3412c52e80895b121db646b1d5750b))

### [1.62.3](https://www.github.com/aeternity/ae_mdw/compare/v1.62.2...v1.62.3) (2023-08-25)


### Bug Fixes

* match entity using nft collection and token id ([#1565](https://www.github.com/aeternity/ae_mdw/issues/1565)) ([43eed29](https://www.github.com/aeternity/ae_mdw/commit/43eed29808f23aac44f80db52aee77ddffac3432))

### [1.62.2](https://www.github.com/aeternity/ae_mdw/compare/v1.62.1...v1.62.2) (2023-08-25)


### Miscellaneous

* enable nft marketplaces tracking ([#1563](https://www.github.com/aeternity/ae_mdw/issues/1563)) ([e1b27cb](https://www.github.com/aeternity/ae_mdw/commit/e1b27cba055e9e829e0b3cd3e9f511803f0facc3))

### [1.62.1](https://www.github.com/aeternity/ae_mdw/compare/v1.62.0...v1.62.1) (2023-08-25)


### Miscellaneous

* count holders based on events ([#1561](https://www.github.com/aeternity/ae_mdw/issues/1561)) ([4c0d4ee](https://www.github.com/aeternity/ae_mdw/commit/4c0d4ee656dc3d195634d9ed0e20d0959b253bfa))

## [1.62.0](https://www.github.com/aeternity/ae_mdw/compare/v1.61.0...v1.62.0) (2023-08-24)


### Features

* add block statistics endpoint ([#1558](https://www.github.com/aeternity/ae_mdw/issues/1558)) ([3d0c86a](https://www.github.com/aeternity/ae_mdw/commit/3d0c86a94b69a55011f7af64fb4dbca614f62d7b))
* enable async migrations ([#1557](https://www.github.com/aeternity/ae_mdw/issues/1557)) ([7f62111](https://www.github.com/aeternity/ae_mdw/commit/7f62111d3d36b8a6e36cfc1f704f9f6bba02d80c))


### Bug Fixes

* use inner tx type to render contract creation ([#1554](https://www.github.com/aeternity/ae_mdw/issues/1554)) ([5fd3bd3](https://www.github.com/aeternity/ae_mdw/commit/5fd3bd344b38deb04e6c043ad6a5cc308a0d26e4))


### Miscellaneous

* prepare wealth to be updated on block basis ([#1556](https://www.github.com/aeternity/ae_mdw/issues/1556)) ([f3ea4b4](https://www.github.com/aeternity/ae_mdw/commit/f3ea4b4478cb92004db8c9f1813fd484c2d45feb))

## [1.61.0](https://www.github.com/aeternity/ae_mdw/compare/v1.60.0...v1.61.0) (2023-08-23)


### Features

* query active entities (e.g auctions) ([#1551](https://www.github.com/aeternity/ae_mdw/issues/1551)) ([23b1927](https://www.github.com/aeternity/ae_mdw/commit/23b19274c65d6b104a33ffd0c1d545a9259ea293))

## [1.60.0](https://www.github.com/aeternity/ae_mdw/compare/v1.59.1...v1.60.0) (2023-08-22)


### Features

* include aexn meta info on aexn activties ([#1546](https://www.github.com/aeternity/ae_mdw/issues/1546)) ([66a54d8](https://www.github.com/aeternity/ae_mdw/commit/66a54d842798113f78ca55ba3328b9cdcc58d778))


### Bug Fixes

* index entrypoints with proper cursor ([#1543](https://www.github.com/aeternity/ae_mdw/issues/1543)) ([47f9fc5](https://www.github.com/aeternity/ae_mdw/commit/47f9fc5b6ee85e0010e59df978cde8812b755221))
* load aex141 contract for aex141 activities ([#1548](https://www.github.com/aeternity/ae_mdw/issues/1548)) ([4703a08](https://www.github.com/aeternity/ae_mdw/commit/4703a08a671046c13873a6c2149a0ac66972ff85))


### Miscellaneous

* remove dup mgiration since it takes too long for testnet ([#1542](https://www.github.com/aeternity/ae_mdw/issues/1542)) ([7515310](https://www.github.com/aeternity/ae_mdw/commit/75153101a7cb218af1c5767125b9b9b6c955aa59))
* unify convert_params usage into util function ([#1541](https://www.github.com/aeternity/ae_mdw/issues/1541)) ([f6bb850](https://www.github.com/aeternity/ae_mdw/commit/f6bb850621ef8234e2b4f4a56e16a95908dabb17))
* use extracted tx mod and name ([#1545](https://www.github.com/aeternity/ae_mdw/issues/1545)) ([eeb9d55](https://www.github.com/aeternity/ae_mdw/commit/eeb9d55bdfc6d19d4135f9a5c977a47eb9003c2c))

### [1.59.1](https://www.github.com/aeternity/ae_mdw/compare/v1.59.0...v1.59.1) (2023-08-18)


### Miscellaneous

* return bad request for input exceptions ([#1537](https://www.github.com/aeternity/ae_mdw/issues/1537)) ([77909cd](https://www.github.com/aeternity/ae_mdw/commit/77909cd59661c274eb36a07aecea231e697a8ad6))

## [1.59.0](https://www.github.com/aeternity/ae_mdw/compare/v1.58.0...v1.59.0) (2023-08-18)


### Features

* add name history endpoint ([#1527](https://www.github.com/aeternity/ae_mdw/issues/1527)) ([637a744](https://www.github.com/aeternity/ae_mdw/commit/637a744805e9fb8334f2383f91f4726dafbec665))


### Bug Fixes

* expire memory stores based on v1 heavy endpoints ([#1536](https://www.github.com/aeternity/ae_mdw/issues/1536)) ([6d0691b](https://www.github.com/aeternity/ae_mdw/commit/6d0691bab2e81dc042be9fac3aa848142ad01013))
* fix some readme typos ([#1530](https://www.github.com/aeternity/ae_mdw/issues/1530)) ([ad287ec](https://www.github.com/aeternity/ae_mdw/commit/ad287ec35378247667d0c7b3cadd3baad5ba3b11))
* ignore field/transaction counts when they are duplicated in the transaction ([#1535](https://www.github.com/aeternity/ae_mdw/issues/1535)) ([77d387b](https://www.github.com/aeternity/ae_mdw/commit/77d387beadbab4af0c97de74d8393c47048965a4))
* return db state after broadcasting ([#1534](https://www.github.com/aeternity/ae_mdw/issues/1534)) ([e90667a](https://www.github.com/aeternity/ae_mdw/commit/e90667a99c971f776e7cf1e101a572706195a0b8))


### Testing

* isolate async test cases ([#1531](https://www.github.com/aeternity/ae_mdw/issues/1531)) ([34a04d5](https://www.github.com/aeternity/ae_mdw/commit/34a04d5523749d7d58653ebc11eb353c889320d5))


### Miscellaneous

* count object keys only from memory ([#1533](https://www.github.com/aeternity/ae_mdw/issues/1533)) ([aed582b](https://www.github.com/aeternity/ae_mdw/commit/aed582b6592a1dc47085111045049352498bed1e))
* remove old mocked websocket tests ([#1526](https://www.github.com/aeternity/ae_mdw/issues/1526)) ([dd75063](https://www.github.com/aeternity/ae_mdw/commit/dd75063011c86ee46d7d393a0d7dbc5d18c87c56))
* use functional single item pipe ([#1529](https://www.github.com/aeternity/ae_mdw/issues/1529)) ([dad0822](https://www.github.com/aeternity/ae_mdw/commit/dad0822cdeae1b5a67c714c37f6d2e320d4f16b1))

## [1.58.0](https://www.github.com/aeternity/ae_mdw/compare/v1.57.2...v1.58.0) (2023-08-14)


### Features

* add drop tables config ([#1517](https://www.github.com/aeternity/ae_mdw/issues/1517)) ([c7331ec](https://www.github.com/aeternity/ae_mdw/commit/c7331ec8cbc0eeb2b0bee9cb9815f534464d926f))
* add statistics and /statistics/transactions endpoint ([#1496](https://www.github.com/aeternity/ae_mdw/issues/1496)) ([a52e2cb](https://www.github.com/aeternity/ae_mdw/commit/a52e2cb34673601e50bcba8d9cb2825109df3f9b))
* add week/month interval filter on statistics ([#1516](https://www.github.com/aeternity/ae_mdw/issues/1516)) ([a269518](https://www.github.com/aeternity/ae_mdw/commit/a2695187ff2b5602f16c34981a2c1c4c8fd64f38))


### Bug Fixes

* dedup txs activities when present on several fields ([#1521](https://www.github.com/aeternity/ae_mdw/issues/1521)) ([5617a37](https://www.github.com/aeternity/ae_mdw/commit/5617a3759e899efc308e1fa2265b106ba45fee38))
* fix auction bids expiring index ([#1512](https://www.github.com/aeternity/ae_mdw/issues/1512)) ([74cdb9e](https://www.github.com/aeternity/ae_mdw/commit/74cdb9e1691b42d8f6dc0213184d6b42f6c59f80))
* put revoked name key for counting ([#1524](https://www.github.com/aeternity/ae_mdw/issues/1524)) ([dc866bb](https://www.github.com/aeternity/ae_mdw/commit/dc866bbebeb196cb3016afe197f1036cc7aa3c2e))
* use map for DeleteKeysMutation ([#1515](https://www.github.com/aeternity/ae_mdw/issues/1515)) ([a9a0e9e](https://www.github.com/aeternity/ae_mdw/commit/a9a0e9e11545469d6364ce548f405b545fff9653))


### Refactorings

* remove name cache ([#1519](https://www.github.com/aeternity/ae_mdw/issues/1519)) ([1a01b5e](https://www.github.com/aeternity/ae_mdw/commit/1a01b5e7ee7ccb12521abd6b02cde387b005d603))


### Miscellaneous

* add aexn type to contracts response ([#1518](https://www.github.com/aeternity/ae_mdw/issues/1518)) ([c99958b](https://www.github.com/aeternity/ae_mdw/commit/c99958b7840372ff83eecf6a36a28bde300cfaa3))
* add healthcheck on all swagger v2 endoints ([#1525](https://www.github.com/aeternity/ae_mdw/issues/1525)) ([ae9a51f](https://www.github.com/aeternity/ae_mdw/commit/ae9a51fc5cbce9462a060d0528b4f7d4e1986e25))
* count names and oracles from keys ([#1493](https://www.github.com/aeternity/ae_mdw/issues/1493)) ([1c3bd78](https://www.github.com/aeternity/ae_mdw/commit/1c3bd78b85da300697bbdbbf6fc34d419daab444))
* fetch only oracles tree ([#1520](https://www.github.com/aeternity/ae_mdw/issues/1520)) ([d151f25](https://www.github.com/aeternity/ae_mdw/commit/d151f25c50c970ded95e273dcde29373031bfb7d))

### [1.57.2](https://www.github.com/aeternity/ae_mdw/compare/v1.57.1...v1.57.2) (2023-08-07)


### Bug Fixes

* increase timeout of call affected by migration ([#1509](https://www.github.com/aeternity/ae_mdw/issues/1509)) ([f65fa1b](https://www.github.com/aeternity/ae_mdw/commit/f65fa1b9be772333ecb481f6558f698a800b61ab))

### [1.57.1](https://www.github.com/aeternity/ae_mdw/compare/v1.57.0...v1.57.1) (2023-08-07)


### Miscellaneous

* add v2 yaml file back to the static directory ([#1499](https://www.github.com/aeternity/ae_mdw/issues/1499)) ([c2bb9da](https://www.github.com/aeternity/ae_mdw/commit/c2bb9da74662c691e42bfcd180659bb97f6fa24d))
* disable cache for DB block mutations ([#1507](https://www.github.com/aeternity/ae_mdw/issues/1507)) ([2e2413f](https://www.github.com/aeternity/ae_mdw/commit/2e2413f01e861c0e0e091793082c0b6bc7e22d72))
* get block height finding the header ([#1501](https://www.github.com/aeternity/ae_mdw/issues/1501)) ([0251aae](https://www.github.com/aeternity/ae_mdw/commit/0251aae9715f5008418ec0bca47ec76f1267628f))
* use aexn extensions from byte code ([#1508](https://www.github.com/aeternity/ae_mdw/issues/1508)) ([35ff502](https://www.github.com/aeternity/ae_mdw/commit/35ff5024d6c4bc64d0e3130801328fb16bb9c6fa))

## [1.57.0](https://www.github.com/aeternity/ae_mdw/compare/v1.56.0...v1.57.0) (2023-08-03)


### Features

* include last tx hash on delta/total stats ([#1486](https://www.github.com/aeternity/ae_mdw/issues/1486)) ([b1dd02d](https://www.github.com/aeternity/ae_mdw/commit/b1dd02d06b8ebafb42cc651edeb7fde41e4fdc6b))
* index Hyperchains seed contracts ([#1489](https://www.github.com/aeternity/ae_mdw/issues/1489)) ([231b169](https://www.github.com/aeternity/ae_mdw/commit/231b1694e69fc8cab4f1c341fcf9d90712652351))


### Bug Fixes

* filter oracle by state param ([#1491](https://www.github.com/aeternity/ae_mdw/issues/1491)) ([e26a2a7](https://www.github.com/aeternity/ae_mdw/commit/e26a2a7d2357ab38e0161b9ad238cde411c5a7f4))
* handle empty stats ([#1484](https://www.github.com/aeternity/ae_mdw/issues/1484)) ([1a0e211](https://www.github.com/aeternity/ae_mdw/commit/1a0e2119fe9a91f9477c11efc2e14ea902942696))
* restructure pattern-match for decode_call_result ([#1495](https://www.github.com/aeternity/ae_mdw/issues/1495)) ([d2ecbb1](https://www.github.com/aeternity/ae_mdw/commit/d2ecbb17a1bac2d98969b48a34a6b4952d699c35))


### Miscellaneous

* log and reindex aexn ([#1494](https://www.github.com/aeternity/ae_mdw/issues/1494)) ([0440a7f](https://www.github.com/aeternity/ae_mdw/commit/0440a7f02ab4abe29f4d8d5d24c183485ae2af99))
* remove all consistency credo warnings ([#1490](https://www.github.com/aeternity/ae_mdw/issues/1490)) ([b58b278](https://www.github.com/aeternity/ae_mdw/commit/b58b278c6b009acedb8298272ff5ec9aad9f34a7))

## [1.56.0](https://www.github.com/aeternity/ae_mdw/compare/v1.55.1...v1.56.0) (2023-07-28)


### Features

* add auction-only claims v3 endpoint ([#1475](https://www.github.com/aeternity/ae_mdw/issues/1475)) ([5f91ff6](https://www.github.com/aeternity/ae_mdw/commit/5f91ff6daaf6181409f96c5c2d2dac17a31f3e61))
* detect AEX-n meta info ([#1482](https://www.github.com/aeternity/ae_mdw/issues/1482)) ([33579e4](https://www.github.com/aeternity/ae_mdw/commit/33579e427273e9c95a3ed4d9ac7cd46f6d9a7871))
* filter owned nfts by collection ([#1481](https://www.github.com/aeternity/ae_mdw/issues/1481)) ([721fbd2](https://www.github.com/aeternity/ae_mdw/commit/721fbd23d701505f115a53173466fb08e71f3995))
* nft metadata endpoint ([#1478](https://www.github.com/aeternity/ae_mdw/issues/1478)) ([dbe6d0c](https://www.github.com/aeternity/ae_mdw/commit/dbe6d0c2f36abd925452a3f9e58e0acfac7b4657))


### Bug Fixes

* allow using hyphen on name cursors ([#1476](https://www.github.com/aeternity/ae_mdw/issues/1476)) ([c6bcaeb](https://www.github.com/aeternity/ae_mdw/commit/c6bcaebb22a251ab4a5ff19551e55e39b67b8fa6)), closes [#1473](https://www.github.com/aeternity/ae_mdw/issues/1473)
* rename AuctionBidBid to BidClaim ([#1474](https://www.github.com/aeternity/ae_mdw/issues/1474)) ([372c60d](https://www.github.com/aeternity/ae_mdw/commit/372c60d147caf983bc2e819785f171cc2958271d))


### Refactorings

* create map or list directly ([#1469](https://www.github.com/aeternity/ae_mdw/issues/1469)) ([750c266](https://www.github.com/aeternity/ae_mdw/commit/750c266dbbc42879acce03b9a2db0e292b2f9535))


### Miscellaneous

* allow nft owner call for hackaton contracts ([#1472](https://www.github.com/aeternity/ae_mdw/issues/1472)) ([9b6d56f](https://www.github.com/aeternity/ae_mdw/commit/9b6d56f1c42dd37e6351585d7c03227ad2aeb50d))

### [1.55.1](https://www.github.com/aeternity/ae_mdw/compare/v1.55.0...v1.55.1) (2023-07-24)


### Bug Fixes

* add missing fname contract creation call ([#1465](https://www.github.com/aeternity/ae_mdw/issues/1465)) ([af3546f](https://www.github.com/aeternity/ae_mdw/commit/af3546fcb213ed57675f8032af66698b67a536c2))


### Miscellaneous

* **deps:** bump node-fetch from 2.6.1 to 2.6.7 in /node_sdk ([#1466](https://www.github.com/aeternity/ae_mdw/issues/1466)) ([3ff5a6c](https://www.github.com/aeternity/ae_mdw/commit/3ff5a6c62ebc21666fa27ab0a6f5f79df90c3b2f))
* **deps:** bump semver from 6.3.0 to 6.3.1 in /node_sdk ([#1460](https://www.github.com/aeternity/ae_mdw/issues/1460)) ([abcec9e](https://www.github.com/aeternity/ae_mdw/commit/abcec9eb554ff23916f320f994ce564c075955f3))
* move nested name records to individual tables ([#1464](https://www.github.com/aeternity/ae_mdw/issues/1464)) ([72d064b](https://www.github.com/aeternity/ae_mdw/commit/72d064b41544971c0a77b618a6d23a098249ae34))


### Testing

* add devmode test for Chain.clone calls ([#1468](https://www.github.com/aeternity/ae_mdw/issues/1468)) ([57d31ff](https://www.github.com/aeternity/ae_mdw/commit/57d31ff2f7a5f4e41e90f206fb4b9bb8b4c6c2dd))

## [1.55.0](https://www.github.com/aeternity/ae_mdw/compare/v1.54.2...v1.55.0) (2023-07-18)


### Features

* add v3 initial endpoints for names/auctions ([#1459](https://www.github.com/aeternity/ae_mdw/issues/1459)) ([f6e0bb4](https://www.github.com/aeternity/ae_mdw/commit/f6e0bb4d42483b0928c0ba1cc93f0c57996eb1ad))


### Testing

* rewrite some mem tests with store ([#1462](https://www.github.com/aeternity/ae_mdw/issues/1462)) ([7982211](https://www.github.com/aeternity/ae_mdw/commit/79822113ebe0bc4f826643a04f27460c4445025c))

### [1.54.2](https://www.github.com/aeternity/ae_mdw/compare/v1.54.1...v1.54.2) (2023-07-12)


### Bug Fixes

* only bootstrap accounts for configured hardforks ([#1404](https://www.github.com/aeternity/ae_mdw/issues/1404)) ([7b24e15](https://www.github.com/aeternity/ae_mdw/commit/7b24e156dc96be0136c70fb48d673edc6b73e65c))


### Testing

* leave controller tests to coverage ([#1451](https://www.github.com/aeternity/ae_mdw/issues/1451)) ([d2ba17a](https://www.github.com/aeternity/ae_mdw/commit/d2ba17aa6742636845482cc9c91259ffa9a0cf24))


### Miscellaneous

* compact type increment counts mutations into a single one ([#1453](https://www.github.com/aeternity/ae_mdw/issues/1453)) ([1b5f77e](https://www.github.com/aeternity/ae_mdw/commit/1b5f77efbf34c8efb79c7f9f1b370c0876809cd5))
* encode event logs within a single migration ([#1457](https://www.github.com/aeternity/ae_mdw/issues/1457)) ([3f53f9a](https://www.github.com/aeternity/ae_mdw/commit/3f53f9a4b6ed4e3083462c1ac696d90f03aaa922))
* keep cache after switching from db to mem commit ([#1458](https://www.github.com/aeternity/ae_mdw/issues/1458)) ([9e41cd8](https://www.github.com/aeternity/ae_mdw/commit/9e41cd8f01c519e38297f70e03fb292c0ee5322e))
* use builtin term to binary for values ([#1456](https://www.github.com/aeternity/ae_mdw/issues/1456)) ([a257442](https://www.github.com/aeternity/ae_mdw/commit/a257442b72c283276e6bb70b39656b68806737ba))

### [1.54.1](https://www.github.com/aeternity/ae_mdw/compare/v1.54.0...v1.54.1) (2023-07-07)


### Miscellaneous

* log mem and db sync profiling ([#1449](https://www.github.com/aeternity/ae_mdw/issues/1449)) ([bde081d](https://www.github.com/aeternity/ae_mdw/commit/bde081d1d8ee0c324a873003d0ddbe333736c620))

## [1.54.0](https://www.github.com/aeternity/ae_mdw/compare/v1.53.0...v1.54.0) (2023-07-06)


### Features

* add further block times to different endpoints ([#1442](https://www.github.com/aeternity/ae_mdw/issues/1442)) ([0636068](https://www.github.com/aeternity/ae_mdw/commit/06360686d0be79a7f2c81c5311f2281739415efa))

## [1.53.0](https://www.github.com/aeternity/ae_mdw/compare/v1.52.0...v1.53.0) (2023-07-05)


### Features

* add channels last updated time ([#1435](https://www.github.com/aeternity/ae_mdw/issues/1435)) ([d922851](https://www.github.com/aeternity/ae_mdw/commit/d922851ed9430d440d6c4830955ec19a8ae27168))


### Refactorings

* use same get code logic from node ([#1436](https://www.github.com/aeternity/ae_mdw/issues/1436)) ([d7ab68e](https://www.github.com/aeternity/ae_mdw/commit/d7ab68ec39dca2f070c1116a55f7ec13df58d042))


### Testing

* add async: false to all test that mock modules ([#1440](https://www.github.com/aeternity/ae_mdw/issues/1440)) ([6a1fc14](https://www.github.com/aeternity/ae_mdw/commit/6a1fc14b3c1f38f41cfb908b39492b844c8c4d07))


### Miscellaneous

* stream generations mutations ([#1444](https://www.github.com/aeternity/ae_mdw/issues/1444)) ([b46803d](https://www.github.com/aeternity/ae_mdw/commit/b46803d93511aeb76cfae9a5c457b07cf5380ef4))

## [1.52.0](https://www.github.com/aeternity/ae_mdw/compare/v1.51.0...v1.52.0) (2023-06-30)


### Features

* add block_time to all activities ([#1432](https://www.github.com/aeternity/ae_mdw/issues/1432)) ([b769250](https://www.github.com/aeternity/ae_mdw/commit/b769250668f1cabd2b3483cd1d2c6b382a0bd42b))
* add micro block time to oracle nested resources ([#1419](https://www.github.com/aeternity/ae_mdw/issues/1419)) ([de3db7c](https://www.github.com/aeternity/ae_mdw/commit/de3db7cb7bce408b5ed1cf0797dcbc2390613f1d))
* add support for swagger using JSON format ([#1420](https://www.github.com/aeternity/ae_mdw/issues/1420)) ([79618f9](https://www.github.com/aeternity/ae_mdw/commit/79618f90932bd527424bc2f8c748d815d693c1c9))
* cache mem sync mutations ([#1431](https://www.github.com/aeternity/ae_mdw/issues/1431)) ([5a8a36c](https://www.github.com/aeternity/ae_mdw/commit/5a8a36c8cf86b193ca524830eec20d7c3b550fcb))
* display approximate expiration time for auctions ([#1403](https://www.github.com/aeternity/ae_mdw/issues/1403)) ([208f414](https://www.github.com/aeternity/ae_mdw/commit/208f4148db7bd6a662af922b4e5c827cf39c4a9c))
* filter contract calls by entrypoint ([#1413](https://www.github.com/aeternity/ae_mdw/issues/1413)) ([409ed52](https://www.github.com/aeternity/ae_mdw/commit/409ed52a413b1b663f3a91e778cc01a88688eb91))


### Bug Fixes

* create contract call event tx when Chain events ([#1412](https://www.github.com/aeternity/ae_mdw/issues/1412)) ([53c22c3](https://www.github.com/aeternity/ae_mdw/commit/53c22c3a609e0df01288b301c67f4da3b24d585b))


### Testing

* add devmode Contract.create call test ([#1415](https://www.github.com/aeternity/ae_mdw/issues/1415)) ([ba930f6](https://www.github.com/aeternity/ae_mdw/commit/ba930f6b57dbb14cd199e872f3af6da8c71f3261))


### Miscellaneous

* add decimals to account balances ([#1417](https://www.github.com/aeternity/ae_mdw/issues/1417)) ([1c42754](https://www.github.com/aeternity/ae_mdw/commit/1c4275460b0a9902976969691e390220dad539dc))
* add migration for entrypoint ([#1433](https://www.github.com/aeternity/ae_mdw/issues/1433)) ([565dfa3](https://www.github.com/aeternity/ae_mdw/commit/565dfa327f196a9609986e955ca0d427e5db1898))
* add mix files to credo checks ([#1423](https://www.github.com/aeternity/ae_mdw/issues/1423)) ([f0ba7b4](https://www.github.com/aeternity/ae_mdw/commit/f0ba7b49f6874cab8eaa1d81f653fd741ff0500e))
* include credo and leave test for dev shell ([#1406](https://www.github.com/aeternity/ae_mdw/issues/1406)) ([2e41a79](https://www.github.com/aeternity/ae_mdw/commit/2e41a794af47df37c71d7fcf8a9b6c6ee6339c21))
* remove dev docker compose warning ([#1408](https://www.github.com/aeternity/ae_mdw/issues/1408)) ([3245573](https://www.github.com/aeternity/ae_mdw/commit/3245573c646bcc8bbf9bae954876897a830dbc45))
* remove swagger ui ([#1430](https://www.github.com/aeternity/ae_mdw/issues/1430)) ([b4adf6b](https://www.github.com/aeternity/ae_mdw/commit/b4adf6bbe5d5c864a00ada42882ef0463715a0c2))
* return nil for invalid amount of aex9 holders ([#1409](https://www.github.com/aeternity/ae_mdw/issues/1409)) ([03ae588](https://www.github.com/aeternity/ae_mdw/commit/03ae58875edd3277cc777c6aef8daac3f5ae7fd5))
* update aexn parameters to OAS3 ([#1434](https://www.github.com/aeternity/ae_mdw/issues/1434)) ([1da6406](https://www.github.com/aeternity/ae_mdw/commit/1da64069d5e820a3553b7e1078195023419d141c))

## [1.51.0](https://www.github.com/aeternity/ae_mdw/compare/v1.50.1...v1.51.0) (2023-06-19)


### Features

* add approximate_expiration_time to names ([#1399](https://www.github.com/aeternity/ae_mdw/issues/1399)) ([4be56fc](https://www.github.com/aeternity/ae_mdw/commit/4be56fc33a94ff7ac689fb3311714a5bffa03781))


### Bug Fixes

* consider all oracles expirations ([#1397](https://www.github.com/aeternity/ae_mdw/issues/1397)) ([8ed0a7b](https://www.github.com/aeternity/ae_mdw/commit/8ed0a7bd8fb819c7fb135374398d96f3e7300f84))
* include aexn contracts with special chars ([#1402](https://www.github.com/aeternity/ae_mdw/issues/1402)) ([a72fe7b](https://www.github.com/aeternity/ae_mdw/commit/a72fe7beb747699d082c6b894e12e2c8dd89df34))
* run aex9 count migration ([#1405](https://www.github.com/aeternity/ae_mdw/issues/1405)) ([3102d8a](https://www.github.com/aeternity/ae_mdw/commit/3102d8ab268f533a27fc61b2d2a1a47fbf281449))


### Testing

* add async:false to more test modules ([#1401](https://www.github.com/aeternity/ae_mdw/issues/1401)) ([ee7de9b](https://www.github.com/aeternity/ae_mdw/commit/ee7de9bf405907fa40e1fa312234e8abfb0971c2))
* fix intermittent test failures due to async mocking ([#1396](https://www.github.com/aeternity/ae_mdw/issues/1396)) ([6e7f310](https://www.github.com/aeternity/ae_mdw/commit/6e7f3103b5be6ba121dcc98633de143c9eb7e859))
* integrate devmode and SDK for custom test txs ([#1306](https://www.github.com/aeternity/ae_mdw/issues/1306)) ([1b6000a](https://www.github.com/aeternity/ae_mdw/commit/1b6000a9d01283103d466401cabcb77511b34bd0))

### [1.50.1](https://www.github.com/aeternity/ae_mdw/compare/v1.50.0...v1.50.1) (2023-06-13)


### Bug Fixes

* return txs count after cache ([#1394](https://www.github.com/aeternity/ae_mdw/issues/1394)) ([38baa36](https://www.github.com/aeternity/ae_mdw/commit/38baa362f033417c0a9ee7f8fb0be7301c6ffb89))

## [1.50.0](https://www.github.com/aeternity/ae_mdw/compare/v1.49.1...v1.50.0) (2023-06-13)


### Features

* add approximate_expiration_time to oracles ([#1390](https://www.github.com/aeternity/ae_mdw/issues/1390)) ([b008217](https://www.github.com/aeternity/ae_mdw/commit/b0082177f948860245935852303137126de168e8))


### Miscellaneous

* add transactions count to websocket keyblock ([#1382](https://www.github.com/aeternity/ae_mdw/issues/1382)) ([490d379](https://www.github.com/aeternity/ae_mdw/commit/490d379b1869463eda060849ea2f693471f94a84))
* count only aexn contracts with valid meta info ([#1387](https://www.github.com/aeternity/ae_mdw/issues/1387)) ([a7f0f84](https://www.github.com/aeternity/ae_mdw/commit/a7f0f84e252ce7eb1e6dd4d2a4ad19d36f184c0d))

### [1.49.1](https://www.github.com/aeternity/ae_mdw/compare/v1.49.0...v1.49.1) (2023-06-08)


### Bug Fixes

* remove circular rendering on Oracles.render_query/2 ([#1383](https://www.github.com/aeternity/ae_mdw/issues/1383)) ([021e988](https://www.github.com/aeternity/ae_mdw/commit/021e988c5bcd5f80355c2a0ba18a96b1bb05a2b0))


### Miscellaneous

* add function parameter alias to contract logs ([#1374](https://www.github.com/aeternity/ae_mdw/issues/1374)) ([25ece54](https://www.github.com/aeternity/ae_mdw/commit/25ece54adf2f8eb71079512ed51d35a4e5869ddc))


### Testing

* remove mock from contracts sync ([#1379](https://www.github.com/aeternity/ae_mdw/issues/1379)) ([ef46747](https://www.github.com/aeternity/ae_mdw/commit/ef467473f202ebffcb68634ab2bd5195f4a9f1e3))

## [1.49.0](https://www.github.com/aeternity/ae_mdw/compare/v1.48.1...v1.49.0) (2023-05-31)


### Features

* add support for node 6.8.1 back ([#1335](https://www.github.com/aeternity/ae_mdw/issues/1335)) ([4284e63](https://www.github.com/aeternity/ae_mdw/commit/4284e63b9888056bc482b7b2f10f7ef5ebd31f9e))
* add target to ws object msg ([#1341](https://www.github.com/aeternity/ae_mdw/issues/1341)) ([11d53ac](https://www.github.com/aeternity/ae_mdw/commit/11d53ace77fa9fb909924b57ed4dcea1b19f0d2c))
* allow filtering channels by active/inactive ([#1367](https://www.github.com/aeternity/ae_mdw/issues/1367)) ([c303cce](https://www.github.com/aeternity/ae_mdw/commit/c303cce348626bad3884abcc93ec04070bec4871))
* include inactive channels on channels listing ([#1340](https://www.github.com/aeternity/ae_mdw/issues/1340)) ([95bfa1e](https://www.github.com/aeternity/ae_mdw/commit/95bfa1e6c0237879ae07c1a5687b6b6511d905bd))


### Bug Fixes

* adjust printed unit on store_account_balance log ([#1368](https://www.github.com/aeternity/ae_mdw/issues/1368)) ([cc601f1](https://www.github.com/aeternity/ae_mdw/commit/cc601f1874ccaa41553551a909adc8cb11bcd934))


### Miscellaneous

* apply Node persist config ([#1343](https://www.github.com/aeternity/ae_mdw/issues/1343)) ([eb58bf3](https://www.github.com/aeternity/ae_mdw/commit/eb58bf3b62068d781c1dc1ca167487ea19725528))
* track internal calls for wealth ([#1369](https://www.github.com/aeternity/ae_mdw/issues/1369)) ([ca2fff8](https://www.github.com/aeternity/ae_mdw/commit/ca2fff8f1e6cd402a5571eb9f9022d3a60119946))
* use count id by type also on /count ([#1370](https://www.github.com/aeternity/ae_mdw/issues/1370)) ([83eaf77](https://www.github.com/aeternity/ae_mdw/commit/83eaf775e0d8e73ad5f9f1fac15c9b29a89ddad2))

### [1.48.1](https://www.github.com/aeternity/ae_mdw/compare/v1.48.0...v1.48.1) (2023-05-29)


### Bug Fixes

* rename OracleQueries migration to run after ContractLogs ([#1353](https://www.github.com/aeternity/ae_mdw/issues/1353)) ([8feb46f](https://www.github.com/aeternity/ae_mdw/commit/8feb46f7f9914f3258fef01599c582b2cee97b9a))

## [1.48.0](https://www.github.com/aeternity/ae_mdw/compare/v1.47.0...v1.48.0) (2023-05-25)


### Features

* add counters to ws block broadcast ([#1325](https://www.github.com/aeternity/ae_mdw/issues/1325)) ([fcb44a9](https://www.github.com/aeternity/ae_mdw/commit/fcb44a937c4bf5ad8bdf2c19dea79dbf93cac4cd))
* encode custom event args ([#1327](https://www.github.com/aeternity/ae_mdw/issues/1327)) ([775b663](https://www.github.com/aeternity/ae_mdw/commit/775b66314dfa6957f47048bbbd585597bacbf73a))
* filter internal calls by contract and function ([#1330](https://www.github.com/aeternity/ae_mdw/issues/1330)) ([1495ddb](https://www.github.com/aeternity/ae_mdw/commit/1495ddb24742a14323afb387a11239a1ce4d67b4))
* include oracle responses on oracle queries endpoints ([#1314](https://www.github.com/aeternity/ae_mdw/issues/1314)) ([7c6fb6f](https://www.github.com/aeternity/ae_mdw/commit/7c6fb6ffb17c5cbb9dd780020051ac0d4d6e8691))
* index inner contract creations for /contracts endpoint ([#1326](https://www.github.com/aeternity/ae_mdw/issues/1326)) ([3767186](https://www.github.com/aeternity/ae_mdw/commit/3767186f653a763ef85cd219b096ed63d0c256ba))


### Bug Fixes

* handle old oracle responses when migrating int transfers ([#1339](https://www.github.com/aeternity/ae_mdw/issues/1339)) ([f835ef3](https://www.github.com/aeternity/ae_mdw/commit/f835ef3333073f262906a7058ecebf71703b8f5f))
* reindex reward_oracle int transfers ([#1323](https://www.github.com/aeternity/ae_mdw/issues/1323)) ([1b6133c](https://www.github.com/aeternity/ae_mdw/commit/1b6133c8eb995c5b5c52d5d749cb7cbd5c41473c))
* rename OracleResponses migration table ([#1329](https://www.github.com/aeternity/ae_mdw/issues/1329)) ([91ecf94](https://www.github.com/aeternity/ae_mdw/commit/91ecf94055ee1d800993a6d725100642fbead61a))


### Miscellaneous

* increase inactivity timeout ([#1342](https://www.github.com/aeternity/ae_mdw/issues/1342)) ([db0da2c](https://www.github.com/aeternity/ae_mdw/commit/db0da2c2e8ee32af67c45ea270efd137cba016d2))
* let docket volumes be optional ([#1334](https://www.github.com/aeternity/ae_mdw/issues/1334)) ([1fe2817](https://www.github.com/aeternity/ae_mdw/commit/1fe2817116d414bd77d5f20678c049ef59f600f0))
* revert "chore: update node to 6.8.1 ([#1223](https://www.github.com/aeternity/ae_mdw/issues/1223))" ([#1328](https://www.github.com/aeternity/ae_mdw/issues/1328)) ([6fa3873](https://www.github.com/aeternity/ae_mdw/commit/6fa3873f37419b081c4dad6717bb52914afac01d))
* update node to 6.8.1 ([#1223](https://www.github.com/aeternity/ae_mdw/issues/1223)) ([f96f56c](https://www.github.com/aeternity/ae_mdw/commit/f96f56c6405917d9a662e2f2195c745bff3d3646))

## [1.47.0](https://www.github.com/aeternity/ae_mdw/compare/v1.46.7...v1.47.0) (2023-05-15)


### Features

* filter logs by contract and event ([#1317](https://www.github.com/aeternity/ae_mdw/issues/1317)) ([8a70312](https://www.github.com/aeternity/ae_mdw/commit/8a70312aed3d2e311a6fd259d7d4fcadb4cea13f))


### Miscellaneous

* rename update_type_count file to match module ([#1315](https://www.github.com/aeternity/ae_mdw/issues/1315)) ([a5b0bac](https://www.github.com/aeternity/ae_mdw/commit/a5b0bac422b521221c6d6ab798f0c402d0715776))

### [1.46.7](https://www.github.com/aeternity/ae_mdw/compare/v1.46.6...v1.46.7) (2023-05-11)


### Miscellaneous

* check if record exists on delete keys mutation ([#1312](https://www.github.com/aeternity/ae_mdw/issues/1312)) ([1c0ff5e](https://www.github.com/aeternity/ae_mdw/commit/1c0ff5e4cea199cfca4550750eea2cc51769cb7a))

### [1.46.6](https://www.github.com/aeternity/ae_mdw/compare/v1.46.5...v1.46.6) (2023-05-11)


### Miscellaneous

* clear done in memory async tasks ([#1310](https://www.github.com/aeternity/ae_mdw/issues/1310)) ([200be59](https://www.github.com/aeternity/ae_mdw/commit/200be59ce872ab2726f5fff33bb90d12102d21a2))

### [1.46.5](https://www.github.com/aeternity/ae_mdw/compare/v1.46.4...v1.46.5) (2023-05-08)


### Bug Fixes

* update account balance ([#1303](https://www.github.com/aeternity/ae_mdw/issues/1303)) ([dee9a63](https://www.github.com/aeternity/ae_mdw/commit/dee9a632af374d862737b4f7e6fe36dee0dd2002))


### Miscellaneous

* prune wealth migration ([#1305](https://www.github.com/aeternity/ae_mdw/issues/1305)) ([21209ed](https://www.github.com/aeternity/ae_mdw/commit/21209ed72282a9162b94be5bafb252d2b16c55b6))

### [1.46.4](https://www.github.com/aeternity/ae_mdw/compare/v1.46.3...v1.46.4) (2023-05-04)


### Bug Fixes

* delete async task if block is not found ([#1299](https://www.github.com/aeternity/ae_mdw/issues/1299)) ([6b4d3d7](https://www.github.com/aeternity/ae_mdw/commit/6b4d3d7bdd0d7859e9733e63d96105006aa5f301))

### [1.46.3](https://www.github.com/aeternity/ae_mdw/compare/v1.46.2...v1.46.3) (2023-05-03)


### Bug Fixes

* delete inactive name owner deactivation records when activated ([#1296](https://www.github.com/aeternity/ae_mdw/issues/1296)) ([79e4242](https://www.github.com/aeternity/ae_mdw/commit/79e4242b66e8bc3170d8c5438dc62c4ca8684c6e))
* set correct node module for channel withdraw ([#1298](https://www.github.com/aeternity/ae_mdw/issues/1298)) ([592faae](https://www.github.com/aeternity/ae_mdw/commit/592faae7c149bca96b414c3d90401b9e64e1a961))

### [1.46.2](https://www.github.com/aeternity/ae_mdw/compare/v1.46.1...v1.46.2) (2023-05-03)


### Bug Fixes

* set proper migrations path on mix release ([#1289](https://www.github.com/aeternity/ae_mdw/issues/1289)) ([cf6d4fa](https://www.github.com/aeternity/ae_mdw/commit/cf6d4fa221e79e2d141ef48d9deb8f4e530204fa))

### [1.46.1](https://www.github.com/aeternity/ae_mdw/compare/v1.46.0...v1.46.1) (2023-05-02)


### Miscellaneous

* show last applied migration ([#1287](https://www.github.com/aeternity/ae_mdw/issues/1287)) ([0f72b8a](https://www.github.com/aeternity/ae_mdw/commit/0f72b8a2293bc428caca3d9ad5d3bc668085c250))

## [1.46.0](https://www.github.com/aeternity/ae_mdw/compare/v1.45.0...v1.46.0) (2023-05-02)


### Features

* add channels updates nested endpoint ([#1277](https://www.github.com/aeternity/ae_mdw/issues/1277)) ([5230feb](https://www.github.com/aeternity/ae_mdw/commit/5230feb3ba3dd421044fba8c12ada16db2d526d5))
* sort aex9 balance per amount ([#1280](https://www.github.com/aeternity/ae_mdw/issues/1280)) ([2f886e9](https://www.github.com/aeternity/ae_mdw/commit/2f886e9c06cba13cbeba58d0d40e1a231fe59e22))


### Bug Fixes

* consider existing oracles on inactive ones count ([#1274](https://www.github.com/aeternity/ae_mdw/issues/1274)) ([8f51484](https://www.github.com/aeternity/ae_mdw/commit/8f514843e8d5d472602e646b06a03100510d0d64))


### Refactorings

* commit migration instead of direct db write ([#1286](https://www.github.com/aeternity/ae_mdw/issues/1286)) ([5fdc504](https://www.github.com/aeternity/ae_mdw/commit/5fdc504c64e0884c0dacdebdb740ffb1c81065ef))

## [1.45.0](https://www.github.com/aeternity/ae_mdw/compare/v1.44.0...v1.45.0) (2023-04-24)


### Features

* add contracts detail page ([#1269](https://www.github.com/aeternity/ae_mdw/issues/1269)) ([b9f2bb7](https://www.github.com/aeternity/ae_mdw/commit/b9f2bb757774ee295653dd47bd3e9dac20b27cb6))
* wealth endpoint ([#1273](https://www.github.com/aeternity/ae_mdw/issues/1273)) ([7d5164d](https://www.github.com/aeternity/ae_mdw/commit/7d5164db5ff794a50ac7fab9fdb19cf17778f000))


### Bug Fixes

* adapt activities to new int transfers format ([#1270](https://www.github.com/aeternity/ae_mdw/issues/1270)) ([c1b0903](https://www.github.com/aeternity/ae_mdw/commit/c1b0903224b8994dbd3a9a9dc6f8bb63f32a363a))

## [1.44.0](https://www.github.com/aeternity/ae_mdw/compare/v1.43.0...v1.44.0) (2023-04-18)


### Features

* add /contracts endpoint to list contracts ([#1263](https://www.github.com/aeternity/ae_mdw/issues/1263)) ([c07fc64](https://www.github.com/aeternity/ae_mdw/commit/c07fc647857a173d9f9e2c86971494b9dacdcb64))
* track aex9 contract supplies ([#1265](https://www.github.com/aeternity/ae_mdw/issues/1265)) ([789f578](https://www.github.com/aeternity/ae_mdw/commit/789f57853a0af097a3090984baeed87f614ed20c))
* track aex9 logs count ([#1266](https://www.github.com/aeternity/ae_mdw/issues/1266)) ([b5b042e](https://www.github.com/aeternity/ae_mdw/commit/b5b042edf2ede83bdebde633c65e38c79c7847f7))
* track aex9 token holders count per contract ([#1260](https://www.github.com/aeternity/ae_mdw/issues/1260)) ([732b37b](https://www.github.com/aeternity/ae_mdw/commit/732b37b160609d102eaa61eb825b84604a4d530a))


### Bug Fixes

* adjust the order for contract call event mutations ([#1267](https://www.github.com/aeternity/ae_mdw/issues/1267)) ([b4edb22](https://www.github.com/aeternity/ae_mdw/commit/b4edb22694f0ec8b9d9ec3d380893af5af4517d9))


### Miscellaneous

* update aex9 response with holders ([#1262](https://www.github.com/aeternity/ae_mdw/issues/1262)) ([7986309](https://www.github.com/aeternity/ae_mdw/commit/7986309aa5dbf3a0998227cbd5b9c2f853402c6d))

## [1.43.0](https://www.github.com/aeternity/ae_mdw/compare/v1.42.0...v1.43.0) (2023-04-05)


### Features

* add /oracles/:id/responses nested endpoint ([#1253](https://www.github.com/aeternity/ae_mdw/issues/1253)) ([c3244be](https://www.github.com/aeternity/ae_mdw/commit/c3244be59d35b5081916a18b9ddafb5e2e10c3ea))
* aexn contracts count endpoints ([#1258](https://www.github.com/aeternity/ae_mdw/issues/1258)) ([87783e1](https://www.github.com/aeternity/ae_mdw/commit/87783e104dca712ff60f4ddb68bf7d6e0d8d9bf3))
* display int transfers source tx ([#1248](https://www.github.com/aeternity/ae_mdw/issues/1248)) ([89cf780](https://www.github.com/aeternity/ae_mdw/commit/89cf7808539b6bcb81a9e34454ea90f78901aecf))


### Bug Fixes

* add lima contracts amount minted to supply ([#1252](https://www.github.com/aeternity/ae_mdw/issues/1252)) ([738bce2](https://www.github.com/aeternity/ae_mdw/commit/738bce26d48eae178e7a98803bd860ab3bf6d0d5))


### Miscellaneous

* fix credo `refactor` errors ([#1251](https://www.github.com/aeternity/ae_mdw/issues/1251)) ([f37a226](https://www.github.com/aeternity/ae_mdw/commit/f37a2267683114b783e965da6be4616ee361142a))
* remove unused tx sync cache ([#1254](https://www.github.com/aeternity/ae_mdw/issues/1254)) ([ab276df](https://www.github.com/aeternity/ae_mdw/commit/ab276df300d38f6438beb4f62b0fcd7650b01447))
* sum account mintings by network ([#1249](https://www.github.com/aeternity/ae_mdw/issues/1249)) ([9f51f40](https://www.github.com/aeternity/ae_mdw/commit/9f51f406657c73973eabe61ae5564754041aef67))

## [1.42.0](https://www.github.com/aeternity/ae_mdw/compare/v1.41.5...v1.42.0) (2023-03-29)


### Features

* add /oracles/:id/queries to list an oracle queries ([#1240](https://www.github.com/aeternity/ae_mdw/issues/1240)) ([f8f2b7d](https://www.github.com/aeternity/ae_mdw/commit/f8f2b7d6e9c4466f00bec8c93a3b4e0154791093))
* count id txs by type or type group ([#1241](https://www.github.com/aeternity/ae_mdw/issues/1241)) ([dfe86b5](https://www.github.com/aeternity/ae_mdw/commit/dfe86b5a58101a59c0b9501225b5044130d2f5c6))
* filter inner txs fields with ga_meta type ([#1246](https://www.github.com/aeternity/ae_mdw/issues/1246)) ([12b270e](https://www.github.com/aeternity/ae_mdw/commit/12b270ec887f87a4936fe71f759090aac879805f))


### Miscellaneous

* ignore oracle responses that don't have associated query ([#1245](https://www.github.com/aeternity/ae_mdw/issues/1245)) ([2d4db64](https://www.github.com/aeternity/ae_mdw/commit/2d4db6495d7b176d94574e4340991f055fa67af0))
* precompute tx ids ([#1239](https://www.github.com/aeternity/ae_mdw/issues/1239)) ([d29d29e](https://www.github.com/aeternity/ae_mdw/commit/d29d29eecd83ed464510ff0ac8fbd7e2fe1d87cb))

### [1.41.5](https://www.github.com/aeternity/ae_mdw/compare/v1.41.4...v1.41.5) (2023-03-20)


### Bug Fixes

* count total pending async tasks from db ([#1238](https://www.github.com/aeternity/ae_mdw/issues/1238)) ([dfc8998](https://www.github.com/aeternity/ae_mdw/commit/dfc8998ca24554fd0513fb5a283921584ec0cfd3))
* handle return type for failed GAMeta txs as well ([#1237](https://www.github.com/aeternity/ae_mdw/issues/1237)) ([c8ca3a4](https://www.github.com/aeternity/ae_mdw/commit/c8ca3a401dc2bff3f0a329bbda808fecc11e87f8))
* remove name logs ([#1230](https://www.github.com/aeternity/ae_mdw/issues/1230)) ([b0165bb](https://www.github.com/aeternity/ae_mdw/commit/b0165bb15dbed767167acb44159a83a80d796499))


### Miscellaneous

* limit ws subscriptions ([#1234](https://www.github.com/aeternity/ae_mdw/issues/1234)) ([940958a](https://www.github.com/aeternity/ae_mdw/commit/940958a3cac614065563b260ba404d24e360af0b))
* remove LoggerJSON backend from test env ([#1228](https://www.github.com/aeternity/ae_mdw/issues/1228)) ([700d338](https://www.github.com/aeternity/ae_mdw/commit/700d338fb8410c758899d29213794974fa385a41))


### Testing

* add unit tests to Db.Channel module ([#1232](https://www.github.com/aeternity/ae_mdw/issues/1232)) ([3f657de](https://www.github.com/aeternity/ae_mdw/commit/3f657def6bea01ae38ebaf6af0cfcf99ddfe888b))
* add unit tests to tx controller and context ([#1235](https://www.github.com/aeternity/ae_mdw/issues/1235)) ([5bb5b1d](https://www.github.com/aeternity/ae_mdw/commit/5bb5b1d5bcb499ce993afe9cc70dca74b76f9d97))

### [1.41.4](https://www.github.com/aeternity/ae_mdw/compare/v1.41.3...v1.41.4) (2023-03-10)


### Bug Fixes

* add base case for txs from gen ([#1221](https://www.github.com/aeternity/ae_mdw/issues/1221)) ([84994fb](https://www.github.com/aeternity/ae_mdw/commit/84994fb21d33c426343e1f9b49f1f3ce504143c6))
* ignore failed ga_meta_tx sync processing ([#1226](https://www.github.com/aeternity/ae_mdw/issues/1226)) ([ff95030](https://www.github.com/aeternity/ae_mdw/commit/ff950301df441f66d66ebe43a2ef9804a452b77d))
* revert git change to allow dev build ([#1227](https://www.github.com/aeternity/ae_mdw/issues/1227)) ([b7ce3a0](https://www.github.com/aeternity/ae_mdw/commit/b7ce3a059285a7642f81f7e85d03926684fc7779))
* set config to serve endpoints on prod ([#1211](https://www.github.com/aeternity/ae_mdw/issues/1211)) ([880f0d3](https://www.github.com/aeternity/ae_mdw/commit/880f0d3159d3b701c0d21daa56401ab7bd0958f8))
* use 404 on missing single path param ([#1217](https://www.github.com/aeternity/ae_mdw/issues/1217)) ([b5b9da3](https://www.github.com/aeternity/ae_mdw/commit/b5b9da39420c1c680f9162dec834d320089946f8))


### Miscellaneous

* aggregate request metric per route ([#1225](https://www.github.com/aeternity/ae_mdw/issues/1225)) ([2f55ac3](https://www.github.com/aeternity/ae_mdw/commit/2f55ac3f17c9e4069d6074bc88a76d1671548e8b))
* allow mounting db dir with docker ([#1224](https://www.github.com/aeternity/ae_mdw/issues/1224)) ([52ef103](https://www.github.com/aeternity/ae_mdw/commit/52ef103b72e01b29201bd2bc77d38e89896aaf16))
* make web config runtime config ([#1222](https://www.github.com/aeternity/ae_mdw/issues/1222)) ([ff14888](https://www.github.com/aeternity/ae_mdw/commit/ff148888cd4ff676292edbcd280051b17ff40bd4))
* set docker user to aeternity ([#1229](https://www.github.com/aeternity/ae_mdw/issues/1229)) ([a94b1d2](https://www.github.com/aeternity/ae_mdw/commit/a94b1d2acf0df30a16572d301aaf68eaf4d2a5cc))
* update endpoints healthcheck ([#1213](https://www.github.com/aeternity/ae_mdw/issues/1213)) ([ddab030](https://www.github.com/aeternity/ae_mdw/commit/ddab030c05f3372367498843699272e3c851ac33))

### [1.41.3](https://www.github.com/aeternity/ae_mdw/compare/v1.41.2...v1.41.3) (2023-02-28)


### Miscellaneous

* avoid deleting oracle queries for later use of them ([#1207](https://www.github.com/aeternity/ae_mdw/issues/1207)) ([ddf4fd8](https://www.github.com/aeternity/ae_mdw/commit/ddf4fd84a48833f1d4579c47682550191b826fb7))
* remove oracle query response check ([#1203](https://www.github.com/aeternity/ae_mdw/issues/1203)) ([5ae60f1](https://www.github.com/aeternity/ae_mdw/commit/5ae60f15c9955d1bf0355996db62fa75ca040c1a))

### [1.41.2](https://www.github.com/aeternity/ae_mdw/compare/v1.41.1...v1.41.2) (2023-02-28)


### Miscellaneous

* add fallback for contracts endpoints ([#1208](https://www.github.com/aeternity/ae_mdw/issues/1208)) ([744b773](https://www.github.com/aeternity/ae_mdw/commit/744b7734645aba4eea25fe55e697b7da16b58054))

### [1.41.1](https://www.github.com/aeternity/ae_mdw/compare/v1.41.0...v1.41.1) (2023-02-27)


### Bug Fixes

* use top height hash for aex9 account balances ([#1205](https://www.github.com/aeternity/ae_mdw/issues/1205)) ([159c51a](https://www.github.com/aeternity/ae_mdw/commit/159c51a33f62303fb03d3eab693e1d5600421cdf))


### Testing

* add coverage for name auction endpoint ([#1201](https://www.github.com/aeternity/ae_mdw/issues/1201)) ([bc5291f](https://www.github.com/aeternity/ae_mdw/commit/bc5291fa5f0de5214d4217240191639c34b597cf))

## [1.41.0](https://www.github.com/aeternity/ae_mdw/compare/v1.40.0...v1.41.0) (2023-02-23)


### Features

* add template token edition ([#1193](https://www.github.com/aeternity/ae_mdw/issues/1193)) ([6a3743f](https://www.github.com/aeternity/ae_mdw/commit/6a3743f69fc2a167bc7b07c169a5c4427644f247))
* allow filtering activities by type ([#1180](https://www.github.com/aeternity/ae_mdw/issues/1180)) ([ccb5f9c](https://www.github.com/aeternity/ae_mdw/commit/ccb5f9cf2d40902f48c53fcc5db3aec61fce3adf))
* encode args using types for AEX-N events ([#1188](https://www.github.com/aeternity/ae_mdw/issues/1188)) ([c0b99b0](https://www.github.com/aeternity/ae_mdw/commit/c0b99b09dbfcfc9891c47f4bd1416dc1e3137929))


### Bug Fixes

* add address to Burn event ([#1191](https://www.github.com/aeternity/ae_mdw/issues/1191)) ([02e00c6](https://www.github.com/aeternity/ae_mdw/commit/02e00c64c1840f9d4ddf941afec606ff97322d06))
* ignore all nft events with args mismatch ([#1196](https://www.github.com/aeternity/ae_mdw/issues/1196)) ([1be940a](https://www.github.com/aeternity/ae_mdw/commit/1be940a8bc50b4dd17f1c5d3ab55da9f4769be60))
* set proper release node to reopen mnesia ([#1197](https://www.github.com/aeternity/ae_mdw/issues/1197)) ([a133ea4](https://www.github.com/aeternity/ae_mdw/commit/a133ea46a4aa3851f3041a79ff057e193900b1ac))


### Miscellaneous

* cleanup field parser module ([#1195](https://www.github.com/aeternity/ae_mdw/issues/1195)) ([2f25139](https://www.github.com/aeternity/ae_mdw/commit/2f25139749dbec40feb36e8e4cab0452932a5608))
* remove console info log for dev environment ([#1194](https://www.github.com/aeternity/ae_mdw/issues/1194)) ([f37ef38](https://www.github.com/aeternity/ae_mdw/commit/f37ef38c5a211414305d23441d5c7dd8d88c7f9a))
* remove no longer needed oracle queries nonce fix ([#1133](https://www.github.com/aeternity/ae_mdw/issues/1133)) ([c3a0e30](https://www.github.com/aeternity/ae_mdw/commit/c3a0e30fde8608216259f5ee6a8aeb9812daa74d))
* skip dev and miners rewards for HC ([#1198](https://www.github.com/aeternity/ae_mdw/issues/1198)) ([32e0836](https://www.github.com/aeternity/ae_mdw/commit/32e083623f82e62420bb45c4d40766c62def436b))
* use mix releases for prod docker images ([#1190](https://www.github.com/aeternity/ae_mdw/issues/1190)) ([fc7356d](https://www.github.com/aeternity/ae_mdw/commit/fc7356d265ce2c75f715fdf316d102d164702dbd))


### CI / CD

* publish images with prod ([#1200](https://www.github.com/aeternity/ae_mdw/issues/1200)) ([44a6b1a](https://www.github.com/aeternity/ae_mdw/commit/44a6b1a4d0edcb6b91dc0671e4bfa61ee11eb242))

## [1.40.0](https://www.github.com/aeternity/ae_mdw/compare/v1.39.1...v1.40.0) (2023-02-10)


### Features

* specialize ws subscription by source ([#1179](https://www.github.com/aeternity/ae_mdw/issues/1179)) ([6631dee](https://www.github.com/aeternity/ae_mdw/commit/6631dee6a7449240e8c3b59f3aabedd68719e26a))


### Bug Fixes

* encode txs 404 address properly ([#1172](https://www.github.com/aeternity/ae_mdw/issues/1172)) ([d1f9e42](https://www.github.com/aeternity/ae_mdw/commit/d1f9e42d1abd541962ba6a572cae189794bb9c9a))


### Testing

* add activities integration tests for the new activity types ([#1175](https://www.github.com/aeternity/ae_mdw/issues/1175)) ([e496e53](https://www.github.com/aeternity/ae_mdw/commit/e496e539e899dc03cbcd201dc5aa8c930afd40fe))


### Miscellaneous

* add handling for previous update format ([#1178](https://www.github.com/aeternity/ae_mdw/issues/1178)) ([2faf521](https://www.github.com/aeternity/ae_mdw/commit/2faf5214b7597e00207b101ddaf2c199d64c152f))
* let aeternity.yaml be used by default ([#1177](https://www.github.com/aeternity/ae_mdw/issues/1177)) ([2abc1db](https://www.github.com/aeternity/ae_mdw/commit/2abc1db634e9f1c101e9f1ebb5166f5891878d5a))

### [1.39.1](https://www.github.com/aeternity/ae_mdw/compare/v1.39.0...v1.39.1) (2023-02-07)


### Bug Fixes

* handle other call not found cases ([#1173](https://www.github.com/aeternity/ae_mdw/issues/1173)) ([6cb9d19](https://www.github.com/aeternity/ae_mdw/commit/6cb9d19d5c91d0a397348becad03b24ba43d775d))

## [1.39.0](https://www.github.com/aeternity/ae_mdw/compare/v1.38.0...v1.39.0) (2023-02-07)


### Features

* add optional json logger ([#1161](https://www.github.com/aeternity/ae_mdw/issues/1161)) ([d0e9965](https://www.github.com/aeternity/ae_mdw/commit/d0e996555fca2823c41bfc1c3363a6cfc71b36e5))
* allow filtering by prefix and scoping contract calls ([#1153](https://www.github.com/aeternity/ae_mdw/issues/1153)) ([de95c3e](https://www.github.com/aeternity/ae_mdw/commit/de95c3ed834cdd46405129c34a88711d2968bb0e))


### Bug Fixes

* allow retrieving the latest txs by hash ([#1167](https://www.github.com/aeternity/ae_mdw/issues/1167)) ([6040929](https://www.github.com/aeternity/ae_mdw/commit/60409295058740aa2001e8fc395b8fb1728dd6b1))
* encode blocks on the /v2/blocks endpoint using formatter ([#1169](https://www.github.com/aeternity/ae_mdw/issues/1169)) ([63e7afd](https://www.github.com/aeternity/ae_mdw/commit/63e7afd5867d9a91516e18ae5c8cfeb14f5ed70a))
* handle call not found ([#1171](https://www.github.com/aeternity/ae_mdw/issues/1171)) ([c5ec27f](https://www.github.com/aeternity/ae_mdw/commit/c5ec27f0be282e74bebfef96d1356c44f1631ac5))
* set hostname as default telemetry host ([#1158](https://www.github.com/aeternity/ae_mdw/issues/1158)) ([61f571c](https://www.github.com/aeternity/ae_mdw/commit/61f571c5b087e5733fd3dcb8a5faeb3bb2b84ac6))
* use path to decide websocket version ([#1164](https://www.github.com/aeternity/ae_mdw/issues/1164)) ([8941457](https://www.github.com/aeternity/ae_mdw/commit/8941457adc6793a61adb43a0ed36e7bcfac2f6ae))


### Testing

* update websocket integration tests ([#1159](https://www.github.com/aeternity/ae_mdw/issues/1159)) ([c373db6](https://www.github.com/aeternity/ae_mdw/commit/c373db6bc4cdd5cb3658d1e043723b880f6a5ba0))


### Refactorings

* fetch txs subscribers once ([#1166](https://www.github.com/aeternity/ae_mdw/issues/1166)) ([d80f7b5](https://www.github.com/aeternity/ae_mdw/commit/d80f7b55ad764b4d08f7dd66b6e39fb8ea072aaa))
* removed unused block cache ([#1168](https://www.github.com/aeternity/ae_mdw/issues/1168)) ([fb4d45f](https://www.github.com/aeternity/ae_mdw/commit/fb4d45f9056eb4bee87f33a66e10bac1bc017f18))


### Miscellaneous

* add NODE_URL docker build argument ([#1162](https://www.github.com/aeternity/ae_mdw/issues/1162)) ([f74c6e0](https://www.github.com/aeternity/ae_mdw/commit/f74c6e01361233cfc04f6eb9296efa753228357b))
* allow aex9 account balance at a block hash ([#1170](https://www.github.com/aeternity/ae_mdw/issues/1170)) ([047ab62](https://www.github.com/aeternity/ae_mdw/commit/047ab627a9ea03527cc7ed226badd618e07a533f))
* remove priv volume for prod ([#1163](https://www.github.com/aeternity/ae_mdw/issues/1163)) ([3fcde8d](https://www.github.com/aeternity/ae_mdw/commit/3fcde8d5cab6550e0f4f24effb488846fd6aa2c0))
* use only Jason library ([#1154](https://www.github.com/aeternity/ae_mdw/issues/1154)) ([e9e537e](https://www.github.com/aeternity/ae_mdw/commit/e9e537e1af14e104b4307becddc860a0cec2feb5))

## [1.38.0](https://www.github.com/aeternity/ae_mdw/compare/v1.37.1...v1.38.0) (2023-01-30)


### Features

* add metrics observability ([#1145](https://www.github.com/aeternity/ae_mdw/issues/1145)) ([d6228c6](https://www.github.com/aeternity/ae_mdw/commit/d6228c6ab582c190f97de8588f18473217b8429f))
* monitor error 500 ([#1149](https://www.github.com/aeternity/ae_mdw/issues/1149)) ([aa111a8](https://www.github.com/aeternity/ae_mdw/commit/aa111a839680ad5f53187d407a2a6c69fee39b00))


### Bug Fixes

* adapt claim actvities to use the new txi_idx stored format ([#1138](https://www.github.com/aeternity/ae_mdw/issues/1138)) ([c112077](https://www.github.com/aeternity/ae_mdw/commit/c112077ca4d467a0433c41e4150b11096ef36846))
* fix bugs found through integration tests ([#1151](https://www.github.com/aeternity/ae_mdw/issues/1151)) ([c1a797a](https://www.github.com/aeternity/ae_mdw/commit/c1a797a68ce58f6abd11c9ff3dde39be65c5f4ee))
* look for pointee also on previous name record ([#1137](https://www.github.com/aeternity/ae_mdw/issues/1137)) ([9c8bd08](https://www.github.com/aeternity/ae_mdw/commit/9c8bd08ccdc8d787ad651d92d13c4b5426a0501b))
* use proper names for transaction types for events and transactions ([#1142](https://www.github.com/aeternity/ae_mdw/issues/1142)) ([b65830d](https://www.github.com/aeternity/ae_mdw/commit/b65830dd835f42d1e07fd96c7d56fe40f2625036))
* use txi_idx values for displaying pointees ([#1148](https://www.github.com/aeternity/ae_mdw/issues/1148)) ([cf5a09d](https://www.github.com/aeternity/ae_mdw/commit/cf5a09d8c28577e5495a83160f324c90fe83a4e6))


### Refactorings

* remove duplicated v2 ws enqueuing ([#1139](https://www.github.com/aeternity/ae_mdw/issues/1139)) ([7c8aff9](https://www.github.com/aeternity/ae_mdw/commit/7c8aff955e9e404e807dc0c3de319db40c2696f9))


### Miscellaneous

* add MIX_ENV=test for being able to run tests ([#1136](https://www.github.com/aeternity/ae_mdw/issues/1136)) ([e76ceba](https://www.github.com/aeternity/ae_mdw/commit/e76ceba904416af81f96b36326e94f4e353b1b93))
* add support for channels local index reference ([#1144](https://www.github.com/aeternity/ae_mdw/issues/1144)) ([33d5e28](https://www.github.com/aeternity/ae_mdw/commit/33d5e280d249c4192322637963429acc90fd552c))
* cleanup dialyzer warning and util module ([#1150](https://www.github.com/aeternity/ae_mdw/issues/1150)) ([ee066eb](https://www.github.com/aeternity/ae_mdw/commit/ee066eb453b83080f2b48765e04470c4ddf56dc6))
* fix some of dialyzer overspec errors ([#1146](https://www.github.com/aeternity/ae_mdw/issues/1146)) ([fe1bcdf](https://www.github.com/aeternity/ae_mdw/commit/fe1bcdf23bb26f9744f972ca6ecc1d713d429d19))

### [1.37.1](https://www.github.com/aeternity/ae_mdw/compare/v1.37.0...v1.37.1) (2023-01-18)


### Bug Fixes

* allow cursors with names with dashes on them on pagination ([#1131](https://www.github.com/aeternity/ae_mdw/issues/1131)) ([3c30342](https://www.github.com/aeternity/ae_mdw/commit/3c30342b5db4d274df8e7a6e3d75c079f82a87b8))


### Refactorings

* enqueue a block only once to ws broadcasting ([#1132](https://www.github.com/aeternity/ae_mdw/issues/1132)) ([0a5738b](https://www.github.com/aeternity/ae_mdw/commit/0a5738b696a37f3f010006838ed243a71256071d))

## [1.37.0](https://www.github.com/aeternity/ae_mdw/compare/v1.36.0...v1.37.0) (2023-01-16)


### Features

* update node to version 6.7.0 ([#1121](https://www.github.com/aeternity/ae_mdw/issues/1121)) ([67e9918](https://www.github.com/aeternity/ae_mdw/commit/67e991889d3b31a8382249f4eadd80f072e34acf))


### Bug Fixes

* skip importing hardfork accounts for custom networks ([#1128](https://www.github.com/aeternity/ae_mdw/issues/1128)) ([aa8ba56](https://www.github.com/aeternity/ae_mdw/commit/aa8ba56bbe45073badc24d42db7d93515a5eb28f))

## [1.36.0](https://www.github.com/aeternity/ae_mdw/compare/v1.35.1...v1.36.0) (2023-01-13)


### Features

* add channel participants to channel txs ([#1120](https://www.github.com/aeternity/ae_mdw/issues/1120)) ([27e3e19](https://www.github.com/aeternity/ae_mdw/commit/27e3e19d6d3021d3ef9f8576ae9891d377264c24))


### Bug Fixes

* formats call return composed by tuple value ([#1124](https://www.github.com/aeternity/ae_mdw/issues/1124)) ([a386a7e](https://www.github.com/aeternity/ae_mdw/commit/a386a7ea20184d4d759a328c462f4dd2d9e81e17))

### [1.35.1](https://www.github.com/aeternity/ae_mdw/compare/v1.35.0...v1.35.1) (2023-01-12)


### Bug Fixes

* ignore gen-based internal transfers for txi indexed activities ([#1115](https://www.github.com/aeternity/ae_mdw/issues/1115)) ([e152455](https://www.github.com/aeternity/ae_mdw/commit/e15245568f4a7bbc71b9f96349c3d14eba4cbb50))


### Testing

* improve aex9 dex coverage ([#1118](https://www.github.com/aeternity/ae_mdw/issues/1118)) ([bafefe5](https://www.github.com/aeternity/ae_mdw/commit/bafefe5cdd284e97a3e1b0e123ecca30f71ee4c4))


### Miscellaneous

* **ci:** always enable semver tags ([#1123](https://www.github.com/aeternity/ae_mdw/issues/1123)) ([ad1871c](https://www.github.com/aeternity/ae_mdw/commit/ad1871c869d5d9f6b9b639b0f6c7f8b2d980ecb1))

## [1.35.0](https://www.github.com/aeternity/ae_mdw/compare/v1.34.0...v1.35.0) (2023-01-11)


### Features

* add offchain rounds to channel transactions ([#1114](https://www.github.com/aeternity/ae_mdw/issues/1114)) ([d20f8f4](https://www.github.com/aeternity/ae_mdw/commit/d20f8f4d39e45463e5f04aa7a0b70f2dcad495f6))
* allow filtering activities by ownership only ([#1111](https://www.github.com/aeternity/ae_mdw/issues/1111)) ([c91206e](https://www.github.com/aeternity/ae_mdw/commit/c91206e8fefa6745b830d0140415c24e3c9492f1))
* render inner tx details ([#1109](https://www.github.com/aeternity/ae_mdw/issues/1109)) ([37282f2](https://www.github.com/aeternity/ae_mdw/commit/37282f276b69618d8ac4131f36965f3884bffbec))


### Miscellaneous

* **ci:** use custom token instead of default ([#1107](https://www.github.com/aeternity/ae_mdw/issues/1107)) ([d1f0e6a](https://www.github.com/aeternity/ae_mdw/commit/d1f0e6a8b7c385401ba957af4d8d1ab43f5e7900))
* cleanup library dependencies ([#1116](https://www.github.com/aeternity/ae_mdw/issues/1116)) ([54e6cf6](https://www.github.com/aeternity/ae_mdw/commit/54e6cf6196678782332c3bbb862ae6c7a9d5a4bd))
* remove migrations since scratch sync needed for 1.34 ([#1113](https://www.github.com/aeternity/ae_mdw/issues/1113)) ([0c8ad4b](https://www.github.com/aeternity/ae_mdw/commit/0c8ad4bcb278fe54a729b228be783ac600342792))
* remove unused code ([#1117](https://www.github.com/aeternity/ae_mdw/issues/1117)) ([ed0c517](https://www.github.com/aeternity/ae_mdw/commit/ed0c51781f0a13ab8abab092a69e9106089105dc))

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
