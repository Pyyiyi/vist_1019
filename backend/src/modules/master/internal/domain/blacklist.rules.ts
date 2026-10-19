import type { BlacklistStatus } from '../master.types.js';

export function isEffectiveBlacklist(
  entry: { status: BlacklistStatus; expireAt: Date | string },
  now: Date = new Date(),
): boolean {
  if (entry.status !== '有效') {
    return false;
  }
  const expireAt = entry.expireAt instanceof Date ? entry.expireAt : new Date(entry.expireAt);
  return !Number.isNaN(expireAt.getTime()) && expireAt.getTime() >= now.getTime();
}

export function shouldExpireBlacklist(
  entry: { status: BlacklistStatus; expireAt: Date | string },
  now: Date,
): boolean {
  if (entry.status !== '有效') {
    return false;
  }
  const expireAt = entry.expireAt instanceof Date ? entry.expireAt : new Date(entry.expireAt);
  return !Number.isNaN(expireAt.getTime()) && expireAt.getTime() < now.getTime();
}

export function normalizeBlacklistIdNos(values: string[]): string[] {
  return Array.from(
    new Set(
      values
        .map((value) => value.replace(/\s+/g, '').toUpperCase())
        .filter((value) => value.length > 0),
    ),
  );
}
