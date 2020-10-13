<template>
  <div class="generation">
    <div class="container-first">
      <div class="container-first-inner">
        <nuxt-link
          :to="`/generations/${data.height}`"
        >
          <LabelType
            title="block height"
            fill="black"
          />
        </nuxt-link>
        <BlockHeight
          v-if="data.height"
          :value="data.height"
        />
      </div>
      <div class="container-first-inner">
        <Account
          v-if="data.beneficiary"
          :value="data.beneficiary"
          title="Beneficiary"
          icon
        />
      </div>
    </div>
    <div class="container-last">
      <div class="container-last-wrapper">
        <AppDefinition
          class="container-last-inner"
          title="Transactions"
        >
          {{ numTransactions }}
        </AppDefinition>
        <AppDefinition
          class="container-last-inner"
          title="Age"
        >
          <Age
            v-if="data.time"
            :time="data.time"
          />
        </AppDefinition>
      </div>
      <div class="container-last-wrapper">
        <AppDefinition
          class="container-last-inner"
          title="Microblocks"
        >
          {{ numMicroBlocks }}
        </AppDefinition>

        <AppDefinition
          class="container-last-inner"
          title="Target"
        >
          {{ data.target }}
        </AppDefinition>
      </div>
    </div>
  </div>
</template>

<script>

import AppDefinition from '../../components/appDefinition'
import Account from '../../components/account'
import Age from '../../components/age'
import LabelType from '../../components/labelType'
import BlockHeight from '../../components/blockHeight'
import prefixedAmount from '../../plugins/filters/prefixedAmount.js'

export default {
  name: 'Index',
  filters: { prefixedAmount },
  components: {
    BlockHeight,
    LabelType,
    AppDefinition,
    Account,
    Age
  },
  props: {
    data: {
      type: Object,
      required: true
    }
  },
  computed: {
    numTransactions () {
      return Object.values(this.$props.data.micro_blocks).reduce((previousValue, currentValue) => {
        const tx = currentValue.transactions ? Object.keys(currentValue.transactions).length : 0
        return previousValue + tx
      }, 0)
    },
    numMicroBlocks () {
      return Object.keys(this.$props.data.micro_blocks).length
    }
  }
}
</script>

<style scoped lang="scss">
  @import "../../node_modules/@aeternity/aepp-components-3/src/styles/variables/colors";
  .generation {
    background-color: #FFFFFF;
    display: flex;
    flex-direction: column;
    padding: .6rem .6rem .6rem 0;
    border-radius: .4rem;
    box-shadow: 0 0 16px 0 rgba(27,68,121,0.10);
    margin-bottom: 1rem;
    @media (min-width: 550px) {
      flex-direction: row;
      border-radius: 0;
      box-shadow: none;
      margin-bottom: 0;
      border-bottom: 2px solid $color-neutral-positive-2;
    }
  }
  .container-first {
    display: flex;
    flex-direction: row;
    margin-bottom: .6rem;
    @media (min-width: 550px) {
      width: 50%;
      flex-direction: column;
      justify-content: space-between;
    }
    @media (min-width: 1600px) {
      width: 50%;
      flex-direction: row;
      justify-content: flex-start;
    }
    &-inner {
      width: 50%;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      @media (min-width: 550px) {
        width: 100%;
        flex-direction: row;
        justify-content: flex-start;
        align-items: center;
      }
      @media (min-width: 1600px) {
        width: auto;
      }
      &:last-child {
        border-left: 2px solid $color-neutral-positive-2;
        @media (min-width: 550px) {
          border-left: none;
        }
        @media (min-width: 1600px) {
          margin-left: 2rem;
        }
      }
    }
  }
  .container-last {
    display: flex;
    align-items: baseline;
    flex-direction: column;
    @media (min-width: 550px) {
      width: 50%;
      border-left: 2px solid $color-neutral-positive-2;
    }
    @media (min-width: 1600px) {
      flex-direction: row;
      border-left: none;
    }
    &-wrapper {
      display: flex;
      width: 100%;
      border-top: 2px solid $color-neutral-positive-2;
      padding: .6rem 0;
      height: 100%;
      &:last-child {
        padding-bottom: 0;
      }
      @media (min-width: 550px) {
        border-top: none;
        padding: 0;
        &:first-child {
          border-bottom: 2px solid $color-neutral-positive-2;
        }
      }
      @media (min-width: 1600px) {
        &:first-child {
          border-bottom: none;
        }
      }
    }
    &-inner {
      width: 50%;
      &:nth-child(2n) {
        border-left: 2px solid $color-neutral-positive-2;
      }
      @media (min-width: 550px) {
        &:nth-child(2n) {
          border-left: 2px solid $color-neutral-positive-2;
        }
      }
      @media (min-width: 1600px) {
        &:nth-child(1n) {
          border-left: 2px solid $color-neutral-positive-2;
        }
      }
    }
  }
</style>
