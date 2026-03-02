<script>
  /* eslint-env browser */
  const OBS_WEBSOCKET_LATEST_VERSION = '5.0.1' // https://api.github.com/repos/Palakis/obs-websocket/releases/latest

  // Imports
  import { onMount, onDestroy } from 'svelte'
  import { goto } from '$app/navigation'
  import { browser } from '$app/environment'
  import {
    mdiSquareRoundedBadge,
    mdiSquareRoundedBadgeOutline,
    mdiImageEdit,
    mdiImageEditOutline,
    mdiFullscreen,
    mdiFullscreenExit,
    mdiBorderVertical,
    mdiArrowSplitHorizontal,
    mdiAccessPoint,
    mdiAccessPointOff,
    mdiRecord,
    mdiStop,
    mdiPause,
    mdiPlayPause,
    mdiConnection,
    mdiCameraOff,
    mdiCamera,
    mdiMotionPlayOutline,
    mdiMotionPlay,
    mdiContentSaveMoveOutline,
    mdiContentSaveCheckOutline,
    mdiMenu
  } from '@mdi/js'
  import Icon from 'mdi-svelte'
  import { compareVersions } from 'compare-versions'

  import { obs, sendCommand } from '../obs.js'
  import ProgramPreview from '../ProgramPreview.svelte'
  import SceneSwitcher from '../SceneSwitcher.svelte'
  import SourceSwitcher from '../SourceSwitcher.svelte'
  import ProfileSelect from '../ProfileSelect.svelte'
  import SceneCollectionSelect from '../SceneCollectionSelect.svelte'
  import { connected, disconnect as disconnectObs } from '$lib/connection.js'

  export let data

  // Redirect to /connect when not connected
  $: if (browser && !$connected) goto('/connect')

  // Avatar state
  let showUserMenu = false
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

  // Mobile menu state
  let mobileMenuOpen = false

  async function setupConnectedUI () {
    console.log('Setting up connected UI')
    const data = await sendCommand('GetVersion')
    const version = data.obsWebSocketVersion || ''
    console.log('OBS-websocket version:', version)
    if (compareVersions(version, OBS_WEBSOCKET_LATEST_VERSION) < 0) {
      alert(
        'You are running an outdated OBS-websocket (version ' +
          version +
          '), please upgrade to the latest version for full compatibility.'
      )
    }
    if (
      data.supportedImageFormats.includes('webp') &&
      document
        .createElement('canvas')
        .toDataURL('image/webp')
        .indexOf('data:image/webp') === 0
    ) {
      imageFormat = 'webp'
    }
    clearInterval(heartbeatInterval)
    heartbeatInterval = setInterval(async () => {
      const stats = await sendCommand('GetStats')
      const streaming = await sendCommand('GetStreamStatus')
      const recording = await sendCommand('GetRecordStatus')
      heartbeat = { stats, streaming, recording }
    }, 1000)
    isStudioMode =
      (await sendCommand('GetStudioModeEnabled')).studioModeEnabled || false
    isVirtualCamActive =
      (await sendCommand('GetVirtualCamStatus')).outputActive || false
  }

  onMount(async () => {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/service-worker.js')
    }

    // Request screen wakelock
    if ('wakeLock' in navigator) {
      try {
        await navigator.wakeLock.request('screen')
        document.addEventListener('visibilitychange', async () => {
          if (document.visibilityState === 'visible') {
            await navigator.wakeLock.request('screen')
          }
        })
      } catch (e) {}
    }

    // Listen for fullscreen changes
    document.addEventListener('fullscreenchange', () => {
      isFullScreen = document.fullscreenElement
    })

    document.addEventListener('webkitfullscreenchange', () => {
      isFullScreen = document.webkitFullscreenElement
    })

    document.addEventListener('msfullscreenchange', () => {
      isFullScreen = document.msFullscreenElement
    })

    // Avatar click outside
    document.addEventListener('click', handleClickOutside, true)

    // If already connected (navigated from /connect), set up UI
    if ($connected) {
      await setupConnectedUI()
    }

    // Handle reconnection while on this page
    const onIdentified = async () => {
      await setupConnectedUI()
    }

    const onVirtualcam = (data) => {
      console.log('VirtualcamStateChanged', data.outputActive)
      isVirtualCamActive = data && data.outputActive
    }

    const onStudioMode = (data) => {
      console.log('StudioModeStateChanged', data.studioModeEnabled)
      isStudioMode = data && data.studioModeEnabled
    }

    const onReplayBuffer = (data) => {
      console.log('ReplayBufferStateChanged', data)
      isReplaying = data && data.outputActive
    }

    obs.on('Identified', onIdentified)
    obs.on('VirtualcamStateChanged', onVirtualcam)
    obs.on('StudioModeStateChanged', onStudioMode)
    obs.on('ReplayBufferStateChanged', onReplayBuffer)

    window.sendCommand = sendCommand

    return () => {
      obs.off('Identified', onIdentified)
      obs.off('VirtualcamStateChanged', onVirtualcam)
      obs.off('StudioModeStateChanged', onStudioMode)
      obs.off('ReplayBufferStateChanged', onReplayBuffer)
      clearInterval(heartbeatInterval)
      document.removeEventListener('click', handleClickOutside, true)
    }
  })

  // State
  let heartbeat = {}
  let heartbeatInterval
  let isFullScreen
  let isStudioMode
  let isSceneOnTop = window.localStorage.getItem('isSceneOnTop') || false
  let isVirtualCamActive
  let isIconMode = window.localStorage.getItem('isIconMode') || false
  let isReplaying
  let editable = false
  let scenes = []
  let replayError = ''
  let imageFormat = 'jpg'
  let isSaveReplay = false
  let isSaveReplayDisabled = false

  $: isSceneOnTop
    ? window.localStorage.setItem('isSceneOnTop', 'true')
    : window.localStorage.removeItem('isSceneOnTop')

  $: isIconMode
    ? window.localStorage.setItem('isIconMode', 'true')
    : window.localStorage.removeItem('isIconMode')

  function formatTime (secs) {
    secs = Math.round(secs / 1000)
    const hours = Math.floor(secs / 3600)
    secs -= hours * 3600
    const mins = Math.floor(secs / 60)
    secs -= mins * 60
    return hours > 0
      ? `${hours}:${mins < 10 ? '0' : ''}${mins}:${secs < 10 ? '0' : ''}${secs}`
      : `${mins < 10 ? '0' : ''}${mins}:${secs < 10 ? '0' : ''}${secs}`
  }

  function toggleFullScreen () {
    if (isFullScreen) {
      if (document.exitFullscreen) {
        document.exitFullscreen()
      } else if (document.webkitExitFullscreen) {
        document.webkitExitFullscreen()
      } else if (document.msExitFullscreen) {
        document.msExitFullscreen()
      }
    } else {
      if (document.documentElement.requestFullscreen) {
        document.documentElement.requestFullscreen()
      } else if (document.documentElement.webkitRequestFullscreen) {
        document.documentElement.webkitRequestFullscreen()
      } else if (document.documentElement.msRequestFullscreen) {
        document.documentElement.msRequestFullscreen()
      }
    }
  }

  async function toggleStudioMode () {
    await sendCommand('SetStudioModeEnabled', {
      studioModeEnabled: !isStudioMode
    })
  }

  function setReplayError (message) {
    replayError = message
    setTimeout(() => {
      replayError = ''
    }, 5000)
  }

  async function toggleReplay () {
    const data = await sendCommand('ToggleReplayBuffer')
    console.debug('ToggleReplayBuffer', data.outputActive)
    if (data.outputActive === undefined) {
      setReplayError('Replay buffer is not enabled.')
    } else isReplaying = data.outputActive
  }

  async function saveReplay () {
    const data = await sendCommand('GetReplayBufferStatus')
    console.debug('GetReplayBufferStatus', data.outputActive)
    if (!data.outputActive) {
      setReplayError('Replay buffer is not enabled.')
      return
    }
    await sendCommand('SaveReplayBuffer')
    isSaveReplayDisabled = true
    isSaveReplay = true
    setTimeout(() => {
      isSaveReplay = false
      isSaveReplayDisabled = false
    }, 2500)
  }

  async function switchSceneView () {
    isSceneOnTop = !isSceneOnTop
  }

  async function startStream () {
    await sendCommand('StartStream')
  }

  async function stopStream () {
    await sendCommand('StopStream')
  }

  async function startRecording () {
    await sendCommand('StartRecord')
  }

  async function stopRecording () {
    await sendCommand('StopRecord')
  }

  async function startVirtualCam () {
    await sendCommand('StartVirtualCam')
  }

  async function stopVirtualCam () {
    await sendCommand('StopVirtualCam')
  }

  async function pauseRecording () {
    await sendCommand('PauseRecord')
  }

  async function resumeRecording () {
    await sendCommand('ResumeRecord')
  }

  async function disconnect () {
    clearInterval(heartbeatInterval)
    await disconnectObs()
  }

</script>

<svelte:head>
  <title>Broadcast Controller</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
  <link href="https://fonts.googleapis.com/css2?family=Libre+Baskerville:wght@400;700&display=swap" rel="stylesheet" />
</svelte:head>

{#if $connected}
<div class="connected-page">
  <header class="toolbar">
    <!-- Top bar: always visible -->
    <div class="toolbar-bar">
      <button
        class="toolbar-burger"
        aria-label="menu"
        aria-expanded={mobileMenuOpen}
        on:click={() => (mobileMenuOpen = !mobileMenuOpen)}
      >
        <Icon path={mdiMenu} size="1.4rem" />
      </button>

      <div class="status-pill desktop-only">
        {#if heartbeat && heartbeat.stats}
          {Math.round(heartbeat.stats.activeFps)} fps &middot; {Math.round(heartbeat.stats.cpuUsage)}% CPU &middot; {heartbeat.stats.renderSkippedFrames} skipped
        {:else}Connected{/if}
      </div>

      <!-- Desktop inline controls -->
      <div class="toolbar-inline">
        <div class="btn-group">
          {#if heartbeat && heartbeat.streaming && heartbeat.streaming.outputActive}
            <button class="tb-btn active-danger" on:click={stopStream} title="Stop Stream">
              <Icon path={mdiAccessPointOff} size="1.15rem" />
              <span class="tb-time">{formatTime(heartbeat.streaming.outputDuration)}</span>
            </button>
          {:else}
            <button class="tb-btn" on:click={startStream} title="Start Stream">
              <Icon path={mdiAccessPoint} size="1.15rem" />
            </button>
          {/if}
        </div>
        <div class="btn-group">
          {#if heartbeat && heartbeat.recording && heartbeat.recording.outputActive}
            {#if heartbeat.recording.outputPaused}
              <button class="tb-btn active-danger" on:click={resumeRecording} title="Resume Recording">
                <Icon path={mdiPlayPause} size="1.15rem" />
              </button>
            {:else}
              <button class="tb-btn active-success" on:click={pauseRecording} title="Pause Recording">
                <Icon path={mdiPause} size="1.15rem" />
              </button>
            {/if}
            <button class="tb-btn active-danger" on:click={stopRecording} title="Stop Recording">
              <Icon path={mdiStop} size="1.15rem" />
              <span class="tb-time">{formatTime(heartbeat.recording.outputDuration)}</span>
            </button>
          {:else}
            <button class="tb-btn" on:click={startRecording} title="Start Recording">
              <Icon path={mdiRecord} size="1.15rem" />
            </button>
          {/if}
        </div>
        <div class="btn-group">
          {#if isVirtualCamActive}
            <button class="tb-btn active-danger" on:click={stopVirtualCam} title="Stop Virtual Webcam">
              <Icon path={mdiCameraOff} size="1.15rem" />
            </button>
          {:else}
            <button class="tb-btn" on:click={startVirtualCam} title="Start Virtual Webcam">
              <Icon path={mdiCamera} size="1.15rem" />
            </button>
          {/if}
        </div>
        <div class="btn-group">
          <button class="tb-btn" class:active={isStudioMode} on:click={toggleStudioMode} title="Studio Mode">
            <Icon path={mdiBorderVertical} size="1.15rem" />
          </button>
          <button class="tb-btn" class:active={isSceneOnTop} on:click={switchSceneView} title="Scene on Top">
            <Icon path={mdiArrowSplitHorizontal} size="1.15rem" />
          </button>
          <button class="tb-btn" class:active={editable} on:click={() => (editable = !editable)} title="Edit Scenes">
            <Icon path={editable ? mdiImageEditOutline : mdiImageEdit} size="1.15rem" />
          </button>
          <button class="tb-btn" class:active={isIconMode} on:click={() => (isIconMode = !isIconMode)} title="Icon Mode">
            <Icon path={isIconMode ? mdiSquareRoundedBadgeOutline : mdiSquareRoundedBadge} size="1.15rem" />
          </button>
        </div>
        <div class="btn-group">
          <button class="tb-btn" class:active={isReplaying} class:active-danger={replayError} on:click={toggleReplay} title="Replay Buffer">
            <Icon path={isReplaying ? mdiMotionPlayOutline : mdiMotionPlay} size="1.15rem" />
          </button>
          <button class="tb-btn" class:active={isSaveReplay} on:click={() => { if (!isSaveReplayDisabled) { saveReplay() } isSaveReplayDisabled = !isSaveReplayDisabled }} title="Save Replay">
            <Icon path={isSaveReplay ? mdiContentSaveCheckOutline : mdiContentSaveMoveOutline} size="1.15rem" />
          </button>
        </div>
        <div class="btn-group">
          <ProfileSelect />
          <SceneCollectionSelect />
        </div>
        <div class="btn-group">
          <button class="tb-btn" on:click={disconnect} title="Disconnect">
            <Icon path={mdiConnection} size="1.15rem" />
          </button>
          <button class="tb-btn" class:active={isFullScreen} on:click={toggleFullScreen} title="Fullscreen">
            <Icon path={isFullScreen ? mdiFullscreenExit : mdiFullscreen} size="1.15rem" />
          </button>
        </div>
      </div>

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
    </div>

    <!-- Mobile dropdown panel -->
    {#if mobileMenuOpen}
      <div class="mobile-panel">
        <div class="status-pill mobile-status">
          {#if heartbeat && heartbeat.stats}
            {Math.round(heartbeat.stats.activeFps)} fps &middot; {Math.round(heartbeat.stats.cpuUsage)}% CPU &middot; {heartbeat.stats.renderSkippedFrames} skipped
          {:else}Connected{/if}
        </div>

        <div class="panel-grid">
          <!-- Streaming -->
          {#if heartbeat && heartbeat.streaming && heartbeat.streaming.outputActive}
            <button class="panel-btn active-danger" on:click={stopStream}>
              <Icon path={mdiAccessPointOff} size="1.1rem" />
              <span>Stop Stream</span>
              <span class="panel-time">{formatTime(heartbeat.streaming.outputDuration)}</span>
            </button>
          {:else}
            <button class="panel-btn" on:click={startStream}>
              <Icon path={mdiAccessPoint} size="1.1rem" />
              <span>Stream</span>
            </button>
          {/if}

          <!-- Recording -->
          {#if heartbeat && heartbeat.recording && heartbeat.recording.outputActive}
            {#if heartbeat.recording.outputPaused}
              <button class="panel-btn active-danger" on:click={resumeRecording}>
                <Icon path={mdiPlayPause} size="1.1rem" />
                <span>Resume</span>
              </button>
            {:else}
              <button class="panel-btn active-success" on:click={pauseRecording}>
                <Icon path={mdiPause} size="1.1rem" />
                <span>Pause</span>
              </button>
            {/if}
            <button class="panel-btn active-danger" on:click={stopRecording}>
              <Icon path={mdiStop} size="1.1rem" />
              <span>Stop Rec</span>
              <span class="panel-time">{formatTime(heartbeat.recording.outputDuration)}</span>
            </button>
          {:else}
            <button class="panel-btn" on:click={startRecording}>
              <Icon path={mdiRecord} size="1.1rem" />
              <span>Record</span>
            </button>
          {/if}

          <!-- Virtual cam -->
          {#if isVirtualCamActive}
            <button class="panel-btn active-danger" on:click={stopVirtualCam}>
              <Icon path={mdiCameraOff} size="1.1rem" />
              <span>Stop Cam</span>
            </button>
          {:else}
            <button class="panel-btn" on:click={startVirtualCam}>
              <Icon path={mdiCamera} size="1.1rem" />
              <span>Cam</span>
            </button>
          {/if}

          <!-- Toggles -->
          <button class="panel-btn" class:active={isStudioMode} on:click={toggleStudioMode}>
            <Icon path={mdiBorderVertical} size="1.1rem" />
            <span>Studio</span>
          </button>
          <button class="panel-btn" class:active={isSceneOnTop} on:click={switchSceneView}>
            <Icon path={mdiArrowSplitHorizontal} size="1.1rem" />
            <span>Scene Top</span>
          </button>
          <button class="panel-btn" class:active={editable} on:click={() => (editable = !editable)}>
            <Icon path={editable ? mdiImageEditOutline : mdiImageEdit} size="1.1rem" />
            <span>Edit</span>
          </button>
          <button class="panel-btn" class:active={isIconMode} on:click={() => (isIconMode = !isIconMode)}>
            <Icon path={isIconMode ? mdiSquareRoundedBadgeOutline : mdiSquareRoundedBadge} size="1.1rem" />
            <span>Icons</span>
          </button>

          <!-- Replay -->
          <button class="panel-btn" class:active={isReplaying} class:active-danger={replayError} on:click={toggleReplay}>
            <Icon path={isReplaying ? mdiMotionPlayOutline : mdiMotionPlay} size="1.1rem" />
            <span>Replay</span>
          </button>
          <button class="panel-btn" class:active={isSaveReplay} on:click={() => { if (!isSaveReplayDisabled) { saveReplay() } isSaveReplayDisabled = !isSaveReplayDisabled }}>
            <Icon path={isSaveReplay ? mdiContentSaveCheckOutline : mdiContentSaveMoveOutline} size="1.1rem" />
            <span>Save</span>
          </button>
        </div>

        {#if replayError}
          <div class="panel-error">{replayError}</div>
        {/if}

        <div class="panel-selects">
          <ProfileSelect />
          <SceneCollectionSelect />
        </div>

        <div class="panel-actions">
          <button class="panel-btn" on:click={disconnect}>
            <Icon path={mdiConnection} size="1.1rem" />
            <span>Disconnect</span>
          </button>
          <button class="panel-btn" class:active={isFullScreen} on:click={toggleFullScreen}>
            <Icon path={isFullScreen ? mdiFullscreenExit : mdiFullscreen} size="1.1rem" />
            <span>Fullscreen</span>
          </button>
        </div>
      </div>
    {/if}
  </header>

  <main class="control-panel">
    {#if isSceneOnTop}
      <ProgramPreview {imageFormat} />
    {/if}
    <SceneSwitcher
      bind:scenes
      buttonStyle={isIconMode ? 'icon' : 'text'}
      {editable}
    />
    {#if !isSceneOnTop}
      <ProgramPreview {imageFormat} />
    {/if}
    {#each scenes as scene}
      {#if scene.sceneName.indexOf('(switch)') > 0}
        <SourceSwitcher
          name={scene.sceneName}
          {imageFormat}
          buttonStyle="screenshot"
        />
      {/if}
    {/each}
  </main>
</div>
{/if}

<style>
  /* ── Page wrapper ── */
  .connected-page {
    min-height: 100vh;
    background: radial-gradient(ellipse at top, #3f4559 0%, #353B4B 50%, #2e3344 100%);
    font-family: 'Libre Baskerville', Georgia, serif;
    color: #d0d4e0;
  }

  /* ── Toolbar ── */
  .toolbar {
    background: #2a2f3d;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
    position: sticky;
    top: 0;
    z-index: 50;
  }

  .toolbar-bar {
    display: flex;
    align-items: center;
    height: 48px;
    padding: 0 0.75rem;
    gap: 0.5rem;
  }

  /* ── Hamburger ── */
  .toolbar-burger {
    display: none;
    background: none;
    border: none;
    color: #999;
    cursor: pointer;
    padding: 0.3rem;
    border-radius: 6px;
    flex-shrink: 0;
  }

  .toolbar-burger:hover {
    background: rgba(255, 255, 255, 0.06);
    color: #d0d4e0;
  }

  /* ── Status pill ── */
  .status-pill {
    background: rgba(255, 255, 255, 0.06);
    color: #999;
    font-size: 0.7rem;
    padding: 0.25rem 0.65rem;
    border-radius: 20px;
    white-space: nowrap;
    letter-spacing: 0.02em;
    flex-shrink: 0;
  }

  /* ── Desktop inline controls ── */
  .toolbar-inline {
    display: flex;
    align-items: center;
    flex: 1;
    justify-content: center;
    gap: 0.15rem;
  }

  .btn-group {
    display: flex;
    align-items: center;
    gap: 0.1rem;
    padding: 0 0.3rem;
    border-right: 1px solid rgba(255, 255, 255, 0.06);
  }

  .btn-group:last-child {
    border-right: none;
  }

  /* ── Toolbar icon buttons (desktop) ── */
  .tb-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    background: transparent;
    border: none;
    color: #777;
    padding: 0.3rem 0.4rem;
    border-radius: 6px;
    cursor: pointer;
    transition: background 0.12s, color 0.12s;
    font-family: 'Libre Baskerville', Georgia, serif;
    font-size: 0.7rem;
    white-space: nowrap;
  }

  .tb-btn:hover {
    background: rgba(255, 255, 255, 0.06);
    color: #d0d4e0;
  }

  .tb-btn.active {
    color: #DFBC0C;
  }

  .tb-btn.active:hover {
    background: rgba(223, 188, 12, 0.1);
  }

  .tb-btn.active-danger {
    color: #fff;
    background: #f14668;
  }

  .tb-btn.active-danger:hover {
    background: #e0395b;
  }

  .tb-btn.active-success {
    color: #fff;
    background: #48c774;
  }

  .tb-btn.active-success:hover {
    background: #3dba68;
  }

  .tb-time {
    font-size: 0.65rem;
    opacity: 0.9;
  }

  /* ── Avatar (always in top bar) ── */
  .avatar-wrapper {
    position: relative;
    flex-shrink: 0;
    margin-left: auto;
  }

  .avatar {
    width: 34px;
    height: 34px;
    border-radius: 50%;
    background: #DFBC0C;
    color: #1a1e28;
    border: none;
    font-size: 0.7rem;
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

  /* ── Mobile panel (hidden by default, shown via {#if}) ── */
  .mobile-panel {
    display: none;
  }

  /* ── Control Panel ── */
  .control-panel {
    padding: 1.5rem;
    max-width: 1200px;
    margin: 0 auto;
  }

  /* ── Mobile ── */
  @media screen and (max-width: 1024px) {
    .toolbar-burger {
      display: flex;
      align-items: center;
    }

    .desktop-only {
      display: none;
    }

    .toolbar-inline {
      display: none;
    }

    .mobile-panel {
      display: block;
      padding: 0.75rem;
      border-top: 1px solid rgba(255, 255, 255, 0.06);
    }

    .mobile-status {
      display: inline-block;
      margin-bottom: 0.75rem;
    }

    /* ── Panel grid of labeled buttons ── */
    .panel-grid {
      display: flex;
      flex-wrap: wrap;
      gap: 0.4rem;
      margin-bottom: 0.75rem;
    }

    .panel-btn {
      display: inline-flex;
      align-items: center;
      gap: 0.35rem;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid rgba(255, 255, 255, 0.08);
      color: #999;
      padding: 0.45rem 0.7rem;
      border-radius: 8px;
      cursor: pointer;
      font-family: 'Libre Baskerville', Georgia, serif;
      font-size: 0.75rem;
      white-space: nowrap;
      transition: background 0.12s, color 0.12s, border-color 0.12s;
    }

    .panel-btn:hover {
      background: rgba(255, 255, 255, 0.08);
      color: #d0d4e0;
    }

    .panel-btn.active {
      color: #DFBC0C;
      border-color: rgba(223, 188, 12, 0.3);
    }

    .panel-btn.active-danger {
      color: #fff;
      background: #f14668;
      border-color: #f14668;
    }

    .panel-btn.active-success {
      color: #fff;
      background: #48c774;
      border-color: #48c774;
    }

    .panel-time {
      font-size: 0.65rem;
      opacity: 0.85;
    }

    .panel-error {
      color: #ff7b7b;
      font-size: 0.75rem;
      margin-bottom: 0.5rem;
    }

    .panel-selects {
      display: flex;
      flex-wrap: wrap;
      gap: 0.4rem;
      margin-bottom: 0.75rem;
    }

    .panel-actions {
      display: flex;
      gap: 0.4rem;
    }

    .control-panel {
      padding: 1rem 0.75rem;
    }
  }

  /* ── Desktop: hide mobile panel entirely ── */
  @media screen and (min-width: 1025px) {
    .mobile-panel {
      display: none !important;
    }
  }
</style>
