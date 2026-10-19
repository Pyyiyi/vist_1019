type LogLevel = 'debug' | 'info' | 'warn' | 'error';

const LEVEL_WEIGHT: Record<LogLevel, number> = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40,
};

const SENSITIVE_KEY = /(?:password|passwd|secret|token|authorization|cookie|id[_-]?card|id[_-]?no|visitor[_-]?id[_-]?no)/i;

function activeLevel(): LogLevel {
  const configured = process.env.LOG_LEVEL?.trim().toLowerCase();
  if (configured === 'debug' || configured === 'info' || configured === 'warn' || configured === 'error') {
    return configured;
  }
  return 'info';
}

function sanitize(value: unknown, seen: WeakSet<object>): unknown {
  if (value === null || typeof value !== 'object') {
    return value;
  }

  if (seen.has(value)) {
    return '[Circular]';
  }
  seen.add(value);

  if (value instanceof Error) {
    return { name: value.name, message: value.message, stack: value.stack };
  }

  if (Array.isArray(value)) {
    return value.map((item) => sanitize(item, seen));
  }

  const output: Record<string, unknown> = {};
  for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
    output[key] = SENSITIVE_KEY.test(key) ? '[REDACTED]' : sanitize(child, seen);
  }
  return output;
}

function write(level: LogLevel, message: string, meta?: Record<string, unknown>): void {
  if (LEVEL_WEIGHT[level] < LEVEL_WEIGHT[activeLevel()]) {
    return;
  }

  const sanitized = meta ? (sanitize(meta, new WeakSet<object>()) as Record<string, unknown>) : {};
  const entry = {
    ...sanitized,
    level,
    message,
    time: new Date().toISOString(),
  };

  console.log(JSON.stringify(entry));
}

export const logger = {
  debug(message: string, meta?: Record<string, unknown>): void {
    write('debug', message, meta);
  },
  info(message: string, meta?: Record<string, unknown>): void {
    write('info', message, meta);
  },
  warn(message: string, meta?: Record<string, unknown>): void {
    write('warn', message, meta);
  },
  error(message: string, meta?: Record<string, unknown>): void {
    write('error', message, meta);
  },
};
