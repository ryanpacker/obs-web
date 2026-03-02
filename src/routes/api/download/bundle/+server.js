import { error } from '@sveltejs/kit'
import { read } from '$app/server'
import bundleUrl from '$lib/bundle/obs-web-installer.zip?url'

export function GET ({ locals }) {
  if (!locals.user) {
    throw error(401, 'Not authenticated')
  }

  const asset = read(bundleUrl)

  return new Response(asset.body, {
    headers: {
      'Content-Type': 'application/zip',
      'Content-Disposition': 'attachment; filename="obs-web-installer.zip"'
    }
  })
}
