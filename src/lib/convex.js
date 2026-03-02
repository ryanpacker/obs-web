import { ConvexHttpClient } from 'convex/browser'
import { env } from '$env/dynamic/public'

const client = new ConvexHttpClient(env.PUBLIC_CONVEX_URL)

export async function getHostIp () {
  const result = await client.query('obsHost:getHost')
  return result?.ipAddress || null
}

export async function getHostConfig () {
  return await client.query('obsHost:getHost')
}
