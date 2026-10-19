import cron from 'node-cron';
import type { ScheduledTask } from 'node-cron';

import { logger } from '../logger.js';

export type JobDefinition = {
  name: string;
  cron: string;
  runOnStart: boolean;
  handler: () => Promise<void>;
};

const registeredJobs = new Map<string, JobDefinition>();
const scheduledJobs: ScheduledTask[] = [];

async function runJob(definition: JobDefinition): Promise<void> {
  try {
    await definition.handler();
  } catch (error) {
    logger.error('定时任务执行失败', {
      job: definition.name,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

export function registerJob(definition: JobDefinition): void {
  registeredJobs.set(definition.name, definition);
}

export function startJobs(): void {
  if (process.env.ENABLE_JOBS !== 'true' || scheduledJobs.length > 0) {
    return;
  }

  for (const definition of registeredJobs.values()) {
    const task = cron.schedule(
      definition.cron,
      () => {
        void runJob(definition);
      },
      { timezone: 'Asia/Shanghai' }
    );
    scheduledJobs.push(task);

    if (definition.runOnStart) {
      void runJob(definition);
    }
  }
}

export function stopAllJobs(): void {
  for (const task of scheduledJobs) {
    task.stop();
  }
  scheduledJobs.length = 0;
}
