<template>
  <div>
    <AppPanel>
      <AppTable details>
        <AppTableHeader>
          <AppTableRow>
            <AppTableRowColumn width="large">
              <AppTableCell extend>
                <div class="block-height-wrapper">
                  <div>
                    <LabelType
                      title="Block Height"
                      fill="black"
                    />
                  </div>
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
        </AppTableHeader>
        <AppTableAccordion>
          <AppTableHeader>
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
                    {{ data.micro_blocks.length }}
                  </AppDefinition>
                </AppTableCell>
              </AppTableRowColumn>
            </AppTableRow>
          </AppTableHeader>
          <AppTableBody>
            <AppTableRow extend>
              <AppTableCell extend>
                <AppDefinition
                  type="list"
                  title="Hash"
                >
                  <FormatAddress
                    :value="data.hash"
                    length="full"
                  />
                </AppDefinition>
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
            <AppTableRow extend>
              <AppTableCell extend>
                <AppDefinition
                  type="list"
                  title="Miner"
                >
                  <FormatAddress
                    :value="data.miner"
                    length="full"
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
                  />
                </AppDefinition>
              </AppTableCell>
            </AppTableRow>
            <AppTableRow
              extend
            >
              <AppTableCell extend>
                <AppDefinition
                  type="list"
                  title="Prev key hash"
                >
                  <FormatAddress
                    :value="data.prev_key_hash"
                    length="full"
                  />
                </AppDefinition>
              </AppTableCell>
            </AppTableRow>
            <AppTableRow extend>
              <AppTableCell extend>
                <AppDefinition
                  type="list"
                  title="State hash"
                >
                  <FormatAddress
                    :value="data.state_hash"
                    length="full"
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
          </AppTableBody>
        </AppTableAccordion>
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
    Age,
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
    },
    large: {
      type: Boolean,
      default: true
    },
    small: {
      type: Boolean,
      default: false
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
