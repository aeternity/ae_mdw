<template>
  <div class="app-names">
    <PageHeader
      :has-crumbs="true"
      :page="{to: '/channels', name: 'Channels'}"
      title="State Channels"
    />
    <div v-if="!loading && channels.length">
      <ChannelList>
        <Channel
          v-for="(item, index) in channels"
          :key="index"
          :data="item"
        />
      </ChannelList>
    </div>
    <div v-if="loading">
      Loading....
    </div>
    <div v-if="!loading && channels.length == 0">
      Nothing to see here right now....
    </div>
  </div>
</template>

<script>
import ChannelList from '../../partials/channels/channelList'
import Channel from '../../partials/channels/channel'
import PageHeader from '../../components/PageHeader'
import { mapState } from 'vuex'

export default {
  name: 'AppChannels',
  components: {
    ChannelList,
    Channel,
    PageHeader
  },
  data () {
    return {
      page: 1,
      loading: true
    }
  },
  computed: {
    ...mapState('channels', [
      'channels'
    ])
  },
  async beforeMount () {
    this.loading = true
    await this.$store.dispatch('channels/getChannels')
    this.loading = false
  }
}
</script>
