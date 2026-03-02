<script>
  import { onMount, onDestroy } from 'svelte'

  export let data

  let showUserMenu = false
  let downloadState = 'idle' // idle | downloading | complete | error
  let errorText = ''

  $: userName = data.user?.name || ''
  $: userEmail = data.user?.email || ''
  $: initials = userName
    ? userName.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2)
    : userEmail
      ? userEmail[0].toUpperCase()
      : '?'

  function toggleUserMenu () {
    showUserMenu = !showUserMenu
  }

  function handleClickOutside (event) {
    if (showUserMenu && !event.target.closest('.avatar-wrapper')) {
      showUserMenu = false
    }
  }

  async function handleDownload () {
    downloadState = 'downloading'
    errorText = ''
    try {
      const res = await fetch('/api/download/bundle')
      if (!res.ok) {
        throw new Error(res.status === 404 ? 'Bundle not available yet' : 'Download failed')
      }
      const blob = await res.blob()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = 'obs-web-installer.zip'
      document.body.appendChild(a)
      a.click()
      a.remove()
      URL.revokeObjectURL(url)
      downloadState = 'complete'
    } catch (e) {
      errorText = e.message
      downloadState = 'error'
    }
  }

  onMount(() => {
    document.addEventListener('click', handleClickOutside, true)
  })

  onDestroy(() => {
    if (typeof document !== 'undefined') {
      document.removeEventListener('click', handleClickOutside, true)
    }
  })
</script>

<svelte:head>
  <title>OBS Remote Setup</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
  <link href="https://fonts.googleapis.com/css2?family=Libre+Baskerville:wght@400;700&display=swap" rel="stylesheet" />
</svelte:head>

<div class="download-page">
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

  <div class="content-card">
    <h1 class="page-title">OBS Remote Setup</h1>
    <p class="page-subtitle">Everything you need to control OBS from your phone</p>

    <div class="section">
      <h2 class="section-title">What's included</h2>
      <ul class="feature-list">
        <li>
          <span class="feature-icon">&#9654;</span>
          <span><strong>OBS Launcher</strong> &mdash; desktop app to start everything with one click</span>
        </li>
        <li>
          <span class="feature-icon">&#9654;</span>
          <span><strong>Local obs-web server</strong> &mdash; runs on your Mac so phones can connect over Wi-Fi</span>
        </li>
        <li>
          <span class="feature-icon">&#9654;</span>
          <span><strong>Companion service</strong> &mdash; automatically discovers your Mac's IP address</span>
        </li>
      </ul>
    </div>

    <div class="section">
      <h2 class="section-title">Requirements</h2>
      <ul class="req-list">
        <li>macOS (Apple Silicon or Intel)</li>
        <li>OBS Studio installed</li>
      </ul>
    </div>

    <!-- Download button -->
    {#if downloadState === 'idle' || downloadState === 'error'}
      <button class="download-btn" on:click={handleDownload}>
        Download Installer
      </button>
    {:else if downloadState === 'downloading'}
      <button class="download-btn downloading" disabled>
        <span class="spinner"></span>
        Downloading&hellip;
      </button>
    {:else if downloadState === 'complete'}
      <button class="download-btn complete" disabled>
        <span class="checkmark">&#10003;</span>
        Downloaded
      </button>
    {/if}

    {#if errorText}
      <div class="error-msg">{errorText}</div>
    {/if}

    <!-- Post-download instructions (shown after download) -->
    {#if downloadState === 'complete'}
      <div class="post-download">
        <h2 class="section-title">Next steps</h2>
        <ol class="steps-list">
          <li>Open the downloaded <strong>obs-web-installer.zip</strong> to extract it</li>
          <li>Open <strong>Terminal</strong> and run:
            <code class="command">cd ~/Downloads/obs-web-installer && bash install.sh</code>
          </li>
          <li>Follow the prompts (it will install Node.js if needed)</li>
          <li>Find <strong>OBS Launcher</strong> on your Desktop and double-click to start</li>
        </ol>
      </div>
    {/if}
  </div>
</div>

<style>
  /* ── Page ── */
  .download-page {
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

  /* ── Content Card ── */
  .content-card {
    max-width: 480px;
    width: 100%;
    text-align: center;
  }

  .page-title {
    color: #f0f0f0;
    font-size: 2rem;
    font-weight: 700;
    margin: 0 0 0.5rem;
    letter-spacing: 0.01em;
  }

  .page-subtitle {
    color: #999;
    font-size: 0.9rem;
    margin: 0 0 2.5rem;
  }

  /* ── Sections ── */
  .section {
    text-align: left;
    margin-bottom: 2rem;
  }

  .section-title {
    color: #DFBC0C;
    font-size: 0.85rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    margin: 0 0 0.75rem;
  }

  .feature-list {
    list-style: none;
    padding: 0;
    margin: 0;
  }

  .feature-list li {
    display: flex;
    align-items: flex-start;
    gap: 0.6rem;
    color: #ccc;
    font-size: 0.85rem;
    margin-bottom: 0.6rem;
    line-height: 1.5;
  }

  .feature-list li strong {
    color: #f0f0f0;
  }

  .feature-icon {
    color: #DFBC0C;
    font-size: 0.6rem;
    margin-top: 0.35rem;
    flex-shrink: 0;
  }

  .req-list {
    list-style: none;
    padding: 0;
    margin: 0;
  }

  .req-list li {
    color: #ccc;
    font-size: 0.85rem;
    margin-bottom: 0.4rem;
    padding-left: 1.2rem;
    position: relative;
  }

  .req-list li::before {
    content: '\2022';
    color: #777;
    position: absolute;
    left: 0;
  }

  /* ── Download Button ── */
  .download-btn {
    width: 100%;
    padding: 0.85rem;
    background: #DFBC0C;
    color: #1a1e28;
    border: none;
    border-radius: 10px;
    font-size: 1rem;
    font-weight: 700;
    font-family: 'Libre Baskerville', Georgia, serif;
    cursor: pointer;
    margin-bottom: 1rem;
    transition: background 0.2s, transform 0.1s;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
  }

  .download-btn:hover:not(:disabled) {
    background: #c9a90b;
  }

  .download-btn:active:not(:disabled) {
    transform: scale(0.98);
  }

  .download-btn.downloading {
    background: rgba(223, 188, 12, 0.6);
    cursor: wait;
  }

  .download-btn.complete {
    background: #48c774;
    color: #fff;
    cursor: default;
  }

  .checkmark {
    font-size: 1.1rem;
  }

  /* ── Spinner ── */
  .spinner {
    width: 18px;
    height: 18px;
    border: 2.5px solid rgba(26, 30, 40, 0.25);
    border-top-color: #1a1e28;
    border-radius: 50%;
    animation: spin 0.7s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  /* ── Error ── */
  .error-msg {
    background: rgba(255, 70, 70, 0.10);
    border: 1px solid rgba(255, 70, 70, 0.22);
    color: #ff9999;
    padding: 0.75rem 1rem;
    border-radius: 10px;
    font-size: 0.85rem;
    margin-bottom: 1rem;
    text-align: center;
  }

  /* ── Post-download Instructions ── */
  .post-download {
    text-align: left;
    margin-top: 1.5rem;
    padding-top: 1.5rem;
    border-top: 1px solid rgba(255, 255, 255, 0.08);
  }

  .steps-list {
    padding: 0 0 0 1.25rem;
    margin: 0;
  }

  .steps-list li {
    color: #ccc;
    font-size: 0.85rem;
    margin-bottom: 0.75rem;
    line-height: 1.5;
  }

  .steps-list li strong {
    color: #f0f0f0;
  }

  .command {
    display: block;
    margin-top: 0.4rem;
    background: rgba(0, 0, 0, 0.35);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 6px;
    padding: 0.5rem 0.75rem;
    font-family: 'SF Mono', 'Menlo', monospace;
    font-size: 0.75rem;
    color: #DFBC0C;
    word-break: break-all;
  }
</style>
