import bundleVersion from '$lib/bundle/version.json'

export function load ({ locals }) {
  return { user: locals.user, bundleVersion }
}
