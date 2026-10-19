import { formatMinute } from '../../../../shared/utils/ids.js';

export const NOTIFICATION_TEMPLATE_TYPES = [
  '提交通知',
  '审核结果',
  '改期提议',
  '改期确认结果',
  '到访提醒',
  '黑名单命中',
  '超时未离',
] as const;

export type NotificationTemplateType = (typeof NOTIFICATION_TEMPLATE_TYPES)[number];

export const SECURITY_TEMPLATE_TYPES: readonly NotificationTemplateType[] = [
  '黑名单命中',
  '超时未离',
];

export type TemplateRenderInput = {
  visitorName?: string;
  hostName?: string;
  gateName?: string;
  visitStart?: string | Date;
  visitEnd?: string | Date;
  result?: '通过' | '拒绝';
  reason?: string;
  timeoutHours?: number;
  appointmentNo?: string;
  maskedIdNo?: string;
  checkinAt?: string | Date;
  stayDuration?: string;
};

export type RenderedTemplate = {
  title: string;
  content: string;
};

export function isNotificationTemplateType(value: unknown): value is NotificationTemplateType {
  return typeof value === 'string' && NOTIFICATION_TEMPLATE_TYPES.includes(value as NotificationTemplateType);
}

export function isSecurityTemplate(type: NotificationTemplateType): boolean {
  return SECURITY_TEMPLATE_TYPES.includes(type);
}

function visitRange(input: TemplateRenderInput): string {
  if (!input.visitStart || !input.visitEnd) {
    return '预约时段';
  }

  const start = formatMinute(input.visitStart);
  const end = formatMinute(input.visitEnd);
  return `${start}–${end.slice(11)}`;
}

export function renderTemplate(
  templateType: NotificationTemplateType,
  input: TemplateRenderInput = {},
): RenderedTemplate {
  const visitorName = input.visitorName?.trim() || '访客';
  const hostName = input.hostName?.trim() || '被访人';
  const gateName = input.gateName?.trim() || '校门';
  const range = visitRange(input);

  switch (templateType) {
    case '提交通知':
      return {
        title: '您有一条新的访客预约',
        content: `访客 ${visitorName} 预约 ${range} 来访，请及时审核`,
      };
    case '审核结果': {
      const result = input.result ?? '通过';
      const reason = result === '拒绝' && input.reason?.trim()
        ? `；拒绝原因：${input.reason.trim()}`
        : '';
      return {
        title: `您的来访申请已${result === '拒绝' ? '拒绝' : '通过'}`,
        content: `到访时段 ${range}，被访人 ${hostName}${reason}`,
      };
    }
    case '改期提议':
      return {
        title: '被访人提议调整到访时段',
        content: `新到访时段 ${range}，请在 ${input.timeoutHours ?? 3} 小时内确认`,
      };
    case '改期确认结果':
      return {
        title: '访客已确认改期',
        content: `访客已确认改期，预约${input.appointmentNo ? ` ${input.appointmentNo}` : ''}回到待审核`,
      };
    case '到访提醒':
      return {
        title: '您的访客即将到访',
        content: `访客 ${visitorName} 将于 ${range} 到访，校门：${gateName}`,
      };
    case '黑名单命中':
      return {
        title: '黑名单人员提交预约',
        content: `访客 ${visitorName}（证件号 ${input.maskedIdNo?.trim() || '已脱敏'}）提交了 ${range} 的预约`,
      };
    case '超时未离':
      return {
        title: '访客超时未离校',
        content: `访客 ${visitorName} 于 ${
          input.checkinAt ? formatMinute(input.checkinAt) : '进校时间未知'
        } 进校，已在校 ${input.stayDuration?.trim() || '超过规定时长'}`,
      };
    default:
      throw new Error(`未知通知模板：${String(templateType)}`);
  }
}
