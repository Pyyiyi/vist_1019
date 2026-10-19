import { unprocessable } from '../../../shared/http/errors.js';

export function stringValue(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

export function nullableString(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null;
  }
  const normalized = stringValue(value);
  return normalized === '' ? null : normalized;
}

export function requiredText(
  value: unknown,
  field: string,
  emptyMessage: string,
  maxLength: number,
): string {
  const normalized = stringValue(value);
  if (!normalized) {
    throw unprocessable(emptyMessage, field);
  }
  if (Array.from(normalized).length > maxLength) {
    throw unprocessable(`内容不能超过 ${maxLength} 个字符`, field);
  }
  return normalized;
}

export function parseDate(value: unknown, field: string, message: string): Date {
  if (typeof value !== 'string' && !(value instanceof Date)) {
    throw unprocessable(message, field);
  }
  const parsed = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw unprocessable(message, field);
  }
  return parsed;
}

export function requireFutureDate(value: unknown, field: string): Date {
  const parsed = parseDate(value, field, '有效期必须晚于当前时间');
  if (parsed.getTime() <= Date.now()) {
    throw unprocessable('有效期必须晚于当前时间', field);
  }
  return parsed;
}

export function parseInteger(value: unknown, field: string, fallback: number): number {
  if (value === undefined || value === null || value === '') {
    return fallback;
  }
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) {
    throw unprocessable('请输入整数', field);
  }
  return parsed;
}

import type { SoftStatus } from './master.types.js';

export function parseSoftStatus(value: unknown): SoftStatus {
  if (value !== 'active' && value !== 'inactive') {
    throw unprocessable('状态值不正确', 'status');
  }
  return value;
}

export function parseIncludeInactive(value: unknown): boolean {
  return value === true || value === 'true' || value === '1' || value === 1;
}
