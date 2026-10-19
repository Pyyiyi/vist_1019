<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { message } from 'ant-design-vue';
import dayjs, { type Dayjs } from 'dayjs';

import apiClient from '@/api/client';
import EmptyState from '@/components/EmptyState.vue';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import PageHeader from '@/components/PageHeader.vue';
import StatusTag from '@/components/StatusTag.vue';
import { useAuthStore } from '@/stores/auth';
import { formatDateTime, formatVisitPeriod } from './format';
import type { LedgerItem } from './types';

type DateRange = [Dayjs, Dayjs];

type LedgerFilters = {
  name: string;
  idNo: string;
  phone: string;
  host: string;
  type: string;
  status: string | undefined;
  dateRange: DateRange | undefined;
};

const authStore = useAuthStore();
const loading = ref(true);
const failed = ref(false);
const items = ref<LedgerItem[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(20);
const exporting = ref(false);
const printing = ref(false);

const filters = reactive<LedgerFilters>({
  name: '',
  idNo: '',
  phone: '',
  host: '',
  type: '',
  status: undefined,
  dateRange: undefined,
});

const statusOptions = [
  '待审核',
  '已通过',
  '已拒绝',
  '已改期',
  '已过期',
  '已到访(在校中)',
  '已离校',
  '已取消',
].map((value) => ({ label: value, value }));

const isGuard = computed(() => authStore.role === 'guard');
const isAdmin = computed(() => authStore.role === 'admin');

const columns = [
  { title: '预约编号', dataIndex: 'appointNo', key: 'appointNo', width: 160 },
  { title: '姓名', dataIndex: 'visitorName', key: 'visitorName', width: 90 },
  { title: '访客类型', dataIndex: 'visitorType', key: 'visitorType', width: 110 },
  { title: '手机号', dataIndex: 'visitorPhone', key: 'visitorPhone', width: 130 },
  { title: '证件号', dataIndex: 'visitorIdNoMasked', key: 'visitorIdNoMasked', width: 175 },
  { title: '被访人', dataIndex: 'hostName', key: 'hostName', width: 100 },
  { title: '到访时段', key: 'visitPeriod', width: 235 },
  { title: '进校时刻', key: 'checkinAt', width: 145 },
  { title: '离校时刻', key: 'checkoutAt', width: 145 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 135 },
  { title: '事由', dataIndex: 'reason', key: 'reason', width: 190 },
  {
    title: '操作',
    key: 'actions',
    width: 70,
    customHeaderCell: () => ({ class: 'operations-column no-print' }),
    customCell: () => ({ class: 'operations-column no-print' }),
  },
];

const pagination = computed(() => ({
  current: page.value,
  pageSize: pageSize.value,
  total: total.value,
  showSizeChanger: true,
  pageSizeOptions: ['20', '50', '100'],
  showTotal: (value: number) => `共 ${value} 条`,
}));

const filterSummary = computed(() => {
  const entries = [
    filters.name && `姓名：${filters.name}`,
    filters.idNo && `证件号：${filters.idNo}`,
    filters.phone && `手机号：${filters.phone}`,
    filters.host && `被访人：${filters.host}`,
    filters.type && `访客类型：${filters.type}`,
    filters.status && `状态：${filters.status}`,
    filters.dateRange && `到访日期：${filters.dateRange[0].format('YYYY-MM-DD')} 至 ${filters.dateRange[1].format('YYYY-MM-DD')}`,
  ].filter(Boolean);
  return entries.length > 0 ? entries.join('；') : '全部记录';
});

function setGuardDate(): void {
  if (!isGuard.value) return;
  const today = dayjs();
  filters.dateRange = [today, today];
}

function requestParams(): Record<string, unknown> {
  const params: Record<string, unknown> = {};
  if (filters.name) params.name = filters.name;
  if (filters.idNo) params.idNo = filters.idNo;
  if (filters.phone) params.phone = filters.phone;
  if (filters.host) params.host = filters.host;
  if (filters.type) params.type = filters.type;
  if (filters.status) params.status = filters.status;
  if (filters.dateRange) {
    params.dateFrom = filters.dateRange[0].format('YYYY-MM-DD');
    params.dateTo = filters.dateRange[1].format('YYYY-MM-DD');
  }
  return params;
}

async function load(): Promise<void> {
  loading.value = true;
  failed.value = false;
  try {
    const response = await apiClient.get('/logs', {
      params: { ...requestParams(), page: page.value, pageSize: pageSize.value },
    });
    items.value = (response.data.data.items ?? []) as LedgerItem[];
    total.value = Number(response.data.data.total ?? 0);
  } catch {
    failed.value = true;
    items.value = [];
    total.value = 0;
  } finally {
    loading.value = false;
  }
}

function applyFilters(): void {
  page.value = 1;
  void load();
}

function resetFilters(): void {
  filters.name = '';
  filters.idNo = '';
  filters.phone = '';
  filters.host = '';
  filters.type = '';
  filters.status = undefined;
  filters.dateRange = undefined;
  setGuardDate();
  page.value = 1;
  void load();
}

function markFilterChanged(): void {
  page.value = 1;
}

function onPageChange(next: { current?: number; pageSize?: number }): void {
  page.value = next.current ?? 1;
  pageSize.value = next.pageSize ?? pageSize.value;
  void load();
}

function fileNameFromDisposition(header: unknown): string | null {
  if (typeof header !== 'string') return null;
  const encoded = header.match(/filename\*=UTF-8''([^;]+)/i);
  if (encoded?.[1]) {
    try {
      return decodeURIComponent(encoded[1].replace(/^"|"$/g, ''));
    } catch {
      return null;
    }
  }
  const plain = header.match(/filename="?([^";]+)"?/i);
  return plain?.[1] ?? null;
}

async function errorCopy(error: unknown): Promise<string> {
  const responseData = (error as { response?: { data?: unknown } }).response?.data;
  if (responseData instanceof Blob) {
    try {
      const parsed = JSON.parse(await responseData.text()) as { message?: string };
      if (parsed.message) return parsed.message;
    } catch {
      return '系统暂时无法处理，请稍后重试';
    }
  }
  if (
    responseData &&
    typeof responseData === 'object' &&
    'message' in responseData &&
    typeof (responseData as { message?: unknown }).message === 'string'
  ) {
    return (responseData as { message: string }).message;
  }
  return '系统暂时无法处理，请稍后重试';
}

function downloadBlob(blob: Blob, fileName: string): void {
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = fileName;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 0);
}

async function exportLedger(format: 'csv' | 'xlsx'): Promise<void> {
  if (!isAdmin.value || exporting.value) return;
  exporting.value = true;
  try {
    const response = await apiClient.get('/logs/export', {
      params: { ...requestParams(), format },
      responseType: 'blob',
    });
    const fallback = `访客台账_${dayjs().format('YYYYMMDD_HHmmss')}.${format}`;
    const fileName = fileNameFromDisposition(response.headers['content-disposition']) ?? fallback;
    downloadBlob(response.data as Blob, fileName);
    message.success('导出完成');
  } catch (error) {
    message.error(await errorCopy(error));
  } finally {
    exporting.value = false;
  }
}

function handleExportMenu({ key }: { key: string }): void {
  if (key === 'csv' || key === 'xlsx') {
    void exportLedger(key);
  }
}

function printLedger(): void {
  if (!isAdmin.value || printing.value) return;
  printing.value = true;
  message.info('正在准备打印...');
  window.setTimeout(() => {
    window.print();
    printing.value = false;
  }, 0);
}

onMounted(() => {
  setGuardDate();
  void load();
});
</script>

<template>
  <div class="report-page ledger-page">
    <PageHeader title="访客台账">
      <template #actions>
        <template v-if="isAdmin">
          <a-dropdown :disabled="exporting">
            <a-button :loading="exporting" :disabled="exporting">
              {{ exporting ? '正在导出，请稍候...' : '导出' }}
            </a-button>
            <template #overlay>
              <a-menu @click="handleExportMenu">
                <a-menu-item key="csv">导出 CSV</a-menu-item>
                <a-menu-item key="xlsx">导出 Excel</a-menu-item>
              </a-menu>
            </template>
          </a-dropdown>
          <a-button :loading="printing" :disabled="printing" @click="printLedger">打印</a-button>
        </template>
      </template>
    </PageHeader>

    <section class="filter-card page-card report-filters no-print">
      <a-form layout="vertical">
        <div class="filter-grid">
          <a-form-item label="访客姓名">
            <a-input v-model:value="filters.name" allow-clear @change="markFilterChanged" />
          </a-form-item>
          <a-form-item label="证件号">
            <a-input v-model:value="filters.idNo" allow-clear @change="markFilterChanged" />
          </a-form-item>
          <a-form-item label="手机号">
            <a-input v-model:value="filters.phone" allow-clear @change="markFilterChanged" />
          </a-form-item>
          <a-form-item label="被访人">
            <a-input v-model:value="filters.host" allow-clear @change="markFilterChanged" />
          </a-form-item>
          <a-form-item label="访客类型">
            <a-input v-model:value="filters.type" allow-clear @change="markFilterChanged" />
          </a-form-item>
          <a-form-item label="状态">
            <a-select
              v-model:value="filters.status"
              allow-clear
              :options="statusOptions"
              placeholder="全部状态"
              @change="markFilterChanged"
            />
          </a-form-item>
          <a-form-item label="到访日期">
            <a-range-picker
              v-model:value="filters.dateRange"
              :disabled="isGuard"
              :allow-clear="!isGuard"
              format="YYYY-MM-DD"
              @change="markFilterChanged"
            />
          </a-form-item>
          <a-form-item label=" ">
            <a-space>
              <a-button type="primary" :loading="loading" :disabled="loading" @click="applyFilters">
                查询
              </a-button>
              <a-button :loading="loading" :disabled="loading" @click="resetFilters">重置</a-button>
            </a-space>
          </a-form-item>
        </div>
      </a-form>
    </section>

    <p class="print-only print-meta">访客台账 · {{ filterSummary }}</p>

    <LoadingState v-if="loading" />
    <ErrorState v-else-if="failed" @retry="load" />
    <EmptyState v-else-if="items.length === 0" description="没有符合条件的访客记录" />
    <section v-else class="table-card page-card">
      <a-table
        row-key="appointmentId"
        :columns="columns"
        :data-source="items"
        :pagination="pagination"
        :scroll="{ x: 1680 }"
        @change="onPageChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'visitorName'">{{ record.visitorName || '—' }}</template>
          <template v-else-if="column.key === 'visitorPhone'">{{ record.visitorPhone || '—' }}</template>
          <template v-else-if="column.key === 'visitorIdNoMasked'">{{ record.visitorIdNoMasked || '—' }}</template>
          <template v-else-if="column.key === 'visitPeriod'">{{ formatVisitPeriod(record) }}</template>
          <template v-else-if="column.key === 'checkinAt'">{{ formatDateTime(record.checkinAt) || '—' }}</template>
          <template v-else-if="column.key === 'checkoutAt'">{{ formatDateTime(record.checkoutAt) || '—' }}</template>
          <template v-else-if="column.key === 'status'"><StatusTag :status="record.status" /></template>
          <template v-else-if="column.key === 'actions'">—</template>
        </template>
      </a-table>
    </section>
  </div>
</template>

<style scoped>
.filter-card {
  padding: var(--space-5);
  margin-bottom: var(--space-5);
}

.filter-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(180px, 1fr));
  gap: 0 var(--space-4);
}

.filter-grid :deep(.ant-form-item) {
  margin-bottom: var(--space-3);
}

.table-card {
  padding: var(--space-4);
}

.print-meta {
  display: none;
  margin-bottom: var(--space-3);
  color: var(--color-text-secondary);
  font-size: var(--font-size-sm);
}

@media (max-width: 1200px) {
  .filter-grid {
    grid-template-columns: repeat(2, minmax(180px, 1fr));
  }
}
</style>
