import { error } from '@sveltejs/kit'
import { readFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'

export function GET ({ locals }) {
  if (!locals.user) {
    throw error(401, 'Not authenticated')
  }

  // Try common locations: works for both Node adapter (cwd = project root)
  // and development (cwd = project root)
  const candidates = [
    join(process.cwd(), 'src/lib/bundle/obs-web-installer.zip'),
    join(process.cwd(), 'bundle/obs-web-installer.zip')
  ]

  const bundlePath = candidates.find(p => existsSync(p))

  if (!bundlePath) {
    throw error(404, 'Bundle not available yet. Run npm run build:bundle first.')
  }

  const file = readFileSync(bundlePath)

  return new Response(file, {
    headers: {
      'Content-Type': 'application/zip',
      'Content-Disposition': 'attachment; filename="obs-web-installer.zip"',
      'Content-Length': file.byteLength.toString()
    }
  })
}
