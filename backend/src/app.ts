import { readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

import compression from 'compression';
import cookieParser from 'cookie-parser';
import cors from 'cors';
import express, { Router, type Express } from 'express';
import helmet from 'helmet';

import { config } from './config.js';
import { sessionMiddleware } from './shared/auth/session.js';
import { responseEnvelope } from './shared/http/responseEnvelope.js';
import { errorHandler } from './shared/http/errorHandler.js';
import { notFoundHandler } from './shared/http/notFoundHandler.js';
import { auditMiddleware } from './shared/middleware/auditMiddleware.js';
import { csrfProtection } from './shared/middleware/csrfProtection.js';
import { apiRateLimiter } from './shared/middleware/rateLimiter.js';
import { logger } from './shared/logger.js';

export const API_PREFIX = '/api/v1';

const modulesDirectory = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  'modules'
);

let routesReady: Promise<void> | undefined;

function routeFiles(): string[] {
  const files: string[] = [];

  for (const context of readdirSync(modulesDirectory, { withFileTypes: true })) {
    if (!context.isDirectory()) {
      continue;
    }

    const apiDirectory = path.join(modulesDirectory, context.name, 'api');
    let entries;
    try {
      entries = readdirSync(apiDirectory, { withFileTypes: true });
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
        continue;
      }
      throw error;
    }

    for (const entry of entries) {
      if (entry.isFile() && /\.routes\.(?:ts|js)$/.test(entry.name)) {
        files.push(path.join(apiDirectory, entry.name));
      }
    }
  }

  return files.sort();
}

async function loadRoutes(router: ReturnType<typeof Router>): Promise<void> {
  for (const file of routeFiles()) {
    const routeModule = await import(pathToFileURL(file).href);
    const moduleRouter = routeModule.default;
    if (typeof moduleRouter !== 'function') {
      throw new Error(`Route module must export default router: ${file}`);
    }
    router.use(moduleRouter);
  }
}

export function waitForRoutes(): Promise<void> {
  return routesReady ?? Promise.resolve();
}

export function mountRoutes(app: Express): void {
  const router = Router();
  app.use(API_PREFIX, router);
  routesReady = loadRoutes(router);
  void routesReady.catch((error: unknown) => {
    logger.error('路由自动发现失败', {
      error: error instanceof Error ? error.message : String(error),
    });
  });
}

export function createApp(): Express {
  const app = express();

  app.set('trust proxy', 1);
  app.use(helmet());
  app.use(cors({ origin: config.CORS_ORIGIN, credentials: true }));
  app.use(compression());
  app.use(cookieParser(config.COOKIE_SECRET));
  app.use(express.json({ limit: '1mb' }));
  app.use(responseEnvelope);
  app.use(sessionMiddleware);
  app.use(csrfProtection);
  app.use(apiRateLimiter);
  app.get(`${API_PREFIX}/health`, (_req, res) => res.json({ code: 0, message: '操作成功', data: { status: 'ok' } }));
  mountRoutes(app);
  app.use(auditMiddleware);
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

const app = createApp();

export default app;
