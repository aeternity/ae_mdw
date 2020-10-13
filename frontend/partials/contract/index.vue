<template>
  <div class="contract">
    <div class="container-first">
      <div class="container-first-inner">
        <nuxt-link :to="`/contracts/transactions/${data.contract_id}`">
          <LabelType
            title="Contract"
            fill="green"
          />
        </nuxt-link>
        <Account
          v-if="data.contract_id"
          :value="data.contract_id"
          title="Contract ID"
          icon
        />
      </div>
    </div>
    <div class="container-last">
      <div class="container-last-wrapper">
        <AppDefinition
          class="container-last-inner"
          title="Block Height"
        >
          <nuxt-link
            class="block-height"
            :to="`/generations/${data.block_height}`"
          >
            {{ data.block_height }}
          </nuxt-link>
        </AppDefinition>
      </div>

      <Account
        v-if="data.transaction_hash"
        :value="data.transaction_hash"
        title="Transaction Hash"
        icon
      />
    </div>
  </div>
</template>
<script>
import AppDefinition from '../../components/appDefinition'
import Account from '../../components/account'
import LabelType from '../../components/labelType'

export default {
  name: 'Contract',
  components: {
    AppDefinition,
    LabelType,
    Account
  },
  props: {
    data: {
      type: Object,
      required: true
    }
  }
}
</script>

<style scoped lang="scss">
@import '../../node_modules/@aeternity/aepp-components-3/src/styles/variables/colors';
.contract {
  background-color: #ffffff;
  display: flex;
  flex-direction: column;
  padding: 0.6rem 0.6rem 0.6rem 0;
  border-radius: 0.4rem;
  box-shadow: 0 0 16px 0 rgba(27, 68, 121, 0.1);
  margin-bottom: 1rem;
  @media (min-width: 768px) {
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
  margin-bottom: 0.6rem;
  @media (min-width: 768px) {
    width: 50%;
    flex-direction: column;
    justify-content: space-between;
  }
  &-inner {
    width: 50%;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    @media (min-width: 768px) {
      width: 100%;
      flex-direction: row;
      justify-content: flex-start;
      align-items: center;
    }
    &:last-child {
      border-left: 2px solid $color-neutral-positive-2;
      @media (min-width: 768px) {
        border-left: none;
      }
/*       @media (min-width: 1600px) {
        margin-left: 2rem;
      } */
    }
  }
}
.container-last {
  display: flex;
  align-items: baseline;
  flex-direction: column;
  @media (min-width: 768px) {
    width: 50%;
    border-left: 2px solid $color-neutral-positive-2;
  }
  &-wrapper {
    display: flex;
    width: 100%;
    border-top: 2px solid $color-neutral-positive-2;
    padding: 0.6rem 0;
    height: 100%;
    &:last-child {
      padding-bottom: 0;
    }
    @media (min-width: 768px) {
      border-top: none;
      padding: 0;
      &:first-child {
        border-bottom: 2px solid $color-neutral-positive-2;
      }
    }
  }
  &-inner {
    width: 50%;
    &:nth-child(2n) {
      border-left: 2px solid $color-neutral-positive-2;
    }
    @media (min-width: 768px) {
      &:nth-child(2n) {
        border-left: 2px solid $color-neutral-positive-2;
      }
    }
  }
}
.block-height {
  font-size: 1.2rem;
  margin-left: 0.6rem;
  font-family: 'Inter UI', sans-serif;
}
</style>
