<template>
  <div class="channel">
    <div class="container-first">
      <div class="container-first-inner">
        <nuxt-link
          v-if="data"
          :to="`/channels/transactions/${data}`"
        >
          <LabelType
            title="Channel"
            fill="green"
          />
        </nuxt-link>
        <Account
          v-if="data"
          :value="data"
          title="Channel Id"
          icon
        />
      </div>
    </div>
  </div>
</template>
<script>
import Account from '../../../components/account'
import LabelType from '../../../components/labelType'

export default {
  name: 'Channel',
  components: {
    LabelType,
    Account
  },
  props: {
    data: {
      type: String,
      required: true
    }
  }
}
</script>

<style scoped lang="scss">
  @import "../../../node_modules/@aeternity/aepp-components-3/src/styles/variables/colors";
  .channel {
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
      &:last-child {
        border-left: 2px solid $color-neutral-positive-2;
        @media (min-width: 550px) {
          border-left: none;
        }
      }
    }
  }
</style>
