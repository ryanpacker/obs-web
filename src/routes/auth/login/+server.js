import { redirect } from '@sveltejs/kit'
import { getAuthorizationUrl } from '$lib/auth.js'

export function GET () {
  const url = getAuthorizationUrl()
  throw redirect(302, url)
}
