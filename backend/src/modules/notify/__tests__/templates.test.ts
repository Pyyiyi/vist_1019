import { describe, expect, it } from 'vitest';

import {
  NOTIFICATION_TEMPLATE_TYPES,
  SECURITY_TEMPLATE_TYPES,
  isNotificationTemplateType,
  isSecurityTemplate,
  renderTemplate,
} from '../internal/domain/templates.js';

describe('通知模板', () => {
  const input = {
    visitorName: '陈晨',
    hostName: '李明',
    gateName: '南门',
    visitStart: '2026-10-19T14:00:00+08:00',
    visitEnd: '2026-10-19T15:00:00+08:00',
    maskedIdNo: '3201**********4566',
    checkinAt: '2026-10-19T14:05:00+08:00',
    stayDuration: '1小时5分钟',
    appointmentNo: 'AP202610190001',
  } as const;

  it('exposes exactly the seven frozen template types', () => {
    expect(NOTIFICATION_TEMPLATE_TYPES).toEqual([
      '提交通知',
      '审核结果',
      '改期提议',
      '改期确认结果',
      '到访提醒',
      '黑名单命中',
      '超时未离',
    ]);
    expect(SECURITY_TEMPLATE_TYPES).toEqual(['黑名单命中', '超时未离']);
    expect(isNotificationTemplateType('到访提醒')).toBe(true);
    expect(isNotificationTemplateType('未知模板')).toBe(false);
    expect(isSecurityTemplate('黑名单命中')).toBe(true);
    expect(isSecurityTemplate('提交通知')).toBe(false);
  });

  it('renders the submission and review-result titles verbatim', () => {
    expect(renderTemplate('提交通知', input)).toEqual({
      title: '您有一条新的访客预约',
      content: '访客 陈晨 预约 2026-10-19 14:00–15:00 来访，请及时审核',
    });
    expect(renderTemplate('审核结果', { ...input, result: '通过' }).title).toBe(
      '您的来访申请已通过',
    );
    expect(renderTemplate('审核结果', { ...input, result: '拒绝', reason: '时段冲突' })).toEqual({
      title: '您的来访申请已拒绝',
      content: '到访时段 2026-10-19 14:00–15:00，被访人 李明；拒绝原因：时段冲突',
    });
  });

  it('renders reschedule, reminder, blacklist and overdue templates', () => {
    expect(renderTemplate('改期提议', input)).toEqual({
      title: '被访人提议调整到访时段',
      content: '新到访时段 2026-10-19 14:00–15:00，请在 3 小时内确认',
    });
    expect(renderTemplate('改期确认结果', input)).toEqual({
      title: '访客已确认改期',
      content: '访客已确认改期，预约 AP202610190001回到待审核',
    });
    expect(renderTemplate('到访提醒', input)).toEqual({
      title: '您的访客即将到访',
      content: '访客 陈晨 将于 2026-10-19 14:00–15:00 到访，校门：南门',
    });
    expect(renderTemplate('黑名单命中', input)).toEqual({
      title: '黑名单人员提交预约',
      content: '访客 陈晨（证件号 3201**********4566）提交了 2026-10-19 14:00–15:00 的预约',
    });
    expect(renderTemplate('超时未离', input)).toEqual({
      title: '访客超时未离校',
      content: '访客 陈晨 于 2026-10-19 14:05 进校，已在校 1小时5分钟',
    });
  });
});
