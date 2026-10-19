import { randomUUID } from 'node:crypto';

const SHANGHAI_TIME_ZONE = 'Asia/Shanghai';
const LOCAL_DATE_TIME = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?$/;
const LOCAL_DATE = /^(\d{4})-(\d{2})-(\d{2})$/;

function asDate(value: Date | string): Date {
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) {
      throw new RangeError('无效日期');
    }
    return value;
  }

  const trimmed = value.trim();
  let parsed: Date;
  if (LOCAL_DATE.test(trimmed)) {
    parsed = new Date(trimmed + 'T00:00:00+08:00');
  } else if (LOCAL_DATE_TIME.test(trimmed)) {
    parsed = new Date(trimmed.replace(' ', 'T') + '+08:00');
  } else {
    parsed = new Date(trimmed);
  }

  if (Number.isNaN(parsed.getTime())) {
    throw new RangeError('无效日期');
  }
  return parsed;
}

function shanghaiParts(value: Date | string): Record<string, string> {
  const date = asDate(value);
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: SHANGHAI_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);

  return Object.fromEntries(parts.map((part) => [part.type, part.value]));
}

export function newUuid(): string {
  return randomUUID();
}

export function formatMinute(value: Date | string): string {
  const parts = shanghaiParts(value);
  return `${parts.year}-${parts.month}-${parts.day} ${parts.hour}:${parts.minute}`;
}

export function formatSecond(value: Date | string): string {
  const parts = shanghaiParts(value);
  return `${parts.year}-${parts.month}-${parts.day} ${parts.hour}:${parts.minute}:${parts.second}`;
}

export function localDayRange(day: Date | string): { start: Date; end: Date } {
  const parts = shanghaiParts(day);
  return {
    start: new Date(`${parts.year}-${parts.month}-${parts.day}T00:00:00.000+08:00`),
    end: new Date(`${parts.year}-${parts.month}-${parts.day}T23:59:59.999+08:00`),
  };
}
