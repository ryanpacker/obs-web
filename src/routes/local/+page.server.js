import { getHostConfig } from '$lib/convex.js'

export async function load () {
  const host = await getHostConfig()
  return { host: host || null }
}
