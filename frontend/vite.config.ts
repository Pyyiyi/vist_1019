import path from 'node:path';
import { fileURLToPath } from 'node:url';

import vue from '@vitejs/plugin-vue';
import { defineConfig } from 'vitest/config';

const dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig(() => {
  const backendPort = process.env.HOST_BACKEND_PORT ?? '3000';
  const target = `http://localhost:${backendPort}`;

  return {
    plugins: [vue()],
    resolve: {
      alias: {
        '@': path.resolve(dirname, 'src'),
      },
    },
    server: {
      proxy: {
        '/api': {
          target,
          changeOrigin: true,
          headers: {
            'X-Forwarded-Proto': 'https',
          },
        },
        '/ws': {
          target,
          changeOrigin: true,
          ws: true,
          headers: {
            'X-Forwarded-Proto': 'https',
          },
        },
      },
    },
    build: {
      outDir: 'dist',
    },
    test: {
      environment: 'jsdom',
    },
  };
});
