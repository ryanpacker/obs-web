<script>
  import { onMount, onDestroy } from 'svelte'
  import { obs, sendCommand } from './obs.js'

  export let imageFormat = 'jpg'

  let isStudioMode = false
  let programScene = ''
  let previewScene = ''

  let program = {}
  let preview = {}
  let screenshotInterval
  let transitions = []
  // let currentTransition = ''

  onMount(async () => {
    let data
    if (!programScene) {
      data = await sendCommand('GetCurrentProgramScene')
      programScene = data.currentProgramSceneName || ''
    }
    data = await sendCommand('GetStudioModeEnabled')
    if (data && data.studioModeEnabled) {
      isStudioMode = true
      data = await sendCommand('GetCurrentPreviewScene')
      previewScene = data.currentPreviewSceneName || ''
    }

    data = await sendCommand('GetSceneTransitionList')
    console.log('GetSceneTransitionList', data)
    transitions = data.transitions || []
    // currentTransition = data.currentSceneTransitionName || ''
    screenshotInterval = setInterval(getScreenshot, 1000)
  })

  onDestroy(() => {
    clearInterval(screenshotInterval)
  })

  // eslint-disable-next-line
  $: getScreenshot(), programScene, previewScene

  obs.on('StudioModeStateChanged', async (data) => {
    console.log('StudioModeStateChanged', data.studioModeEnabled)
    isStudioMode = data.studioModeEnabled
    if (isStudioMode) {
      previewScene = programScene
    }
  })

  obs.on('CurrentPreviewSceneChanged', async (data) => {
    console.log('CurrentPreviewSceneChanged', data.sceneName)
    previewScene = data.sceneName
  })

  obs.on('CurrentProgramSceneChanged', async (data) => {
    console.log('CurrentProgramSceneChanged', data.sceneName)
    programScene = data.sceneName
  })

  obs.on('SceneNameChanged', async (data) => {
    if (data.oldSceneName === programScene) programScene = data.sceneName
    if (data.oldSceneName === previewScene) previewScene = data.sceneName
  })

  // TODO: does not exist???
  obs.on('TransitionListChanged', async (data) => {
    console.log('TransitionListChanged', data)
    transitions = data.transitions || []
  })

  async function getScreenshot () {
    if (!programScene) return
    let data = await sendCommand('GetSourceScreenshot', {
      sourceName: programScene,
      imageFormat,
      imageWidth: 960,
      imageHeight: 540
    })
    if (data && data.imageData && program) {
      program.src = data.imageData
      program.className = ''
    }

    if (isStudioMode) {
      if (previewScene !== programScene) {
        data = await sendCommand('GetSourceScreenshot', {
          sourceName: previewScene,
          imageFormat,
          imageWidth: 960,
          imageHeight: 540
        })
      }
      if (data && data.imageData && preview) {
        preview.src = data.imageData
      }
    }
  }
</script>

<div class="columns is-centered is-vcentered has-text-centered">
  {#if isStudioMode}
    <div class="column"><div class="stream-frame">
      <img bind:this={preview} alt="Preview" />
    </div></div>
    <div class="column is-narrow">
      {#each transitions as transition}
      <button class="transition-btn" style="margin-bottom: .5rem;"
        on:click={async () => {
          await sendCommand('SetCurrentSceneTransition', { transitionName: transition.transitionName })
          await sendCommand('TriggerStudioModeTransition')
        }}
        >{transition.transitionName}</button>
      {/each}
    </div>
  {/if}
  <div class="column"><div class="stream-frame">
    <img bind:this={program} alt="Program"/>
  </div></div>
</div>

<style>
  .transition-btn {
    width: 100%;
    padding: 0.5rem 1rem;
    background: #3a3f50;
    color: #d0d4e0;
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 6px;
    font-size: 0.85rem;
    font-family: 'Libre Baskerville', Georgia, serif;
    cursor: pointer;
    transition: background 0.15s, border-color 0.15s;
  }

  .transition-btn:hover {
    background: #464c60;
    border-color: rgba(223, 188, 12, 0.3);
  }

  .transition-btn:active {
    background: #2e3344;
  }

  .stream-frame {
    border-radius: 8px;
    overflow: hidden;
    display: inline-block;
  }

  .stream-frame :global(img) {
    display: block;
    max-width: 100%;
  }
</style>
