<script>
  import { onMount } from 'svelte'
  import { obs, sendCommand } from './obs.js'

  let profiles = []
  let currentProfile = ''

  onMount(async function () {
    const data = await sendCommand('GetProfileList')
    profiles = data.profiles || []
    currentProfile = data.currentProfileName || ''
  })

  obs.on('CurrentProfileChanged', async (data) => {
    console.log('CurrentProfileChanged', data.profileName)
    currentProfile = data.profileName || ''
  })
  obs.on('ProfileListChanged', async (data) => {
    console.log('ProfileListChanged', data.profiles.length)
    profiles = data.profiles || []
  })

  async function setCurrentProfile (event) {
    sendCommand('SetCurrentProfile', { profileName: event.target.value })
  }
</script>

<div class="dark-select" style="margin: 0 .5rem .5rem 0;">
  <select bind:value={currentProfile} title="Change Profile" on:change={setCurrentProfile}>
  {#each profiles as profile}
    <option value={profile}>{profile}</option>
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
