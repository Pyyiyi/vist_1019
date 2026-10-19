import app from './app.js';
import { config } from './config.js';
import { runMigrations } from './shared/db/migrate.js';
import { getPool } from './shared/db/pool.js';

async function start(): Promise<void> {
  getPool();
  await runMigrations();

  app.listen(config.port, () => {
    console.log(`visitor-system-backend listening on port ${config.port}`);
  });
}

start().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
