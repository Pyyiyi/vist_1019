import { conflict, unprocessable } from '../../../../shared/http/errors.js';
import { APPOINTMENT_STATUSES, OPEN_STATUSES } from '../../../../shared/constants/status.js';
import { isValidIdCard, isValidOtherId, normalizeIdNo } from '../../../../shared/validation/validators.js';

export type AppointmentStatus = (typeof APPOINTMENT_STATUSES)[number];
export type CompanionInput = { name?: unknown; relation?: unknown; id_no?: unknown };

export const COPY = {
  NAME_REQUIRED: '请输入访客姓名',
  NAME_TOO_LONG: '访客姓名不能超过 20 个字符',
  PHONE_REQUIRED: '请输入手机号',
  PHONE_INVALID: '请输入正确的 11 位手机号',
  ID_REQUIRED: '请输入证件号',
  ID_INVALID: '请输入正确的 18 位身份证号，或 5–20 位其他证件号',
  TYPE_REQUIRED: '请选择访客类型',
  HOST_REQUIRED: '请选择被访人',
  START_REQUIRED: '请选择开始时间',
  END_REQUIRED: '请选择结束时间',
  END_BEFORE_START: '结束时间必须晚于开始时间',
  CROSS_DAY: '预约必须在同一天内完成',
  TOO_SHORT: '到访时段不能少于 15 分钟',
  TOO_LONG: '到访时段不能超过 240 分钟',
  REASON_REQUIRED: '请填写来访事由',
  REASON_SHORT: '来访事由至少 2 个字符',
  REASON_LONG: '来访事由不能超过 100 个字符',
  COMPANION_LIMIT: '最多添加 10 名随行人员',
  COMPANION_RELATION: '请选择与主访客的关系',
  COMPANION_ID: '请输入正确的随行人员证件号',
  OUTSIDE_ALLOWED: '所选时段不在可预约时间内',
  DENY_RULE: '所选时段属于禁止入校时段',
  START_PAST: '开始时间必须晚于当前时间',
  DUPLICATE: '该证件号在所选时段已有未完成的预约',
  CONSENT: '请阅读并勾选《安全告知》和《个人信息授权告知》',
  STATE_CONFLICT: '当前状态不允许该操作，请刷新后重试',
  RESCHEDULE_REASON: '被访人提议改期',
  GATE_PASS: '核验通过，可以放行',
  GATE_BLACKLIST: '该访客命中安全名单，禁止放行，已记录异常',
  GATE_OUT_OF_WINDOW: '当前不在预约核验时段内',
  GATE_EXPIRED: '该预约已过期，不能放行',
  GATE_NOT_APPROVED: '该预约尚未通过审核，不能放行',
};

const TRANSITIONS: Readonly<Record<AppointmentStatus, readonly AppointmentStatus[]>> = {
  待审核: ['已通过', '已拒绝', '已改期', '已过期', '已取消'],
  已通过: ['已到访(在校中)', '已过期', '已取消'],
  已改期: ['待审核', '已过期', '已取消'],
  '已到访(在校中)': ['已离校'],
  已离校: ['已到访(在校中)'],
  已拒绝: [],
  已过期: [],
  已取消: [],
};

export function assertTransition(from: string, to: string): void {
  const allowed = TRANSITIONS[from as AppointmentStatus];
  if (!allowed?.includes(to as AppointmentStatus)) {
    throw conflict(COPY.STATE_CONFLICT);
  }
}

export function assertRescheduleEligible(status: string): void {
  if (!['待审核', '已改期', '已通过'].includes(status)) {
    throw conflict(COPY.STATE_CONFLICT);
  }
}

export function parseDateValue(value: unknown): Date | null {
  if (typeof value !== 'string' || value.trim() === '') return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function shanghaiParts(value: Date): Record<string, string> {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    weekday: 'short',
  }).formatToParts(value);
  return Object.fromEntries(parts.map((part) => [part.type, part.value]));
}

export function shanghaiDateKey(value: Date): string {
  const parts = shanghaiParts(value);
  return `${parts.year}-${parts.month}-${parts.day}`;
}

export function shanghaiWeekday(value: Date): number {
  const parts = shanghaiParts(value);
  const map: Record<string, number> = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };
  return map[parts.weekday ?? ''] ?? 1;
}

export function shanghaiHms(value: Date): string {
  const parts = shanghaiParts(value);
  return `${parts.hour}:${parts.minute}:00`;
}

export function validateVisitWindow(
  start: Date,
  end: Date,
  now: Date,
  minMinutes = 15,
  maxMinutes = 240,
  allowPast = false,
  allowCrossDay = false,
): void {
  if (start >= end) throw unprocessable(COPY.END_BEFORE_START, 'visit_end');
  if (!allowCrossDay && shanghaiDateKey(start) !== shanghaiDateKey(end)) {
    throw unprocessable(COPY.CROSS_DAY, 'visit_end');
  }
  const minutes = (end.getTime() - start.getTime()) / 60_000;
  if (minutes < minMinutes) throw unprocessable(COPY.TOO_SHORT, 'visit_end');
  if (minutes > maxMinutes) throw unprocessable(COPY.TOO_LONG, 'visit_end');
  if (!allowPast && start.getTime() <= now.getTime()) {
    throw unprocessable(COPY.START_PAST, 'visit_start');
  }
}

export function normalizeCompanions(input: unknown, max = 10): Array<{ name: string; relation: string; id_no: string; sort_order: number }> {
  if (input === undefined || input === null) return [];
  if (!Array.isArray(input)) throw unprocessable('随行人员格式不正确', 'companions');
  if (input.length > max) throw unprocessable(COPY.COMPANION_LIMIT, 'companions');
  return input.map((raw, index) => {
    const item = (raw ?? {}) as CompanionInput;
    const name = typeof item.name === 'string' ? item.name.trim() : '';
    if (!name) throw unprocessable('请输入随行人员姓名', `companions[${index}].name`);
    if (Array.from(name).length > 20) throw unprocessable('随行人员姓名不能超过 20 个字符', `companions[${index}].name`);
    const relation = typeof item.relation === 'string' ? item.relation.trim() : '';
    if (!relation) throw unprocessable(COPY.COMPANION_RELATION, `companions[${index}].relation`);
    const idNo = typeof item.id_no === 'string' ? normalizeIdNo(item.id_no) : '';
    if (!idNo || (!isValidIdCard(idNo) && !isValidOtherId(idNo))) {
      throw unprocessable(COPY.COMPANION_ID, `companions[${index}].id_no`);
    }
    return { name, relation, id_no: idNo, sort_order: index + 1 };
  });
}

export function validateMainVisitor(input: { visitor_name?: unknown; visitor_phone?: unknown; visitor_id_no?: unknown }): { name: string; phone: string; idNo: string } {
  const name = typeof input.visitor_name === 'string' ? input.visitor_name.trim() : '';
  if (!name) throw unprocessable(COPY.NAME_REQUIRED, 'visitor_name');
  if (Array.from(name).length > 20) throw unprocessable(COPY.NAME_TOO_LONG, 'visitor_name');
  const phone = typeof input.visitor_phone === 'string' ? input.visitor_phone.trim() : '';
  if (!phone) throw unprocessable(COPY.PHONE_REQUIRED, 'visitor_phone');
  if (!/^1\d{10}$/.test(phone)) throw unprocessable(COPY.PHONE_INVALID, 'visitor_phone');
  const idNo = typeof input.visitor_id_no === 'string' ? normalizeIdNo(input.visitor_id_no) : '';
  if (!idNo) throw unprocessable(COPY.ID_REQUIRED, 'visitor_id_no');
  if (!isValidIdCard(idNo) && !isValidOtherId(idNo)) throw unprocessable(COPY.ID_INVALID, 'visitor_id_no');
  return { name, phone, idNo };
}

export function validateReason(value: unknown): string {
  const reason = typeof value === 'string' ? value.trim() : '';
  if (!reason) throw unprocessable(COPY.REASON_REQUIRED, 'reason');
  const length = Array.from(reason).length;
  if (length < 2) throw unprocessable(COPY.REASON_SHORT, 'reason');
  if (length > 100) throw unprocessable(COPY.REASON_LONG, 'reason');
  return reason;
}

export function validateRejectReason(value: unknown): string {
  const reason = typeof value === 'string' ? value.trim() : '';
  if (!reason) throw unprocessable('请填写拒绝原因', 'reject_reason');
  const length = Array.from(reason).length;
  if (length < 2) throw unprocessable('拒绝原因至少 2 个字符', 'reject_reason');
  if (length > 100) throw unprocessable('拒绝原因不能超过 100 个字符', 'reject_reason');
  return reason;
}

export function inVerifyWindow(start: Date, end: Date, now: Date, bufferMinutes = 15): boolean {
  const startBoundary = start.getTime() - bufferMinutes * 60_000;
  const endBoundary = end.getTime() + bufferMinutes * 60_000;
  return now.getTime() >= startBoundary && now.getTime() <= endBoundary;
}

export function rescheduleDeadline(proposedAt: Date, timeoutHours = 3): Date {
  return new Date(proposedAt.getTime() + timeoutHours * 3_600_000);
}

export function isRescheduleExpired(proposedAt: Date, now: Date, timeoutHours = 3): boolean {
  return now.getTime() > rescheduleDeadline(proposedAt, timeoutHours).getTime();
}

export function isOpenStatus(status: string): boolean {
  return (OPEN_STATUSES as readonly string[]).includes(status);
}

export function intervalsIntersect(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date): boolean {
  return aStart.getTime() <= bEnd.getTime() && bStart.getTime() <= aEnd.getTime();
}

export function sameShanghaiDayAsNow(value: Date, now: Date): boolean {
  return shanghaiDateKey(value) === shanghaiDateKey(now);
}
