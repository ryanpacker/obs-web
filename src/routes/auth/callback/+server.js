import { redirect } from '@sveltejs/kit'
import { authenticateWithCode, createSession } from '$lib/auth.js'

export async function GET ({ url, cookies }) {
  const code = url.searchParams.get('code')
  if (!code) {
    throw redirect(302, '/auth/login')
  }

  const user = await authenticateWithCode(code)
  const token = await createSession(user)

  cookies.set('session', token, {
    path: '/',
    httpOnly: true,
    secure: true,
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 7 // 7 days
  })

  throw redirect(302, '/')
}
