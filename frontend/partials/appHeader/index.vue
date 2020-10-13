<template>
  <header class="app-header">
    <AppMainNav />
    <div class="app-header-content">
      <section class="inner">
        <div class="searchbar">
          <SearchBar placeholder="Search by account, height, tx, oracle, contract, channel" />
        </div>
        <div class="network">
          <NetworkName />
        </div>
      </section>
    </div>
  </header>
</template>

<script>
import AppMainNav from '../../partials/appMainNav'
import SearchBar from '../../components/searchBar'
import NetworkName from '../../components/networkName'
export default {
  name: 'AppHeader',
  components: {
    AppMainNav,
    SearchBar,
    NetworkName
  }
}
</script>

<style scoped lang="scss">
@import "~@aeternity/aepp-components-3/src/styles/variables/colors";
@import "~@aeternity/aepp-components-3/src/styles/placeholders/typography";

.app-header {
  background-color: #D3DCE6;
  min-height: 30vh;
  margin-bottom: -7.75rem;

  &-content {
    margin-left: auto;
    width: 80%;
    padding: 0 5%;
    display: flex;
    flex-direction: column;
    @media (min-width:1080px) {
      width: 85%;
    }
  }
  &-title {
    margin-bottom: 3rem;
  }
}
.inner {
  width: 100%;
  margin-top: 1.5rem;
  display: flex;
  align-items: center;
  @media (min-width:769px) {
    margin: 3rem 0 auto 0;
  }

  & .searchbar {
   width: 60%;
   max-width: 30rem;
   @media (max-width: 768px) {
     display: none;
   }
 }
  & .network {
    width: auto;
    margin-left: auto;
    @media (max-width:768px) {
      margin-right: -.7rem;
    }
  }
  }
</style>
