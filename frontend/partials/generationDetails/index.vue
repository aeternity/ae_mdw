<template>
  <div>
    <AppPanel>
      <AppTable details>
        <AppTableHeader>
          <AppTableRow>
            <AppTableRowColumn width="large">
              <AppTableCell extend>
                <div class="block-height-wrapper">
                  <nuxt-link
                    :to="`/generations/${data.height}`"
                  >
                    <LabelType
                      title="block height"
                      fill="black"
                    />
                  </nuxt-link>
                  <BlockHeight :value="data.height" />
                  <div>
                    <Confirmations
                      :max-height="dynamicData"
                      :height="data.height"
                    />
                  </div>
                </div>
              </AppTableCell>
            </AppTableRowColumn>
            <AppTableRowColumn width="small">
              <AppTableCell>
                <AppDefinition
                  class="container-last-inner"
                  title="Age"
                >
                  <Age :time="data.time" />
                </AppDefinition>
              </AppTableCell>
            </AppTableRowColumn>
          </AppTableRow>
          <AppTableRow>
            <AppTableRowColumn>
              <AppTableCell extend>
                <Account
                  :value="data.beneficiary"
                  title="beneficiary"
                  icon
                />
              </AppTableCell>
            </AppTableRowColumn>
            <AppTableRowColumn>
              <AppTableCell>
                <AppDefinition
                  title="Microblocks"
                >
                  {{ microBlocks }}
                </AppDefinition>
              </AppTableCell>
            </AppTableRowColumn>
          </AppTableRow>
        </AppTableHeader>
        <AppTableBody>
          <AppTableRow extend>
            <AppTableCell extend>
              <nuxt-link
                :to="`/generations/${data.height}`"
              >
                <AppDefinition
                  type="list"
                  title="Hash"
                >
                  <FormatAddress
                    v-if="data.hash"
                    :value="data.hash"
                    length="full"
                    icon
                  />
                </AppDefinition>
              </nuxt-link>
            </AppTableCell>
          </AppTableRow>
          <AppTableRow>
            <AppTableCell extend>
              <AppDefinition
                type="list"
                title="Target"
              >
                {{ data.target }}
              </AppDefinition>
            </AppTableCell>
          </AppTableRow>
          <AppTableAccordion>
            <AppTableRow extend>
              <AppTableCell extend>
                <AppDefinition
                  type="list"
                  title="Miner"
                >
                  <FormatAddress
                    v-if="data.miner"
                    :value="data.miner"
                    length="full"
                    icon
                  />
                </AppDefinition>
              </AppTableCell>
            </AppTableRow>
            <AppTableRow extend>
              <AppTableCell extend>
                <AppDefinition
                  type="list"
                  title="Nonce"
                >
                  {{ data.nonce }}
                </AppDefinition>
              </AppTableCell>
            </AppTableRow>
            <AppTableRow extend>
              <AppTableCell extend>
                <AppDefinition
                  type="list"
                  title="Version"
                >
                  {{ data.version }}
                </AppDefinition>
              </AppTableCell>
            </AppTableRow>
            <AppTableRow extend>
              <AppTableCell extend>
                <AppDefinition
                  type="list"
                  title="Prev hash"
                >
                  <FormatAddress
                    :value="data.prev_hash"
                    length="full"
                    icon
                  />
                </AppDefinition>
              </AppTableCell>
            </AppTableRow>
            <AppTableRow
              extend
            >
              <AppTableCell extend>
                <nuxt-link
                  :to="`/generations/${data.height-1}`"
                >
                  <AppDefinition
                    type="list"
                    title="Prev key hash"
                  >
                    <FormatAddress
                      v-if="data.prev_key_hash"
                      :value="data.prev_key_hash"
                      length="full"
                      icon
                    />
                  </AppDefinition>
                </nuxt-link>
              </AppTableCell>
            </AppTableRow>
            <AppTableRow extend>
              <AppTableCell extend>
                <AppDefinition
                  type="list"
                  title="State hash"
                >
                  <FormatAddress
                    v-if="data.state_hash"
                    :value="data.state_hash"
                    length="full"
                    icon
                  />
                </AppDefinition>
              </AppTableCell>
            </AppTableRow>
            <AppTableRow extend>
              <AppTableCell extend>
                <AppDefinition
                  type="list"
                  title="Pow"
                >
                  <FormatPow :value="data.pow" />
                </AppDefinition>
              </AppTableCell>
            </AppTableRow>
          </AppTableAccordion>
        </AppTableBody>
      </AppTable>
    </AppPanel>
  </div>
</template>

<script>
import AppTable from '../../components/appTable'
import AppTableRow from '../../components/appTableRow'
import AppTableCell from '../../components/appTableCell'
import AppTableHeader from '../../components/appTableHeader'
import AppTableBody from '../../components/appTableBody'
import AppTableAccordion from '../../components/appTableAccordion'
import AppTableRowColumn from '../../components/appTableRowColumn'
import AppDefinition from '../../components/appDefinition'
import AppPanel from '../../components/appPanel'
import BlockHeight from '../../components/blockHeight'
import LabelType from '../../components/labelType'
import Age from '../../components/age'
// import TimeStamp from '../../components/timeStamp'
// import FormatAeUnit from '../../components/formatAeUnit'
import FormatAddress from '../../components/formatAddress'
import Account from '../../components/account'
import Confirmations from '../../components/confirmations'
import FormatPow from '../../components/formatPow'

export default {
  name: 'GenerationDetails',
  components: {
    FormatPow,
    BlockHeight,
    AppTable,
    AppTableRow,
    AppTableCell,
    AppTableHeader,
    AppTableBody,
    AppTableRowColumn,
    AppDefinition,
    AppPanel,
    Account,
    LabelType,
    AppTableAccordion,
    // TimeStamp,
    Age,
    // FormatAeUnit,
    FormatAddress,
    Confirmations
  },
  props: {
    data: {
      type: Object,
      default: undefined
    },
    dynamicData: {
      type: Number,
      default: undefined
    }
  },
  computed: {
    microBlocks () {
      return this.data.micro_blocks ? Object.values(this.data.micro_blocks).length : 0
    }
  }
}
</script>

<style scoped lang="scss">
  .block-height-wrapper {
    display: flex;
    flex-direction: column;
    @media (min-width: 550px) {
      flex-direction: row;
      align-items: center;
    }
  }
</style>
