<template>
  <div class="app-main-nav">
    <div class="app-main-nav-logo">
      <Logo fill="primary" />
    </div>
    <div class="app-main-nav-mobile">
      <AppNavAccordion icon="search">
        <div class="mobile-search">
          <SearchBar />
          <p class="mobile-search-info">
            Search by account, height, tx, oracle, contract, channel
          </p>
        </div>
      </AppNavAccordion>
    </div>
    <AppNavAccordion>
      <AppNav>
        <AppNavLink
          to="/"
          :exact="true"
        >
          Dashboard
        </AppNavLink>
        <AppNavLink to="/generations">
          Generations
        </AppNavLink>
        <AppNavLink to="/transactions">
          Transactions
        </AppNavLink>
        <AppNavLink to="/channels">
          Channels
        </AppNavLink>
        <AppNavLink to="/contracts">
          Contracts
        </AppNavLink>
        <AppNavLink to="/names">
          Names
        </AppNavLink>
        <AppNavLink to="/auctions">
          Name Auctions
        </AppNavLink>
        <AppNavLink to="/oracles">
          Oracles
        </AppNavLink>
        <AppNavLink
          :to="this.$store.state.swaggerHub"
          :external="true"
          external-value="Swagger Hub"
        >
          Swagger Hub
        </AppNavLink>
        <AppNavLink
          v-if="isFaucetActive"
          to="/faucet"
        >
          Faucet
        </AppNavLink>
      </AppNav>
    </AppNavAccordion>
  </div>
</template>

<script>
import Logo from '../../components/logo'
import AppNavAccordion from '../../components/appNavAccordion'
import SearchBar from '../../components/searchBar'
import AppNav from '../../components/appNav'
import AppNavLink from '../../components/appNavLink'

export default {
  name: 'AppMainNav',
  components: {
    AppNavAccordion,
    AppNav,
    AppNavLink,
    SearchBar,
    Logo
  },
  computed: {
    isFaucetActive () {
      return this.$store.state.enableFaucet
    }
  }
}
</script>

<style scoped lang="scss">
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";
  @import "~@aeternity/aepp-components-3/src/styles/placeholders/typography";

  .app-main-nav {
    min-height: 3rem;
    display: flex;
    position: relative;
    background-color: #001833;
    color: #FFFFFF;
    padding: .8rem;
    justify-content: space-between;
    @media (min-width: 769px) {
      flex-direction: column;
      justify-content: space-between;
      padding-left: 1rem;
      min-width: 12rem;
      width: 20%;
      position: fixed;
      top: 0;
      bottom: 0;
      left: 0;
    }
    @media (min-width: 1040px) {
      width: 15%;
    }
  }
  .app-main-nav-mobile {
    display: flex;
    @media (min-width: 769px) {
      display: none;
    }
  }
  .app-main-nav-logo{
    width: 100%;
    margin-right: auto;
  }
  .mobile-search {
    padding: 1.5rem;
    &-info{
      @extend %face-sans-s;
      margin-top: 1rem;
      color: $color-neutral-negative-1;
    }
  }
</style>
