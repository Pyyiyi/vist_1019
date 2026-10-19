import connectPgSimple from 'connect-pg-simple';
import type { RequestHandler } from 'express';
import session, { type Store } from 'express-session';

import { getPool } from '../db/pool.js';

export const SESSION_COOKIE_NAME = 'vs.sid';
export const SESSION_TTL_MS = 8 * 60 * 60 * 1000;

export type SessionMiddlewareOptions = {
  store?: Store;
};

const PgSession = connectPgSimple(session);

function sessionSecret(): string {
  const secret = process.env.SESSION_SECRET?.trim();
  if (!secret) {
    throw new Error('Missing required environment variable: SESSION_SECRET');
  }
  return secret;
}

function cookieSecure(): boolean {
  return process.env.COOKIE_SECURE?.trim() === 'true';
}

function defaultStore(): Store {
  return new PgSession({
    pool: getPool(),
    tableName: 'sessions',
    createTableIfMissing: false,
  });
}

export function createSessionMiddleware(options: SessionMiddlewareOptions = {}): RequestHandler {
  return session({
    name: SESSION_COOKIE_NAME,
    secret: sessionSecret(),
    store: options.store ?? defaultStore(),
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      sameSite: 'lax',
      secure: cookieSecure(),
      maxAge: SESSION_TTL_MS,
    },
  });
}

let activeMiddleware: RequestHandler | undefined;

export const sessionMiddleware: RequestHandler = (req, res, next) => {
  if (!activeMiddleware) {
    activeMiddleware = createSessionMiddleware();
  }
  activeMiddleware(req, res, next);
};
