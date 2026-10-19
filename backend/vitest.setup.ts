Object.assign(process.env, {
  NODE_ENV: 'production',
  PORT: '3000',
  DATABASE_URL: 'postgres://visitor:visitor@localhost:55432/visitor_system',
  DB_POOL_MAX: '10',
  SESSION_SECRET: 'visitor-session-secret-2026',
  COOKIE_SECRET: 'visitor-cookie-secret-2026',
  COOKIE_SECURE: 'false',
  SESSION_TTL_HOURS: '8',
  CORS_ORIGIN: 'http://localhost:8080',
  TZ: 'Asia/Shanghai',
  ENABLE_JOBS: 'false',
  LOG_LEVEL: 'info',
});
