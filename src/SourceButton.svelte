<script>
  export let name
  export let buttonStyle = 'text'
  export let icon = '#ffffff'
  export let isProgram = false
  export let isPreview = false
  export let img = ''

  import { createEventDispatcher } from 'svelte'
  const dispatch = createEventDispatcher()

  $: style = icon.startsWith('#')
    ? `background-color: ${icon};`
    : `background-image: url(${icon});`

  // Pending state: immediate feedback on click before OBS confirms the switch
  let pending = false

  function handleClick () {
    if (!isProgram && !pending) {
      pending = true
    }
    dispatch('click')
  }

  // Clear pending once the real state arrives
  $: if (isProgram || isPreview) {
    pending = false
  }
</script>

<button
  class:title={buttonStyle === 'text'}
  class:program={isProgram}
  class:preview={isPreview}
  class:pending
  class:with-icon={buttonStyle === 'icon'}
  on:click={handleClick}
  style={buttonStyle === 'icon' ? style : ''}
  title={name}
  >
  <span class="fill-bar"></span>
  {#if img}<img src={img} alt={name} class="thumbnail" />{/if}
  {#if buttonStyle !== 'icon'}<span class="btn-text">{name}</span>{/if}
</button>

<style>
  button {
    border: 1px solid rgba(255, 255, 255, 0.14);
    height: 2.75rem;
    text-align: center;
    width: 100%;
    cursor: pointer;
    background: rgba(255, 255, 255, 0.06);
    color: #f0f1f4;
    border-radius: 8px;
    font-family: 'Libre Baskerville', Georgia, serif;
    font-size: 0.85rem;
    font-weight: 700;
    letter-spacing: 0.01em;
    transition: border-color 0.15s, box-shadow 0.15s, color 0.15s;
    position: relative;
    overflow: hidden;
  }

  button:hover {
    background: rgba(255, 255, 255, 0.09);
    border-color: rgba(255, 255, 255, 0.15);
  }

  button:active {
    background: rgba(255, 255, 255, 0.03);
  }

  /* ── Fill bar (sits behind content) ── */
  .fill-bar {
    position: absolute;
    inset: 0;
    background: rgba(223, 188, 12, 0.10);
    transform: scaleX(0);
    transform-origin: left;
    pointer-events: none;
    border-radius: inherit;
  }

  /* ── Pending: instant border + animated fill ── */
  button.pending {
    border-color: rgba(223, 188, 12, 0.4);
    color: #DFBC0C;
  }

  button.pending .fill-bar {
    animation: fill-progress 1.8s ease-out forwards;
  }

  @keyframes fill-progress {
    0%   { transform: scaleX(0); }
    70%  { transform: scaleX(0.85); }
    100% { transform: scaleX(0.92); }
  }

  /* ── Text label (above fill bar) ── */
  .btn-text {
    position: relative;
    z-index: 1;
    color: inherit;
  }

  /* ── Preview state ── */
  button.preview {
    background: rgba(0, 209, 178, 0.12);
    border-color: rgba(0, 209, 178, 0.35);
    color: #6ee7d7;
  }

  button.preview .fill-bar {
    animation: none;
    transform: none;
    background: rgba(0, 209, 178, 0.12);
  }

  /* ── Program (selected) state ── */
  button.program {
    background: rgba(223, 188, 12, 0.12);
    border-color: rgba(223, 188, 12, 0.4);
    color: #DFBC0C;
  }

  button.program .fill-bar {
    animation: none;
    transform: none;
    background: rgba(223, 188, 12, 0.12);
  }

  /* ── Screenshot / non-title mode ── */
  button:not(.title) {
    padding: 0;
    width: 192px;
    height: 126px;
  }

  /* ── Icon mode ── */
  button.with-icon {
    height: 56px;
    width: 56px;
    border: 1px solid rgba(255, 255, 255, 0.08);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
    margin: .4em;
    border-radius: 10px;
    cursor: pointer;
    background: #3a3f50 no-repeat center center / cover;
    position: relative;
  }

  button.with-icon:hover {
    border-color: rgba(255, 255, 255, 0.18);
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.4);
  }

  button.with-icon.pending {
    border-color: rgba(223, 188, 12, 0.5);
    box-shadow: 0 0 10px rgba(223, 188, 12, 0.15);
  }

  button.with-icon.preview {
    border-color: rgba(0, 209, 178, 0.5);
    box-shadow: 0 0 10px rgba(0, 209, 178, 0.2);
  }

  button.with-icon.program {
    border-color: rgba(223, 188, 12, 0.5);
    box-shadow: 0 0 10px rgba(223, 188, 12, 0.2);
  }

  button.with-icon.program::before {
    content: " ";
    position: absolute;
    top: -4px;
    right: -4px;
    background: #DFBC0C;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    box-shadow: 0 0 6px rgba(223, 188, 12, 0.5);
  }

  .thumbnail {
    display: block;
    max-width: 100%;
    max-height: calc(100% - 1rem);
    margin: 0 auto;
    position: relative;
    z-index: 1;
  }
</style>
