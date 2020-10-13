<template>
  <div class="transaction">
    <div class="transaction-main-info">
      <div class="transaction-main-info-inner">
        <nuxt-link :to="`/transactions/${transaction.hash}`">
          <div class="transaction-label">
            <LabelType
              :title="transaction | transformTxType"
              fill="red"
            />
          </div>
        </nuxt-link>
      </div>
      <div class="transaction-main-info-inner accounts">
        <AccountGroup>
          <Account
            v-if="transaction.tx.sender_id"
            :value="transaction.tx.sender_id"
            title="Sender"
            icon
          />
          <Account
            v-if="transaction.tx.oracle_id"
            :value="transaction.tx.oracle_id"
            title="oracle"
            icon
          />
        </AccountGroup>
      </div>
    </div>
    <div class="transaction-type-info">
      <div class="transaction-type-info-item">
        <AppDefinition
          title="Block Height"
        >
          <nuxt-link :to="`/generations/${transaction.block_height}`">
            {{ transaction.block_height }}
          </nuxt-link>
        </AppDefinition>
        <AppDefinition
          v-if="transaction.tx.fee"
          title="tx fee"
        >
          <FormatAeUnit
            :value="transaction.tx.fee"
          />
        </AppDefinition>
        <AppDefinition
          v-if="transaction.tx.nonce"
          title="nonce"
        >
          {{ transaction.tx.nonce }}
        </AppDefinition>
      </div>
      <div class="transaction-type-info-item">
        <AppDefinition
          v-if="transaction.tx.query"
          title="Query"
        >
          {{ transaction.tx.query }}
        </AppDefinition>
        <AppDefinition
          v-if="transaction.tx.query_fee"
          title="Query fee"
        >
          <FormatAeUnit
            :value="transaction.tx.query_fee"
          />
        </AppDefinition>
        <AppDefinition
          v-if="transaction.time"
          title="Time"
          class="tx-time"
        >
          {{ transaction.time | timestampToUTC }}
        </AppDefinition>
      </div>
    </div>
  </div>
</template>
<script>
import AppDefinition from '../../../components/appDefinition'
import FormatAeUnit from '../../../components/formatAeUnit'
import AccountGroup from '../../../components/accountGroup'
import Account from '../../../components/account'
import LabelType from '../../../components/labelType'
import timestampToUTC from '../../../plugins/filters/timestampToUTC'
import { transformTxType } from '../../../store/utils'

export default {
  name: 'OracleQueryTx',
  components: {
    LabelType,
    AppDefinition,
    FormatAeUnit,
    AccountGroup,
    Account
  },
  filters: {
    timestampToUTC,
    transformTxType
  },
  props: {
    transaction: {
      type: Object,
      required: true
    }
  }
}
</script>
