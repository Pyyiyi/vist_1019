import http from 'node:http';

import { config, loadConfig } from './config.js';
import { createApp, waitForRoutes } from './app.js';
import { initRealtime } from './realtime/io.js';
import { sessionMiddleware } from './shared/auth/session.js';
import { getPool } from './shared/db/pool.js';
import { runMigrations } from './shared/db/migrate.js';
import { startJobs, stopAllJobs } from './shared/jobs/scheduler.js';

async function start(): Promise<void> {
  loadConfig();
  const pool = getPool();
  await runMigrations();

  const app = createApp();
  await waitForRoutes();
  const server = http.createServer(app);
  const io = initRealtime(server, sessionMiddleware);

  server.listen(config.PORT, () => {
    console.log(`visitor-system-backend listening on port ${config.PORT}`);
  });

  if (config.ENABLE_JOBS === 'true') {
    startJobs();
  }

  let shuttingDown = false;
  const shutdown = async (signal: string): Promise<void> => {
    if (shuttingDown) {
      return;
    }
    shuttingDown = true;

    console.log(`收到 ${signal}，正在关闭服务`);
    stopAllJobs();
    io.close();
    server.close();
    await pool.end();
  };

  process.once('SIGTERM', () => {
    void shutdown('SIGTERM');
  });
  process.once('SIGINT', () => {
    void shutdown('SIGINT');
  });
}

start().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
