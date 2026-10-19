import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { getPool, withTransaction } from './pool.js';

const seedsDirectory = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../../db/seeds'
);

function withoutTransactionControl(sql: string): string {
  return sql.replace(/^\s*(?:BEGIN|COMMIT)\s*;\s*$/gim, '');
}

export async function runSeeds(): Promise<number> {
  const entries = await readdir(seedsDirectory, { withFileTypes: true });
  const files = entries
    .filter((entry) => entry.isFile() && entry.name.endsWith('.sql'))
    .map((entry) => entry.name)
    .sort();

  for (const filename of files) {
    try {
      const sql = await readFile(path.join(seedsDirectory, filename), 'utf8');
      await withTransaction(async (client) => {
        await client.query(withoutTransactionControl(sql));
      });
    } catch (error) {
      console.error(`种子执行失败：${filename}`);
      throw error;
    }
  }

  console.log(`种子执行完成，共 ${files.length} 个文件`);
  return files.length;
}

const isDirectRun =
  process.argv[1] !== undefined &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));

if (isDirectRun) {
  runSeeds()
    .then(() => getPool().end())
    .catch(async () => {
      await getPool().end().catch(() => undefined);
      process.exitCode = 1;
    });
}
