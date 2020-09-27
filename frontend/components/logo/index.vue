<template>
  <RouterLink
    class="logo"
    to="/"
  >
    <div class="app-nav-logo">
      <div
        :class="fill"
        class="graphics"
      >
        <svg
          class="logo"
          width="45"
          height="22"
          viewBox="0 0 45 22"
          xmlns="http://www.w3.org/2000/svg"
        >
          <g
            fill="#ffffff"
            fill-rule="evenodd"
          >
            <path d="M34.107 0C29.67 0 26.63 2.757 24 6.172l1.558 2.263c2.408-3.276 4.967-5.853 8.55-5.853 4.114 0 7.536 2.966 8.168 6.835H32.061V12h12.86A10.6 10.6 0 0 0 45 10.709C45 4.804 40.114 0 34.107 0" />
            <path d="M34.73 19.347c-4.43 0-7.354-3.864-11.066-9.535C19.953 4.142 16.45 0 11.016 0 4.942 0 0 4.935 0 11s4.942 11 11.016 11c4.48 0 7.553-2.822 10.208-6.322L19.66 13.34c-2.434 3.363-5.022 6.008-8.644 6.008-4.614 0-8.368-3.744-8.368-8.347s3.754-8.347 8.368-8.347c4.43 0 7.197 3.667 11.058 9.525C25.934 18.036 29.296 22 34.73 22c4.67 0 8.67-2.916 10.27-7.02h-2.915a8.379 8.379 0 0 1-7.355 4.367" />
          </g>
        </svg>
      </div>
      <span class="bold">
        æternal
      </span>
    </div>
  </RouterLink>
</template>

<script>
export default {
  name: 'Logo',
  props: {
    fill: {
      type: String,
      validator: value => [
        'primary',
        'secondary'
      ].includes(value),
      default: 'primary'
    }
  }
}
</script>

<style scoped lang="scss">
  @import "~@aeternity/aepp-components-3/src/styles/variables/colors";

  .app-nav-logo {
    display: flex;
    align-items: center;
    font-size: .9rem;
    color: white;
    & .graphics {
      display: block;
      width: 2em;
      height: 2em;
      margin-right: .5rem;
      border-radius: 50%;
      text-align: center;
      &.primary {
          background-color: $color-primary;
        }
      &.secondary {
        background-color: $color-secondary;
      }
    }
    & .bold {
      font-weight: bold;
    }
    .logo {
      max-width: 1.4em;
      height: 2em;
    }
  }
</style>
