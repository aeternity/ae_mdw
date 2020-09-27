<template>
  <div
    ref="address"
    :class="[ length ]"
    :title="value"
    class="format-address"
  >
    <template v-if="length === 'responsive'">
      <div
        v-if="link === ''"
      >
        <span class="first-chunk">
          <span
            v-for="chunk in chunked.slice(0, 3)"
            :key="chunk"
          >
            {{ chunk }}
          </span>
        </span>
        <span class="middle-chunk">
          ...
        </span>
        <span class="last-chunk">
          <span
            v-for="chunk in chunked.slice(15, 18)"
            :key="chunk"
          >
            {{ chunk }}
          </span>
        </span>
      </div>
      <nuxt-link
        v-else
        :to="link"
      >
        <span class="first-chunk">
          <span
            v-for="chunk in chunked.slice(0, 3)"
            :key="chunk"
          >
            {{ chunk }}
          </span>
        </span>
        <span class="middle-chunk">
          ...
        </span>
        <span class="last-chunk">
          <span
            v-for="chunk in chunked.slice(15, 18)"
            :key="chunk"
          >
            {{ chunk }}
          </span>
        </span>
      </nuxt-link>
    </template>
    <template v-if="length === 'full'">
      <div
        v-if="link === ''"
      >
        <span
          v-for="chunk in chunked"
          :key="chunk.id"
        >
          {{ chunk }}
        </span>
      </div>
      <nuxt-link
        v-else
        :to="link"
      >
        <span
          v-for="chunk in chunked"
          :key="chunk.id"
        >
          {{ chunk }}
        </span>
      </nuxt-link>
    </template>
    <template v-if="length === 'nochunk'">
      <div
        v-if="link === ''"
      >
        {{ value }}
      </div>
      <nuxt-link
        v-else
        :to="link"
      >
        {{ value }}
      </nuxt-link>
    </template>
    <div
      v-if="icon"
      v-copy-to-clipboard="value"
      v-remove-spaces-on-copy
      class="format-address-clipboard"
    >
      <AppIcon name="copy" />
    </div>
  </div>
</template>
<script>
import AppIcon from '../appIcon'
export default {
  name: 'FormatAddress',
  components: {
    AppIcon
  },
  props: {
    value: {
      type: String,
      required: true
    },
    length: {
      type: String,
      default: 'full'
    },
    enableCopyToClipboard: {
      type: Boolean,
      default: false
    },
    icon: {
      type: Boolean,
      default: false
    }
  },
  computed: {
    copyToClipboard () {
      return this.enableCopyToClipboard ? this.value : false
    },
    chunked () {
      return this.value.match(/^\w{2}_|.{2}(?=.{47,48}$)|.{2,3}/g)
    },
    link () {
      if (this.value.match(/^th_[1-9A-HJ-NP-Za-km-z]{48,50}$/)) {
        return `/transactions/${this.value}`
      }
      if (this.value.match(/^ok_[1-9A-HJ-NP-Za-km-z]{48,50}$/)) {
        return `/oracles/queries/${this.value}`
      }
      if (this.value.match(/^ch_[1-9A-HJ-NP-Za-km-z]{48,50}$/)) {
        return `/channels/transactions/${this.value}`
      }
      if (this.value.match(/^ct_[1-9A-HJ-NP-Za-km-z]{48,50}$/)) {
        return `/contracts/transactions/${this.value}`
      }
      if (this.value.match(/^ak_[1-9A-HJ-NP-Za-km-z]{48,50}$/)) {
        return `/account/transactions/${this.value}`
      }
      return ''
    }
  }
}
</script>
<style lang="scss" scoped>
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";
  @import "~@aeternity/aepp-components-3/src/styles/placeholders/typography";
  .format-address {
    color: inherit;
    font-family: inherit;
    display: flex;
    font-size: inherit;
    word-break: normal;
    position: relative;
  }
  .format-address.full{
    flex-wrap: wrap;
    & span {
      min-width: 2.7em;
    }
  }
  .format-address-clipboard {
    display: flex;
    & .app-icon {
      margin-left: .3rem;
    }
    &.v-copied-to-clipboard:before {
      @extend %face-mono-base;
      content: 'copied to clipboard';
      display: flex;
      justify-content: center;
      align-items: center;
      font-weight: 500;
      color: $color-neutral-negative-3;
      background: rgba($color-neutral-positive-1, 0.9);
      position: absolute;
      top: 0;
      right: 0;
      left: 0;
      bottom: 0;
    }
  }
  .first-chunk {
    & span:nth-child(3) {
      @media (max-width: 1024px) {
        display: none;
      }
    }
    & span:nth-child(2) {
      @media (min-width: 320px) {
        margin-left: -.5rem;
      }
    }
  }
  .middle-chunk {
    display: inline-block;
    vertical-align: middle;
    line-height: 1;
  }
  .last-chunk {
    & span:nth-child(1) {
      @media (max-width: 1024px) {
        display: none;
      }
     }

  }

</style>
