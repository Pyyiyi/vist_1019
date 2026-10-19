const COPY_MESSAGES: Record<string, string> = {
  'COPY-001': '请先登录',
  'COPY-002': '账号或密码错误，请重新输入',
  'COPY-003': '该账号已停用，请联系管理员',
  'COPY-004': '密码错误次数过多，账号已锁定，请在 10 分钟后重试',
  'COPY-005': '您没有执行该操作的权限',
  'COPY-006': '您无权查看该记录',
  'COPY-007': '该申请链接已失效，请重新扫码申请',
  'COPY-008': '要查看的记录不存在或已被删除',
  'COPY-009': '该数据不支持删除，请使用停用功能',
  'COPY-010': '当前状态不允许该操作，请刷新后重试',
  'COPY-011': '该凭证已核销，不能重复放行',
  'COPY-012': '登录请求过于频繁，请 1 分钟后再试',
  'COPY-013': '系统暂时无法处理，请稍后重试',
};

export const MESSAGES: Record<string, string> = {
  SUCCESS: '操作成功',
  UNAUTHORIZED: COPY_MESSAGES['COPY-001'],
  INVALID_CREDENTIALS: COPY_MESSAGES['COPY-002'],
  ACCOUNT_DISABLED: COPY_MESSAGES['COPY-003'],
  ACCOUNT_LOCKED: COPY_MESSAGES['COPY-004'],
  FORBIDDEN: COPY_MESSAGES['COPY-005'],
  OBJECT_FORBIDDEN: COPY_MESSAGES['COPY-006'],
  VISITOR_TOKEN_INVALID: COPY_MESSAGES['COPY-007'],
  NOT_FOUND: COPY_MESSAGES['COPY-008'],
  METHOD_NOT_ALLOWED: COPY_MESSAGES['COPY-009'],
  CONFLICT: COPY_MESSAGES['COPY-010'],
  DUPLICATE_CHECKIN: COPY_MESSAGES['COPY-011'],
  TOO_MANY_REQUESTS: COPY_MESSAGES['COPY-012'],
  INTERNAL_ERROR: COPY_MESSAGES['COPY-013'],
  SERVER_ERROR: COPY_MESSAGES['COPY-013'],
};

for (const [copyId, message] of Object.entries(COPY_MESSAGES)) {
  Object.defineProperty(MESSAGES, copyId, {
    configurable: false,
    enumerable: false,
    value: message,
    writable: false,
  });
}
