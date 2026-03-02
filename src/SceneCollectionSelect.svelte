<script>
  import { onMount } from 'svelte'
  import { obs, sendCommand } from './obs.js'

  let collections = []
  let currentCollection = ''

  onMount(async function () {
    const data = await sendCommand('GetSceneCollectionList')
    collections = data.sceneCollections || []
    currentCollection = data.currentSceneCollectionName || ''
  })

  obs.on('CurrentSceneCollectionChanged', async (data) => {
    console.log('CurrentSceneCollectionChanged', data.sceneCollectionName)
    currentCollection = data.sceneCollectionName || ''
    // Manually emit new scenes, since OBS doesn't send them when the collection changes
    obs.emit('SceneListChanged', await sendCommand('GetSceneList'))
  })
  obs.on('SceneCollectionListChanged', async (data) => {
    console.log('SceneCollectionListChanged', data.sceneCollections.length)
    collections = data.sceneCollections || []
  })

  async function setCurrentCollection (event) {
    sendCommand('SetCurrentSceneCollection', { sceneCollectionName: event.target.value })
  }
</script>

<div class="dark-select" style="margin: 0 .5rem .5rem 0;">
  <select bind:value={currentCollection} title="Change Collection" on:change={setCurrentCollection}>
  {#each collections as collection}
    <option value={collection}>{collection}</option>
  {/each}
  </select>
</div>

<style>
  .dark-select {
    display: inline-block;
    position: relative;
  }

  .dark-select select {
    appearance: none;
    background: #2a2f3d;
    color: #d0d4e0;
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 6px;
    padding: 0.4rem 2rem 0.4rem 0.75rem;
    font-size: 0.8rem;
    font-family: 'Libre Baskerville', Georgia, serif;
    cursor: pointer;
    outline: none;
    transition: border-color 0.15s;
  }

  .dark-select select:hover {
    border-color: rgba(223, 188, 12, 0.3);
  }

  .dark-select select:focus {
    border-color: #DFBC0C;
  }

  .dark-select::after {
    content: '\25BE';
    position: absolute;
    right: 0.6rem;
    top: 50%;
    transform: translateY(-50%);
    color: #777;
    pointer-events: none;
    font-size: 0.75rem;
  }

  .dark-select select option {
    background: #2a2f3d;
    color: #d0d4e0;
  }
</style>
