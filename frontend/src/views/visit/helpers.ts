import dayjs from 'dayjs';

export const TERMINAL_STATUSES = ['已拒绝', '已过期', '已取消'] as const;
export const ACTIONABLE_STATUSES = ['待审核', '已改期', '已通过'] as const;

export function isTerminal(status: string): boolean {
  return (TERMINAL_STATUSES as readonly string[]).includes(status);
}

export function canReschedule(status: string): boolean {
  return (ACTIONABLE_STATUSES as readonly string[]).includes(status);
}

export function serverMessage(error: unknown): string {
  const response = (error as { response?: { data?: { message?: string } } }).response;
  return response?.data?.message ?? '系统暂时无法处理，请稍后重试';
}

export function responseField(error: unknown): string | undefined {
  return (error as { response?: { data?: { field?: string } } }).response?.data?.field;
}

export function formatMinute(value: string | null | undefined): string {
  return value ? dayjs(value).format('YYYY-MM-DD HH:mm') : '—';
}

export function formatSecond(value: string | null | undefined): string {
  return value ? dayjs(value).format('YYYY-MM-DD HH:mm:ss') : '—';
}

export function formatRange(start: string | null | undefined, end: string | null | undefined): string {
  if (!start || !end) return '—';
  const from = dayjs(start);
  const to = dayjs(end);
  return from.isSame(to, 'day')
    ? `${from.format('YYYY-MM-DD HH:mm')}–${to.format('HH:mm')}`
    : `${from.format('YYYY-MM-DD HH:mm')}–${to.format('YYYY-MM-DD HH:mm')}`;
}

export function isoForInput(value: string | null): string | undefined {
  return value ? dayjs(value).toISOString() : undefined;
}

export function durationText(minutes: number | null | undefined): string {
  if (minutes === null || minutes === undefined) return '—';
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return hours > 0 ? `${hours} 小时 ${rest} 分钟` : `${rest} 分钟`;
}

export function relationLabel(options: Array<{ dictKey: string; dictLabel: string }>, value: string): string {
  return options.find((item) => item.dictKey === value)?.dictLabel ?? value;
}
