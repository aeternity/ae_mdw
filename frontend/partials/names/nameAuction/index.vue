<template>
  <div class="auction">
    <div class="auction-main-info">
      <div class="auction-main-info-inner">
        <div class="auction-label">
          <LabelType
            title="Name Auction"
            fill="red"
          />
        </div>
      </div>
      <div class="auction-main-info-inner accounts">
        <Account
          v-if="data.name"
          :value="data.name"
          title="name"
          length="nochunk"
          icon
        />
        <Account
          :value="data.winning_bidder"
          title="Winning Bidder"
          icon
        />
      </div>
    </div>
    <div class="auction-type-info">
      <div class="auction-type-info-item">
        <AppDefinition
          title="Winning Bid"
        >
          <FormatAeUnit :value="Number(data.winning_bid)" />
        </AppDefinition>
      </div>
      <div class="auction-type-info-item">
        <AppDefinition
          title="Expiration Height"
        >
          {{ data.expiration }}
        </AppDefinition>
        <AppDefinition
          title="Estimated Expiration Time"
          class="tx-time"
        >
          {{ estimatedExpiration }}
        </AppDefinition>
      </div>
    </div>
  </div>
</template>
<script>
import AppDefinition from '../../../components/appDefinition'
import Account from '../../../components/account'
import LabelType from '../../../components/labelType'
import FormatAeUnit from '../../../components/formatAeUnit'

export default {
  name: 'NameAuction',
  components: {
    AppDefinition,
    LabelType,
    Account,
    FormatAeUnit
  },
  props: {
    data: {
      type: Object,
      required: true
    }
  },
  computed: {
    estimatedExpiration () {
      const heightDiff = this.data.expiration - this.$store.state.height
      const epoch = new Date()
      epoch.setSeconds(heightDiff * 180) // considering 1 block takes 3 minutes
      const date = epoch.toISOString().replace('T', ' ')
      return date.split('.')[0].split(' ')[0] + ' ' + epoch.toLocaleTimeString()
    }
  }
}
</script>

<style scoped lang="scss">
@import '~@aeternity/aepp-components-3/src/styles/variables/colors';
.auction {
  background-color: #ffffff;
  display: flex;
  flex-direction: column;
  padding: 0.6rem 0.6rem 0 0;
  border-radius: 0.4rem;
  box-shadow: 0 0 16px 0 rgba(27, 68, 121, 0.1);
  margin-bottom: 1rem;
  width: 100%;
  @media (min-width: 550px) {
    flex-direction: row;
    border-radius: 0;
    box-shadow: none;
    margin-bottom: 0;
    &:not(:last-child) {
      border-bottom: 2px solid $color-neutral-positive-2;
    }
  }

  /deep/ .auction-main-info {
    display: flex;
    margin-bottom: 0.6rem;
    flex-direction: row;
    width: 100%;
    @media (min-width: 550px) {
      width: 60%;
      justify-content: space-between;
    }
    @media (min-width: 1600px) {
      width: 65%;
    }

    &-inner {
      width: 50%;
      &:not(:first-child) {
        border-left: 2px solid $color-neutral-positive-2;
      }
      @media (min-width: 550px) {
        width: 30%;
        &:not(:first-child) {
          border-left: none;
        }
      }

      .name {
        margin-left: 43px;
      }
    }

    .accounts {
      width: 50%;
      @media (min-width: 550px) {
        width: 70%;
      }
    }
  }

  /deep/ .auction-type-info {
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
    @media (min-width: 550px) {
      width: 40%;
      flex-direction: row;
    }
    @media (min-width: 1600px) {
      width: 35%;
    }

    .auction-type-info-item {
      display: flex;
      flex-direction: row;
      width: 100%;
      border-top: 2px solid $color-neutral-positive-2;
      padding: 0.6rem 0;
      margin-bottom: 0.6rem;
      @media (min-width: 550px) {
        border-top: none;
        width: 50%;
        flex-direction: column;
        border-left: 2px solid $color-neutral-positive-2;
      }

      .block {
        &:not(:first-child) {
          border-left: 2px solid $color-neutral-positive-2;
          border-top: none;
        }
        @media (min-width: 550px) {
          &:not(:first-child) {
            border-left: none;
            border-top: 2px solid $color-neutral-positive-2;
          }
        }
      }
      .tx-time .app-definition-content {
        word-break: keep-all;
      }
    }
  }
}
</style>
