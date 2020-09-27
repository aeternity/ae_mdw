import Vue from 'vue'
/**
 * A Vue Directive to clean up the empty
 * spaces (whitespace, new line, tabs) on copy event
 *
 * @example <div v-remove-spaces-on-copy></div>
 */
Vue.directive('remove-spaces-on-copy', {
  inserted: el => el.addEventListener('copy', (event) => {
    event.clipboardData.setData('text/plain', getSelection().toString().replace(/\s/g, ''))
    event.preventDefault()
  })
})
