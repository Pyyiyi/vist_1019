import type {
  BlacklistEntryDto,
  DictionaryItemDto,
  GateDto,
  HostDto,
  ParamDto,
  TimeRuleDto,
  VisitorTypeDto,
} from './master.types.js';

export function apiVisitorType(item: VisitorTypeDto): Record<string, unknown> {
  return {
    id: item.id,
    code: item.code,
    name: item.name,
    status: item.status,
    sort_order: item.sortOrder,
    created_at: item.createdAt,
  };
}

export function apiBlacklist(item: BlacklistEntryDto): Record<string, unknown> {
  return {
    id: item.id,
    id_no: item.idNo,
    name: item.name,
    reason: item.reason,
    expire_at: item.expireAt,
    status: item.status,
    created_at: item.createdAt,
  };
}

export function apiTimeRule(item: TimeRuleDto): Record<string, unknown> {
  return {
    id: item.id,
    weekday: item.weekday,
    start_time: item.startTime,
    end_time: item.endTime,
    rule_type: item.ruleType,
    created_at: item.createdAt,
  };
}

export function apiGate(item: GateDto): Record<string, unknown> {
  return {
    id: item.id,
    code: item.code,
    name: item.name,
    status: item.status,
    sort_order: item.sortOrder,
    created_at: item.createdAt,
  };
}

export function apiHost(item: HostDto): Record<string, unknown> {
  return {
    id: item.id,
    name: item.name,
    employee_no: item.employeeNo,
    department: item.department,
    phone: item.phone,
    status: item.status,
    created_at: item.createdAt,
  };
}

export function apiParam(item: ParamDto): Record<string, unknown> {
  return {
    config_key: item.configKey,
    config_value: item.configValue,
    value_type: item.valueType,
    description: item.description,
    updated_at: item.updatedAt,
  };
}

export function apiDictionary(item: DictionaryItemDto): Record<string, unknown> {
  return {
    id: item.id,
    dict_type: item.dictType,
    dict_key: item.dictKey,
    dict_label: item.dictLabel,
    sort_order: item.sortOrder,
    status: item.status,
    created_at: item.createdAt,
  };
}
