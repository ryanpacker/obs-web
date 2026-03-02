<script>
  import { onMount } from 'svelte'
  import { browser } from '$app/environment'

  export let data

  const LOCAL_PORT = 8080
  const STALE_MINUTES = 30

  $: host = data.host
  $: ipAddress = host?.ipAddress
  $: interfaceName = host?.interfaceName || ''
  $: updatedAt = host?.updatedAt
  $: isRecent = updatedAt && (Date.now() - updatedAt) < STALE_MINUTES * 60 * 1000
  $: localUrl = ipAddress ? `http://${ipAddress}:${LOCAL_PORT}` : null
  $: timeAgo = updatedAt ? formatTimeAgo(updatedAt) : ''

  let redirecting = false
  let failed = false

  function formatTimeAgo (ts) {
    const seconds = Math.floor((Date.now() - ts) / 1000)
    if (seconds < 60) return 'just now'
    const minutes = Math.floor(seconds / 60)
    if (minutes < 60) return `${minutes}m ago`
    const hours = Math.floor(minutes / 60)
    return `${hours}h ago`
  }

  onMount(() => {
    if (localUrl && isRecent) {
      redirecting = true
      // Brief pause so the user sees what's happening
      setTimeout(() => {
        window.location.href = localUrl
      }, 1500)
    }
  })
</script>

<svelte:head>
  <title>Local OBS Connection</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
  <link href="https://fonts.googleapis.com/css2?family=Libre+Baskerville:wght@400;700&display=swap" rel="stylesheet" />
</svelte:head>

<div class="local-page">
  {#if redirecting}
    <div class="status-card">
      <div class="spinner"></div>
      <h2>Connecting to local OBS</h2>
      <p class="subtitle">Redirecting to <strong>{localUrl}</strong></p>
      <p class="detail">{interfaceName} &middot; last seen {timeAgo}</p>
    </div>

  {:else if localUrl && isRecent}
    <div class="status-card">
      <div class="dot dot-ok"></div>
      <h2>OBS Broadcast Computer Found</h2>
      <p class="subtitle">{interfaceName}</p>
      <p class="detail">Last seen {timeAgo}</p>
      <a href={localUrl} class="connect-btn">Connect to {localUrl}</a>
    </div>

  {:else if localUrl && !isRecent}
    <div class="status-card">
      <div class="dot dot-stale"></div>
      <h2>OBS Broadcast Computer Offline</h2>
      <p class="subtitle">Last known address: <strong>{ipAddress}</strong></p>
      <p class="detail">{interfaceName} &middot; last seen {timeAgo}</p>
      <p class="message">
        OBS Web hasn't checked in for over {STALE_MINUTES} minutes.
        Make sure OBS Launcher is running on the broadcast computer.
      </p>
      <a href={localUrl} class="connect-btn secondary">Try connecting anyway</a>
    </div>

  {:else}
    <div class="status-card">
      <div class="dot dot-error"></div>
      <h2>No OBS Broadcast Computer Found</h2>
      <p class="message">
        OBS Launcher hasn't published a host address yet.
        Make sure OBS Launcher is running on the broadcast computer.
      </p>
    </div>
  {/if}
</div>

<style>
  .local-page {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: radial-gradient(ellipse at top, #3f4559 0%, #353B4B 50%, #2e3344 100%);
    padding: 2rem 1rem;
    font-family: 'Libre Baskerville', Georgia, serif;
  }

  .status-card {
    text-align: center;
    max-width: 420px;
    width: 100%;
  }

  h2 {
    color: #f0f0f0;
    font-size: 1.4rem;
    font-weight: 700;
    margin: 0 0 0.5rem;
  }

  .subtitle {
    color: #bbb;
    font-size: 0.9rem;
    margin: 0 0 0.25rem;
  }

  .subtitle strong {
    color: #d0d4e0;
  }

  .detail {
    color: #777;
    font-size: 0.75rem;
    margin: 0 0 1.5rem;
  }

  .message {
    color: #999;
    font-size: 0.85rem;
    line-height: 1.5;
    margin: 0 0 1.5rem;
  }

  /* ── Status dots ── */
  .dot {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    margin: 0 auto 1.25rem;
  }

  .dot-ok {
    background: #48c774;
    box-shadow: 0 0 10px rgba(72, 199, 116, 0.4);
  }

  .dot-stale {
    background: #DFBC0C;
    box-shadow: 0 0 10px rgba(223, 188, 12, 0.4);
  }

  .dot-error {
    background: #f14668;
    box-shadow: 0 0 10px rgba(241, 70, 104, 0.4);
  }

  /* ── Spinner ── */
  .spinner {
    width: 32px;
    height: 32px;
    border: 3px solid rgba(255, 255, 255, 0.1);
    border-top-color: #DFBC0C;
    border-radius: 50%;
    margin: 0 auto 1.25rem;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  /* ── Connect button ── */
  .connect-btn {
    display: inline-block;
    padding: 0.75rem 1.5rem;
    background: #DFBC0C;
    color: #1a1e28;
    border-radius: 10px;
    font-size: 0.9rem;
    font-weight: 700;
    font-family: 'Libre Baskerville', Georgia, serif;
    text-decoration: none;
    transition: background 0.2s, transform 0.1s;
  }

  .connect-btn:hover {
    background: #c9a90b;
  }

  .connect-btn:active {
    transform: scale(0.98);
  }

  .connect-btn.secondary {
    background: rgba(255, 255, 255, 0.06);
    color: #999;
    border: 1px solid rgba(255, 255, 255, 0.1);
  }

  .connect-btn.secondary:hover {
    background: rgba(255, 255, 255, 0.1);
    color: #d0d4e0;
  }
</style>
