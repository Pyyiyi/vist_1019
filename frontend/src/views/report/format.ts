import dayjs from 'dayjs';

import type { LedgerItem } from './types';

export function formatDateTime(value: string | null | undefined): string {
  return value ? dayjs(value).format('YYYY-MM-DD HH:mm') : '';
}

export function formatVisitPeriod(item: LedgerItem): string {
  return `${formatDateTime(item.visitStart)} - ${formatDateTime(item.visitEnd)}`;
}

export function formatOnCampusDuration(
  checkinAt: string | null | undefined,
  now: Date = new Date(),
): string {
  if (!checkinAt) return '—';
  const start = dayjs(checkinAt);
  if (!start.isValid()) return '—';
  const minutes = Math.max(0, Math.floor((now.getTime() - start.valueOf()) / 60000));
  if (minutes < 60) return `${minutes}分钟`;
  const hours = Math.floor(minutes / 60);
  const remaining = minutes % 60;
  return remaining === 0 ? `${hours}小时` : `${hours}小时${remaining}分钟`;
}
