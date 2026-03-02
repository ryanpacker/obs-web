import { WorkOS } from '@workos-inc/node'
import { SignJWT, jwtVerify } from 'jose'
import { env } from '$env/dynamic/private'

let _workos
function workos () {
  if (!_workos) _workos = new WorkOS(env.WORKOS_API_KEY)
  return _workos
}

function secret () {
  return new TextEncoder().encode(env.SESSION_SECRET)
}

export function getAuthorizationUrl () {
  return workos().userManagement.getAuthorizationUrl({
    provider: 'authkit',
    clientId: env.WORKOS_CLIENT_ID,
    redirectUri: env.WORKOS_REDIRECT_URI
  })
}

export async function authenticateWithCode (code) {
  const { user } = await workos().userManagement.authenticateWithCode({
    code,
    clientId: env.WORKOS_CLIENT_ID
  })
  return user
}

export async function createSession (user) {
  return new SignJWT({ sub: user.id, email: user.email, name: user.firstName || user.email })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('7d')
    .sign(secret())
}

export async function verifySession (token) {
  try {
    const { payload } = await jwtVerify(token, secret())
    return payload
  } catch {
    return null
  }
}
