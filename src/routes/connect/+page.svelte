<script>
  import { onMount, onDestroy } from 'svelte'
  import { goto } from '$app/navigation'
  import {
    mdiCellphone,
    mdiTelevisionClassic
  } from '@mdi/js'
  import Icon from 'mdi-svelte'
  import { getHostIp } from '$lib/convex.js'
  import {
    connected,
    address,
    password,
    errorMessage,
    autoConnecting,
    connect
  } from '$lib/connection.js'

  export let data

  // Redirect to main page once connected
  $: if ($connected) goto('/')

  // Avatar state
  let showUserMenu = false
  let showDetails = false

  $: userName = data.user?.name || ''
  $: userEmail = data.user?.email || ''
  $: initials = userName
    ? userName.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2)
    : userEmail
      ? userEmail[0].toUpperCase()
      : '?'
  $: statusText = $autoConnecting
    ? 'Searching for OBS...'
    : $errorMessage
      ? ''
      : 'Ready to connect'

  function toggleUserMenu () {
    showUserMenu = !showUserMenu
  }

  function toggleDetails () {
    showDetails = !showDetails
  }

  function handleClickOutside (event) {
    if (showUserMenu && !event.target.closest('.avatar-wrapper')) {
      showUserMenu = false
    }
  }

  async function handleConnect () {
    await connect()
  }

  onMount(async () => {
    document.addEventListener('click', handleClickOutside, true)

    // Auto-connect via Convex
    autoConnecting.set(true)
    try {
      const hostIp = await getHostIp()
      if (hostIp) {
        address.set(`ws://${hostIp}:4455`)
        password.set(data.obsPassword)
        await connect()
        autoConnecting.set(false)
        return
      }
    } catch (e) {
      console.warn('Auto-connect failed, falling back to manual:', e)
    }
    autoConnecting.set(false)

    // Check URL hash
    if (document.location.hash !== '') {
      let addr = document.location.hash.slice(1)
      if (addr.includes('#')) {
        const [a, p] = addr.split('#')
        addr = a
        password.set(p)
      }
      address.set(addr)
      await connect()
    }

    // Restore saved address
    if (window.localStorage.getItem('obsAddress')) {
      address.set(window.localStorage.getItem('obsAddress'))
    }
  })

  onDestroy(() => {
    if (typeof document !== 'undefined') {
      document.removeEventListener('click', handleClickOutside, true)
    }
  })
</script>

<svelte:head>
  <title>Broadcast Controller</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
  <link href="https://fonts.googleapis.com/css2?family=Libre+Baskerville:wght@400;700&display=swap" rel="stylesheet" />
</svelte:head>

<div class="connect-page">
  <!-- User avatar -->
  {#if data.user}
    <div class="avatar-wrapper">
      <button class="avatar" on:click={toggleUserMenu}>{initials}</button>
      {#if showUserMenu}
        <div class="avatar-menu">
          {#if userName}<div class="avatar-menu-name">{userName}</div>{/if}
          <div class="avatar-menu-email">{userEmail}</div>
          <hr />
          <a href="/auth/logout">Sign out</a>
        </div>
      {/if}
    </div>
  {/if}

  <h1 class="connect-title">Broadcast Controller</h1>

  <!-- Vertical connection visual -->
  <div class="connect-visual">
    <div class="endpoint-card">
      <div class="endpoint-icon">
        <Icon path={mdiCellphone} size="3rem" />
      </div>
    </div>
    <span class="endpoint-label">Controller</span>

    <div class="signal-bridge">
      <div class="signal-track"></div>
      <div class="signal-dot dot-1"></div>
      <div class="signal-dot dot-2"></div>
      <div class="signal-dot dot-3"></div>
    </div>

    <div class="endpoint-card">
      <div class="endpoint-icon">
        <Icon path={mdiTelevisionClassic} size="3rem" />
      </div>
    </div>
    <span class="endpoint-label">OBS Studio</span>
  </div>

  {#if statusText}
    <p class="connect-status">{statusText}</p>
  {/if}

  {#if $errorMessage}
    <div class="connect-error">{$errorMessage}</div>
  {/if}

  <button class="connect-button" on:click={handleConnect}>Connect</button>

  <button class="details-toggle" on:click={toggleDetails}>
    Connection Details {showDetails ? '\u25B4' : '\u25BE'}
  </button>

  {#if showDetails}
    <div class="details-form">
      <div class="details-field">
        <label for="host" class="details-label">Host</label>
        <input
          id="host"
          bind:value={$address}
          class="details-input"
          type="text"
          placeholder="ws://localhost:4455"
        />
      </div>
      <div class="details-field">
        <label for="password" class="details-label">Password</label>
        <input
          id="password"
          bind:value={$password}
          class="details-input"
          type="password"
          autocomplete="current-password"
          placeholder="Enter password"
        />
      </div>
    </div>
  {/if}
</div>

<style>
  /* ── Page ── */
  .connect-page {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    background: radial-gradient(ellipse at top, #3f4559 0%, #353B4B 50%, #2e3344 100%);
    padding: 2rem 1rem;
    position: relative;
    font-family: 'Libre Baskerville', Georgia, serif;
  }

  /* ── Avatar ── */
  .avatar-wrapper {
    position: absolute;
    top: 1.25rem;
    right: 1.25rem;
  }

  .avatar {
    width: 42px;
    height: 42px;
    border-radius: 50%;
    background: #DFBC0C;
    color: #1a1e28;
    border: none;
    font-size: 0.85rem;
    font-weight: 700;
    font-family: 'Libre Baskerville', Georgia, serif;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: transform 0.15s;
  }

  .avatar:hover {
    transform: scale(1.08);
  }

  .avatar-menu {
    position: absolute;
    top: calc(100% + 0.5rem);
    right: 0;
    min-width: 200px;
    background: #2a2f3d;
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 10px;
    padding: 0.75rem 1rem;
    z-index: 100;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
    font-family: 'Libre Baskerville', Georgia, serif;
  }

  .avatar-menu-name {
    color: #f0f0f0;
    font-size: 0.9rem;
    font-weight: 700;
  }

  .avatar-menu-email {
    color: #999;
    font-size: 0.75rem;
    margin-top: 0.15rem;
  }

  .avatar-menu hr {
    border: none;
    border-top: 1px solid rgba(255, 255, 255, 0.08);
    margin: 0.6rem 0;
  }

  .avatar-menu a {
    color: #ff7b7b;
    font-size: 0.8rem;
    text-decoration: none;
  }

  .avatar-menu a:hover {
    text-decoration: underline;
  }

  /* ── Title ── */
  .connect-title {
    color: #f0f0f0;
    font-size: 2rem;
    font-weight: 700;
    margin: 0 0 2.5rem;
    letter-spacing: 0.01em;
  }

  /* ── Vertical Connection Visual ── */
  .connect-visual {
    display: flex;
    flex-direction: column;
    align-items: center;
    margin-bottom: 2rem;
  }

  .endpoint-card {
    width: 130px;
    height: 130px;
    border-radius: 24px;
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.08);
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow:
      0 2px 16px rgba(0, 0, 0, 0.2),
      inset 0 1px 0 rgba(255, 255, 255, 0.04);
  }

  .endpoint-icon {
    color: #d0d4e0;
  }

  .endpoint-label {
    font-size: 0.8rem;
    color: #777;
    margin-top: 0.65rem;
    letter-spacing: 0.04em;
  }

  /* ── Signal Bridge (vertical) ── */
  .signal-bridge {
    position: relative;
    width: 4px;
    height: 80px;
    margin: 1rem 0;
  }

  .signal-track {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: repeating-linear-gradient(
      180deg,
      rgba(223, 188, 12, 0.18) 0px,
      rgba(223, 188, 12, 0.18) 6px,
      transparent 6px,
      transparent 12px
    );
    border-radius: 2px;
  }

  .signal-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #DFBC0C;
    position: absolute;
    left: 50%;
    transform: translateX(-50%);
    animation: travel-down 2.4s ease-in-out infinite;
    box-shadow: 0 0 8px rgba(223, 188, 12, 0.5);
  }

  .dot-1 { animation-delay: 0s; }
  .dot-2 { animation-delay: 0.8s; }
  .dot-3 { animation-delay: 1.6s; }

  @keyframes travel-down {
    0% {
      top: -4px;
      opacity: 0;
    }
    10% {
      opacity: 1;
    }
    90% {
      opacity: 1;
    }
    100% {
      top: calc(100% - 4px);
      opacity: 0;
    }
  }

  /* ── Status & Error ── */
  .connect-status {
    color: #999;
    font-size: 0.9rem;
    margin: 0 0 1rem;
  }

  .connect-error {
    width: 100%;
    max-width: 320px;
    background: rgba(255, 70, 70, 0.10);
    border: 1px solid rgba(255, 70, 70, 0.22);
    color: #ff9999;
    padding: 0.75rem 1rem;
    border-radius: 10px;
    font-size: 0.85rem;
    margin-bottom: 1.25rem;
    text-align: center;
    box-sizing: border-box;
  }

  /* ── Connect Button ── */
  .connect-button {
    width: 100%;
    max-width: 320px;
    padding: 0.85rem;
    background: #DFBC0C;
    color: #1a1e28;
    border: none;
    border-radius: 10px;
    font-size: 1rem;
    font-weight: 700;
    font-family: 'Libre Baskerville', Georgia, serif;
    cursor: pointer;
    margin-bottom: 1.5rem;
    transition: background 0.2s, transform 0.1s;
    box-sizing: border-box;
  }

  .connect-button:hover {
    background: #c9a90b;
  }

  .connect-button:active {
    transform: scale(0.98);
  }

  /* ── Connection Details ── */
  .details-toggle {
    background: none;
    border: none;
    color: #777;
    font-size: 0.85rem;
    font-family: 'Libre Baskerville', Georgia, serif;
    cursor: pointer;
    padding: 0.5rem 1rem;
    transition: color 0.2s;
    margin-bottom: 0.5rem;
  }

  .details-toggle:hover {
    color: #bbb;
  }

  .details-form {
    width: 100%;
    max-width: 320px;
    margin-top: 0.5rem;
  }

  .details-field {
    margin-bottom: 1.25rem;
  }

  .details-label {
    display: block;
    color: #999;
    font-size: 0.85rem;
    margin-bottom: 0.5rem;
  }

  .details-input {
    width: 100%;
    padding: 0.75rem 1rem;
    background: rgba(0, 0, 0, 0.25);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 10px;
    color: #f0f0f0;
    font-size: 0.95rem;
    font-family: 'Libre Baskerville', Georgia, serif;
    transition: border-color 0.2s;
    box-sizing: border-box;
  }

  .details-input::placeholder {
    color: rgba(255, 255, 255, 0.25);
  }

  .details-input:focus {
    outline: none;
    border-color: #DFBC0C;
  }
</style>
