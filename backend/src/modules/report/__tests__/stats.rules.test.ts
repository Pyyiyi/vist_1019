import { describe, expect, it } from 'vitest';

import { AppError } from '../../../shared/http/errors.js';
import {
  expandVisitBuckets,
  normalizeIncidentCounts,
  parseGranularity,
  resolveDateRange,
  visitPeriods,
} from '../internal/stats.service.js';

describe('report stats rules', () => {
  it('日粒度补齐空类型维度为 0', () => {
    const range = resolveDateRange(
      { date_from: '2026-10-12', date_to: '2026-10-12' },
      new Date('2026-10-12T12:00:00+08:00'),
    );
    const buckets = expandVisitBuckets(
      [{ period: '2026-10-12', type: '公务访客', count: 2 }],
      ['公务访客', '校友'],
      'day',
      range,
    );

    expect(buckets).toEqual([
      { period: '2026-10-12', type: '公务访客', count: 2 },
      { period: '2026-10-12', type: '校友', count: 0 },
    ]);
  });

  it('周粒度和月粒度返回完整周期', () => {
    const weekRange = resolveDateRange({ date_from: '2026-10-12', date_to: '2026-10-25' });
    expect(visitPeriods(weekRange, 'week')).toEqual(['2026-10-12', '2026-10-19']);

    const monthRange = resolveDateRange({ date_from: '2026-10-12', date_to: '2026-11-30' });
    expect(visitPeriods(monthRange, 'month')).toEqual(['2026-10-01', '2026-11-01']);
  });

  it('异常统计固定输出四类并对缺失类型补 0', () => {
    expect(normalizeIncidentCounts([{ incident_type: '信息不符', count: 2 }])).toEqual([
      { type: '黑名单命中', count: 0 },
      { type: '信息不符', count: 2 },
      { type: '强行闯入', count: 0 },
      { type: '超时未离', count: 0 },
    ]);
  });

  it('非法粒度返回 422', () => {
    try {
      parseGranularity('year');
      throw new Error('expected validation error');
    } catch (error) {
      expect(error).toBeInstanceOf(AppError);
      expect((error as AppError).httpStatus).toBe(422);
    }
  });
});
