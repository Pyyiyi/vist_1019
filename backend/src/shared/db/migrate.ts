import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getPool, withTransaction } from './pool.js';

const migrationsDirectory = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../../db/migrations'
);

function withoutTransactionControl(sql: string): string {
  return sql.replace(/^\s*(?:BEGIN|COMMIT)\s*;\s*$/gim, '');
}

export async function runMigrations(): Promise<{ applied: string[] }> {
  const pool = getPool();

  await pool.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      filename   TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  const entries = await readdir(migrationsDirectory, { withFileTypes: true });
  const files = entries
    .filter((entry) => entry.isFile() && entry.name.endsWith('.sql'))
    .map((entry) => entry.name)
    .sort();

  const applied: string[] = [];

  for (const filename of files) {
    try {
      const sql = await readFile(path.join(migrationsDirectory, filename), 'utf8');
      const wasApplied = await withTransaction(async (client) => {
        const claim = await client.query<{ filename: string }>(
          `INSERT INTO _migrations (filename)
           VALUES ($1)
           ON CONFLICT (filename) DO NOTHING
           RETURNING filename`,
          [filename]
        );

        if (claim.rowCount === 0) {
          return false;
        }

        await client.query(withoutTransactionControl(sql));
        return true;
      });

      if (wasApplied) {
        applied.push(filename);
      }
    } catch (error) {
      console.error(`数据库迁移失败：${filename}`);
      throw error;
    }
  }

  console.log(`数据库迁移完成，已应用 ${applied.length} 个文件`);
  return { applied };
}

const isDirectRun =
  process.argv[1] !== undefined &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));

if (isDirectRun) {
  runMigrations()
    .then(() => getPool().end())
    .catch(async () => {
      await getPool().end().catch(() => undefined);
      process.exitCode = 1;
    });
}
