import { defineConfig } from 'vite'

export default defineConfig({
  build: {
    manifest: true,
    outDir: '../static',
    rollupOptions: {
      input: './src/main.js'
    }
  },
  server: {
    port: 3000,
    cors: true,
    strictPort: true,
    proxy: {
      '/api': 'http://localhost:4000',
      '/static': 'http://localhost:4000'
    }
  }
})
