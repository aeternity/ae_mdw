<template>
  <div>
    <PageHeader
      title="Faucet"
      :has-crumbs="true"
      :page="{to: '/faucet', name: 'Testnet Faucet'}"
    />
    <div class="faucet-bar">
      <input
        v-model="userAddress"
        :placeholder="placeholder"
        class="faucet-bar-input"
        type="text"
        @keyup.enter="processInput"
      >
      <button
        class="faucet-bar-button"
        @click="processInput"
      >
        <AppIcon name="left-more" />
      </button>
    </div>
    <div class="faucet-bar-messages">
      <AppIcon
        v-if="loading"
        name="ae-loader"
      />
      <AppTableBody>
        <AppTableRow
          v-if="tx_hash"
          extend
        >
          <AppTableCell extend>
            <nuxt-link
              :to="`/account/transactions/${account}`"
            >
              <AppDefinition
                type="list"
                title="Account"
              >
                {{ account }}
              </AppDefinition>
            </nuxt-link>
          </AppTableCell>
        </AppTableRow>
      </AppTableBody>
      <AppTableBody>
        <AppTableRow
          v-if="tx_hash"
          extend
        >
          <AppTableCell extend>
            <nuxt-link
              :to="`/transactions/${tx_hash}`"
            >
              <AppDefinition
                type="list"
                title="Hash"
              >
                {{ tx_hash }}
              </AppDefinition>
            </nuxt-link>
          </AppTableCell>
        </AppTableRow>
      </AppTableBody>
      <AppTableBody>
        <AppTableRow
          v-if="tx_hash"
          extend
        >
          <AppTableCell extend>
            <AppDefinition
              type="list"
              title="Balance"
            >
              {{ balance | prefixAmount }}
            </AppDefinition>
          </AppTableCell>
        </AppTableRow>
      </AppTableBody>
      <AppTableBody>
        <AppTableRow
          v-if="errorMessage"
          extend
        >
          <AppTableCell extend>
            <AppDefinition
              type="list"
              title="Message"
            >
              {{ errorMessage }}
            </AppDefinition>
          </AppTableCell>
        </AppTableRow>
      </AppTableBody>
    </div>
  </div>
</template>
<script>
import AppIcon from '../../components/appIcon'
import PageHeader from '../../components/PageHeader'
import AppDefinition from '../../components/appDefinition'
import AppTableBody from '../../components/appTableBody'
import AppTableRow from '../../components/appTableRow'
import AppTableCell from '../../components/appTableCell'
import prefixAmount from '../../plugins/filters/prefixedAmount'

export default {
  name: 'Faucet',
  components: {
    AppIcon,
    PageHeader,
    AppDefinition,
    AppTableBody,
    AppTableRow,
    AppTableCell
  },
  filters: {
    prefixAmount
  },
  props: {
    placeholder: {
      type: String,
      default: 'ak_YOUrPubl1ckeyh4sHh3r3'
    }
  },
  data () {
    return {
      userAddress: '',
      account: '',
      balance: 0,
      tx_hash: '',
      errorMessage: '',
      loading: false
    }
  },
  beforeCreate () {
    if (!this.$store.state.enableFaucet) {
      this.$router.push('/')
    }
  },
  mounted () {
    this.resetData()
  },
  methods: {
    async processInput () {
      this.resetData()
      if (this.userAddress.match(/^ak_[1-9A-HJ-NP-Za-km-z]{48,50}$/)) {
        this.account = this.userAddress
        this.loading = true
        const result = await this.$store.dispatch('account/createFaucetTx', this.userAddress)
        this.loading = false
        if (result.error) {
          this.errorMessage = result.error
        } else {
          this.balance = result.balance
          this.tx_hash = result.tx_hash
        }
        this.userAddress = ''
      }
    },
    resetData () {
      this.account = ''
      this.balance = 0
      this.tx_hash = ''
      this.errorMessage = ''
    }
  }
}
</script>
<style scoped lang="scss">
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";
  @import "~@aeternity/aepp-components-3/src/styles/placeholders/typography";
  .faucet-bar {
    position: relative;
    width: 100%;
    display: flex;
    flex-direction: row;
    background-color: #FFFFFF;
    border-radius: .4rem;
    overflow: hidden;
    justify-content: center;
    align-items: center;
    &-input {
      width: 100%;
      border: none;
      padding: 1.3rem .6rem;
      color: $color-neutral-negative-1;
      @extend %face-sans-base;
    }

    &-button {
      border: none;
      background-color: transparent;
      cursor: pointer;
      justify-content: center;
      align-items: center;
      line-height: 0;
      padding: 1.3rem .6rem;
      font-size: 1.5rem;
      color: $color-neutral-negative-1;
    }

    &-messages {
        margin-top: 2rem;
        .app-icon {
            width: 8rem;
            height: 10rem;
            margin-left: 30rem;
        }
    }
  }
</style>
