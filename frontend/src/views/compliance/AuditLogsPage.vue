<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import dayjs from 'dayjs';

import apiClient from '@/api/client';
import EmptyState from '@/components/EmptyState.vue';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import PageHeader from '@/components/PageHeader.vue';

type AuditValue = Record<string, unknown> | unknown[] | string | number | boolean | null;
type AuditLog = {
  id: string;
  userId: string | null;
  userName: string;
  occurredAt: string;
  objectType: string;
  objectId: string | null;
  action: string;
  result: string;
  beforeValue: AuditValue;
  afterValue: AuditValue;
  ip: string | null;
  note: string;
};
type DateRange = [dayjs.Dayjs, dayjs.Dayjs] | null;
type DiffStatus = 'added' | 'removed' | 'modified' | 'same';

const ACTION_OPTIONS = [
  '审核同意', '审核拒绝', '放行', '核验', '取消预约', '异常上报', '异常处置',
  '越权拦截', '新增预约', '离校', '改期', '现场登记', '人工清除', '修改留存配置',
  '登录', '退出登录', '新增账号', '停用账号', '启用账号', '重置密码', '修改密码',
  '新增主数据', '修改主数据', '停用主数据', '删除黑名单', '删除时段规则', '修改参数',
  '修改字典',
].map((value) => ({ value, label: value }));

const columns = [
  { title: '时间', key: 'occurredAt', dataIndex: 'occurredAt', width: 176 },
  { title: '操作人', key: 'userName', dataIndex: 'userName', width: 130, ellipsis: true },
  { title: '对象', key: 'object', width: 210, ellipsis: true },
  { title: '动作', key: 'action', dataIndex: 'action', width: 116 },
  { title: '结果', key: 'result', dataIndex: 'result', width: 84 },
  { title: '改动前', key: 'beforeValue', width: 92 },
  { title: '改动后', key: 'afterValue', width: 92 },
];

const loading = ref(true);
const failed = ref(false);
const items = ref<AuditLog[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(20);
const drawerOpen = ref(false);
const selectedLog = ref<AuditLog | null>(null);
const expandedRows = ref<Record<string, boolean>>({});
const filters = reactive({
  operator: '',
  action: undefined as string | undefined,
  objectType: '',
  dateRange: null as DateRange,
});

function emptyValue(value: AuditValue): boolean {
  return value === null || value === undefined;
}

function plainObject(value: AuditValue): Record<string, unknown> {
  if (emptyValue(value)) return {};
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
        ? parsed as Record<string, unknown>
        : { value: parsed };
    } catch {
      return { value };
    }
  }
  if (Array.isArray(value)) return { value };
  return value as Record<string, unknown>;
}

function sortKeys(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, entry]) => [key, sortKeys(entry)]),
    );
  }
  return value;
}

function displayValue(value: unknown, exists: boolean): string {
  if (!exists || value === null || value === undefined) return '—';
  if (typeof value === 'string') return value;
  if (typeof value === 'object') return JSON.stringify(sortKeys(value), null, 2);
  return String(value);
}

const diffRows = computed(() => {
  const before = plainObject(selectedLog.value?.beforeValue ?? null);
  const after = plainObject(selectedLog.value?.afterValue ?? null);
  const keys = Array.from(new Set([...Object.keys(before), ...Object.keys(after)])).sort((left, right) => left.localeCompare(right));
  return keys.map((key) => {
    const hasBefore = Object.prototype.hasOwnProperty.call(before, key);
    const hasAfter = Object.prototype.hasOwnProperty.call(after, key);
    const beforeText = displayValue(before[key], hasBefore);
    const afterText = displayValue(after[key], hasAfter);
    let status: DiffStatus = 'same';
    if (!hasBefore && hasAfter) status = 'added';
    else if (hasBefore && !hasAfter) status = 'removed';
    else if (beforeText !== afterText) status = 'modified';
    return {
      key,
      before: beforeText,
      after: afterText,
      status,
      long: beforeText.length > 120 || afterText.length > 120 || beforeText.includes('\n') || afterText.includes('\n'),
    };
  });
});

function formatTime(value: string): string {
  return dayjs(value).format('YYYY-MM-DD HH:mm:ss');
}

function resultColor(result: string): string {
  if (result === '成功') return 'green';
  if (result === '失败') return 'red';
  return 'default';
}

async function load(): Promise<void> {
  loading.value = true;
  failed.value = false;
  try {
    const response = await apiClient.get('/audit-logs', {
      params: {
        page: page.value,
        page_size: pageSize.value,
        user_id: filters.operator.trim() || undefined,
        action: filters.action || undefined,
        object_type: filters.objectType.trim() || undefined,
        date_from: filters.dateRange?.[0]?.format('YYYY-MM-DD'),
        date_to: filters.dateRange?.[1]?.format('YYYY-MM-DD'),
      },
    });
    const data = response.data.data;
    items.value = data.items as AuditLog[];
    total.value = Number(data.total ?? 0);
  } catch {
    failed.value = true;
    items.value = [];
    total.value = 0;
  } finally {
    loading.value = false;
  }
}

function query(): void {
  page.value = 1;
  void load();
}

function filterChanged(): void {
  page.value = 1;
}

function onPageChange(pagination: { current?: number; pageSize?: number }): void {
  page.value = pagination.current ?? 1;
  pageSize.value = pagination.pageSize ?? 20;
  void load();
}

function openDiff(record: AuditLog): void {
  selectedLog.value = record;
  expandedRows.value = {};
  drawerOpen.value = true;
}

function toggleExpanded(key: string): void {
  expandedRows.value = { ...expandedRows.value, [key]: !expandedRows.value[key] };
}

onMounted(load);
</script>

<template>
  <section class="audit-page">
    <PageHeader title="操作日志" />

    <a-card class="filter-card" :bordered="false">
      <a-form layout="inline" class="filter-form">
        <a-form-item label="操作人">
          <a-input v-model:value="filters.operator" allow-clear placeholder="请输入操作人" @change="filterChanged" />
        </a-form-item>
        <a-form-item label="动作">
          <a-select v-model:value="filters.action" allow-clear show-search :options="ACTION_OPTIONS" placeholder="请选择动作" class="action-select" @change="filterChanged" />
        </a-form-item>
        <a-form-item label="对象">
          <a-input v-model:value="filters.objectType" allow-clear placeholder="请输入对象类型" @change="filterChanged" />
        </a-form-item>
        <a-form-item label="时间范围">
          <a-range-picker v-model:value="filters.dateRange" value-format="YYYY-MM-DD" @change="filterChanged" />
        </a-form-item>
        <a-form-item>
          <a-button type="primary" :loading="loading" :disabled="loading" @click="query">查询</a-button>
        </a-form-item>
      </a-form>
    </a-card>

    <a-card class="table-card" :bordered="false">
      <LoadingState v-if="loading" />
      <ErrorState v-else-if="failed" @retry="load" />
      <EmptyState v-else-if="items.length === 0" description="没有符合条件的操作记录" />
      <a-table
        v-else
        row-key="id"
        :columns="columns"
        :data-source="items"
        :pagination="{ current: page, pageSize, total, showSizeChanger: true, showTotal: (value: number) => `共 ${value} 条` }"
        :scroll="{ x: 1060 }"
        @change="onPageChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'occurredAt'">{{ formatTime(record.occurredAt) }}</template>
          <template v-else-if="column.key === 'userName'">
            <a-tooltip :title="record.userName"><span class="single-line">{{ record.userName }}</span></a-tooltip>
          </template>
          <template v-else-if="column.key === 'object'">
            <a-tooltip :title="`${record.objectType}${record.objectId ? ` / ${record.objectId}` : ''}`">
              <span class="single-line">{{ record.objectType }}<template v-if="record.objectId"> / {{ record.objectId }}</template></span>
            </a-tooltip>
          </template>
          <template v-else-if="column.key === 'result'">
            <a-tag :color="resultColor(record.result)">{{ record.result }}</a-tag>
          </template>
          <template v-else-if="column.key === 'beforeValue'">
            <a-button v-if="!emptyValue(record.beforeValue)" type="link" class="view-json" @click="openDiff(record)">查看</a-button>
            <span v-else>—</span>
          </template>
          <template v-else-if="column.key === 'afterValue'">
            <a-button v-if="!emptyValue(record.afterValue)" type="link" class="view-json" @click="openDiff(record)">查看</a-button>
            <span v-else>—</span>
          </template>
        </template>
      </a-table>
    </a-card>

    <a-drawer v-model:open="drawerOpen" title="改动前 / 改动后" :width="920" placement="right">
      <template v-if="selectedLog">
        <div class="drawer-meta">
          <span>{{ formatTime(selectedLog.occurredAt) }}</span>
          <span>{{ selectedLog.userName }}</span>
          <span>{{ selectedLog.objectType }}<template v-if="selectedLog.objectId"> / {{ selectedLog.objectId }}</template></span>
          <a-tag :color="resultColor(selectedLog.result)">{{ selectedLog.result }}</a-tag>
        </div>
        <EmptyState v-if="diffRows.length === 0" description="暂无改动内容" />
        <div v-else class="diff-table" role="table" aria-label="改动前后对比">
          <div class="diff-head" role="row">
            <div role="columnheader">字段</div>
            <div role="columnheader">改动前</div>
            <div role="columnheader">改动后</div>
          </div>
          <div v-for="row in diffRows" :key="row.key" class="diff-row" :class="`diff-${row.status}`" role="row">
            <div class="diff-key" role="cell">{{ row.key }}</div>
            <div class="diff-cell" role="cell">
              <pre class="json-value" :class="{ expanded: expandedRows[row.key] }">{{ row.before }}</pre>
              <a-button v-if="row.long" type="link" size="small" class="expand-button" @click="toggleExpanded(row.key)">{{ expandedRows[row.key] ? '收起' : '展开' }}</a-button>
            </div>
            <div class="diff-cell" role="cell">
              <pre class="json-value" :class="{ expanded: expandedRows[row.key] }">{{ row.after }}</pre>
              <a-button v-if="row.long" type="link" size="small" class="expand-button" @click="toggleExpanded(row.key)">{{ expandedRows[row.key] ? '收起' : '展开' }}</a-button>
            </div>
          </div>
        </div>
      </template>
    </a-drawer>
  </section>
</template>

<style scoped>
.audit-page { display: flex; min-width: 0; flex-direction: column; gap: var(--space-4); }
.filter-card, .table-card { min-width: 0; overflow: hidden; }
.filter-form { row-gap: var(--space-3); }
.filter-form :deep(.ant-form-item) { margin-right: var(--space-4); margin-bottom: 0; }
.action-select { width: 160px; }
.single-line { display: block; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.view-json { padding-inline: 0; }
.drawer-meta { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-2) var(--space-4); margin-bottom: var(--space-4); color: var(--color-text-secondary); }
.diff-table { overflow: hidden; border: 1px solid var(--color-border); border-radius: var(--radius-card); }
.diff-head, .diff-row { display: grid; grid-template-columns: minmax(120px, 0.7fr) minmax(0, 1fr) minmax(0, 1fr); }
.diff-head { color: var(--color-text-secondary); font-weight: 600; background: var(--color-table-header-bg); }
.diff-head > div, .diff-key, .diff-cell { padding: 10px 12px; }
.diff-row { border-top: 1px solid var(--color-border); }
.diff-key { color: var(--color-text-primary); font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-weight: 600; word-break: break-all; }
.diff-cell { min-width: 0; border-left: 1px solid var(--color-border); }
.diff-added { background: #f6ffed; }
.diff-removed { background: #fff1f0; }
.diff-modified { background: #fffbe6; }
.json-value { margin: 0; overflow: hidden; color: var(--color-text-primary); font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: var(--font-size-xs); line-height: 1.55; white-space: pre-wrap; word-break: break-word; }
.json-value:not(.expanded) { max-height: calc(1.55em * 3); }
.expand-button { height: auto; padding: 4px 0 0; line-height: 1.2; }
@media (max-width: 900px) { .diff-head { display: none; } .diff-row { grid-template-columns: 1fr; } .diff-key { padding-bottom: 4px; background: rgba(0, 0, 0, 0.025); } .diff-cell { border-left: 0; padding-top: 6px; } }
</style>
