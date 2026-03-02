import adapter from '@sveltejs/adapter-vercel'
import { sveltekit } from '@sveltejs/kit/vite'
import preprocess from 'svelte-preprocess'
import purgecssImport from '@fullhuman/postcss-purgecss'
import { defineConfig } from 'vite'

const config = {
  preprocess: preprocess({
    scss: {}
  }),
  kit: {
    adapter: adapter(),
    output: {
      bundleStrategy: 'single'
    }
  }
}

export default config

export const viteConfig = defineConfig(({ mode }) => {
  const production = mode === 'production'
  const purgecss = purgecssImport.default ?? purgecssImport

  return {
    appType: 'custom',
    plugins: [sveltekit()],
    css: {
      postcss: {
        plugins: [
          production &&
            purgecss({
              content: [
                './src/**/*.svelte',
                './src/**/*.js',
                './src/**/*.ts',
                './src/**/*.html',
                './src/app.html'
              ],
              safelist: {
                standard: [/svelte-/]
              },
              variables: true
            })
        ].filter(Boolean)
      }
    },
    build: {
      minify: 'terser',
      cssMinify: 'lightningcss',
      terserOptions: {
        compress: {
          passes: 2
        }
      },
      rollupOptions: {
        output: {
          inlineDynamicImports: true
        }
      }
    }
  }
})
