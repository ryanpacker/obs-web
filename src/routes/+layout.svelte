<script>
  import { onMount } from 'svelte'
  import { obs } from '../obs.js'
  import { setupConnectionState } from '$lib/connection.js'

  export let data

  onMount(() => {
    setupConnectionState(obs)
  })
</script>

<svelte:head>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
  <link href="https://fonts.googleapis.com/css2?family=Libre+Baskerville:wght@400;700&display=swap" rel="stylesheet" />
</svelte:head>

<slot />
