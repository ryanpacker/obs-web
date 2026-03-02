import { writable, get } from 'svelte/store'

export const connected = writable(false)
export const address = writable('')
export const password = writable('')
export const errorMessage = writable('')
export const autoConnecting = writable(false)

let _obs = null

/**
 * Call once from the layout to wire up OBS event handlers
 * that persist across route navigation.
 */
export function setupConnectionState (obs) {
  if (_obs) return
  _obs = obs

  obs.on('Identified', () => {
    connected.set(true)
    errorMessage.set('')
    const addr = get(address)
    if (typeof document !== 'undefined') {
      document.location.hash = addr
    }
  })

  obs.on('ConnectionClosed', () => {
    connected.set(false)
    if (typeof window !== 'undefined') {
      window.history.pushState(
        '',
        document.title,
        window.location.pathname + window.location.search
      )
    }
    console.log('Connection closed')
  })

  obs.on('ConnectionError', (e) => {
    const code = e?.code
    const msg = e?.message || ''
    if (code === 4008 || msg.toLowerCase().includes('auth')) {
      errorMessage.set('Authentication failed \u2014 check your password')
    } else {
      errorMessage.set(msg || 'Connection error')
    }
    connected.set(false)
  })
}

export async function connect () {
  let addr = get(address) || 'ws://localhost:4455'
  if (addr.indexOf('://') === -1) {
    const secure = typeof location !== 'undefined' &&
      (location.protocol === 'https:' || addr.endsWith(':443'))
    addr = (secure ? 'wss://' : 'ws://') + addr
  }
  address.set(addr)

  console.log('Connecting to:', addr, '- using password:', get(password))
  await disconnect()
  try {
    await _obs.connect(addr, get(password))
    if (typeof window !== 'undefined') {
      window.localStorage.setItem('obsAddress', addr)
    }
  } catch (e) {
    console.log(e)
    const code = e?.code
    const msg = e?.message || ''
    if (code === 4008 || msg.toLowerCase().includes('auth')) {
      errorMessage.set('Authentication failed \u2014 check your password')
    } else if (code === 1006 || msg.toLowerCase().includes('refused')) {
      errorMessage.set('Unable to reach OBS at ' + addr)
    } else {
      errorMessage.set(msg || 'Connection failed')
    }
  }
}

export async function disconnect () {
  if (!_obs) return
  await _obs.disconnect()
  connected.set(false)
}
