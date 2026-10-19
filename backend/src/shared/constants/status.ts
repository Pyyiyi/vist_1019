export const APPOINTMENT_STATUSES = [
  '待审核',
  '已通过',
  '已拒绝',
  '已改期',
  '已过期',
  '已到访(在校中)',
  '已离校',
  '已取消',
] as const;

export const TERMINAL_STATUSES = ['已拒绝', '已过期', '已取消'] as const;

export const OPEN_STATUSES = ['待审核', '已改期', '已通过', '已到访(在校中)'] as const;

export const ATTENDED_STATUSES = ['已通过', '已到访(在校中)', '已离校'] as const;

export const INCIDENT_STATUSES = ['待处理', '已处理', '已忽略'] as const;

export const INCIDENT_TYPES = ['黑名单命中', '信息不符', '强行闯入', '超时未离'] as const;
