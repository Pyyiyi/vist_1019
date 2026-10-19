const requiredKeys = [
  'NODE_ENV',
  'PORT',
  'DATABASE_URL',
  'DB_POOL_MAX',
  'SESSION_SECRET',
  'COOKIE_SECRET',
  'COOKIE_SECURE',
  'SESSION_TTL_HOURS',
  'CORS_ORIGIN',
  'TZ',
  'ENABLE_JOBS',
  'LOG_LEVEL',
] as const;

type RequiredKey = (typeof requiredKeys)[number];
type LogLevel = 'debug' | 'info' | 'warn' | 'error';

export interface AppConfig {
  nodeEnv: 'production';
  port: number;
  databaseUrl: string;
  dbPoolMax: number;
  sessionSecret: string;
  cookieSecret: string;
  cookieSecure: boolean;
  sessionTtlHours: number;
  corsOrigin: string;
  timezone: 'Asia/Shanghai';
  enableJobs: boolean;
  logLevel: LogLevel;
}

function requireValue(env: NodeJS.ProcessEnv, key: RequiredKey): string {
  const value = env[key]?.trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

function requirePositiveInteger(env: NodeJS.ProcessEnv, key: RequiredKey): number {
  const raw = requireValue(env, key);
  const value = Number(raw);
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error(`Environment variable ${key} must be a positive integer`);
  }
  return value;
}

function requireBoolean(env: NodeJS.ProcessEnv, key: RequiredKey): boolean {
  const value = requireValue(env, key);
  if (value !== 'true' && value !== 'false') {
    throw new Error(`Environment variable ${key} must be true or false`);
  }
  return value === 'true';
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const missing = requiredKeys.filter((key) => !env[key]?.trim());
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  const nodeEnv = requireValue(env, 'NODE_ENV');
  if (nodeEnv !== 'production') {
    throw new Error('Environment variable NODE_ENV must be production');
  }

  const timezone = requireValue(env, 'TZ');
  if (timezone !== 'Asia/Shanghai') {
    throw new Error('Environment variable TZ must be Asia/Shanghai');
  }

  const logLevel = requireValue(env, 'LOG_LEVEL');
  if (!['debug', 'info', 'warn', 'error'].includes(logLevel)) {
    throw new Error('Environment variable LOG_LEVEL must be debug, info, warn, or error');
  }

  return {
    nodeEnv: 'production',
    port: requirePositiveInteger(env, 'PORT'),
    databaseUrl: requireValue(env, 'DATABASE_URL'),
    dbPoolMax: requirePositiveInteger(env, 'DB_POOL_MAX'),
    sessionSecret: requireValue(env, 'SESSION_SECRET'),
    cookieSecret: requireValue(env, 'COOKIE_SECRET'),
    cookieSecure: requireBoolean(env, 'COOKIE_SECURE'),
    sessionTtlHours: requirePositiveInteger(env, 'SESSION_TTL_HOURS'),
    corsOrigin: requireValue(env, 'CORS_ORIGIN'),
    timezone: 'Asia/Shanghai',
    enableJobs: requireBoolean(env, 'ENABLE_JOBS'),
    logLevel: logLevel as LogLevel,
  };
}

export const config = loadConfig();
