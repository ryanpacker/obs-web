import { redirect } from '@sveltejs/kit'
import { verifySession } from '$lib/auth.js'

export async function handle ({ event, resolve }) {
  if (event.url.pathname.startsWith('/auth/')) {
    return resolve(event)
  }

  const token = event.cookies.get('session')
  if (token) {
    const user = await verifySession(token)
    if (user) {
      event.locals.user = user
      return resolve(event)
    }
  }

  throw redirect(302, '/auth/login')
}
