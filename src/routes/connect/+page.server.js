import { env } from '$env/dynamic/private'
import { getHostConfig } from '$lib/convex.js'

export async function load () {
  const host = await getHostConfig()
  return {
    obsPassword: env.OBS_WS_PASSWORD || '',
    host: host || null
  }
}
