import type { QueryResult, QueryResultRow } from 'pg';

export type Queryable = {
  query<T extends QueryResultRow = QueryResultRow>(
    sql: string,
    params?: unknown[],
  ): Promise<QueryResult<T>>;
};
export type SoftStatus = 'active' | 'inactive';
export type BlacklistStatus = '有效' | '已过期' | '已删除';
export type RuleType = '可预约' | '禁入';
export type ReviewerKind = 'host' | 'admin' | 'designated';

export type Actor = {
  id: string;
  displayName: string;
};

export type VisitorTypeDto = {
  id: string;
  code: string;
  name: string;
  status: SoftStatus;
  sortOrder: number;
  createdAt: Date | string;
};

export type BlacklistEntryDto = {
  id: string;
  idNo: string;
  name: string;
  reason: string;
  expireAt: Date | string;
  status: BlacklistStatus;
  createdAt: Date | string;
};

export type TimeRuleDto = {
  id: string;
  weekday: number;
  startTime: string;
  endTime: string;
  ruleType: RuleType;
  createdAt: Date | string;
};

export type GateDto = {
  id: string;
  code: string;
  name: string;
  status: SoftStatus;
  sortOrder: number;
  createdAt: Date | string;
};

export type HostDto = {
  id: string;
  name: string;
  employeeNo: string;
  department: string;
  phone: string | null;
  status: SoftStatus;
  createdAt: Date | string;
};

export type ParamDto = {
  configKey: string;
  configValue: string;
  valueType: 'string' | 'number' | 'boolean' | 'json';
  description: string;
  updatedAt: Date | string;
};

export type DictionaryItemDto = {
  id: string;
  dictType: string;
  dictKey: string;
  dictLabel: string;
  sortOrder: number;
  status: SoftStatus;
  createdAt: Date | string;
};

export type ReviewerRuleDto = {
  id: string;
  visitorTypeId: string | null;
  gateId: string | null;
  startTime: string | null;
  endTime: string | null;
  reviewerKind: ReviewerKind;
  reviewerUserId: string | null;
  declarationOrder: number;
  status: SoftStatus;
};

export type NewReviewerRule = Omit<ReviewerRuleDto, 'id'>;
