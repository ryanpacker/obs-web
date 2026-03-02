import { env } from '$env/dynamic/private'

export function load () {
  return { obsPassword: env.OBS_WS_PASSWORD || '' }
}
