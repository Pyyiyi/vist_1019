<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { message } from 'ant-design-vue';
import dayjs from 'dayjs';

import apiClient from '@/api/client';
import { accessiblePaginationItem } from '@/utils/pagination';
import ConfirmDialog from '@/components/ConfirmDialog.vue';
import EmptyState from '@/components/EmptyState.vue';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import PageHeader from '@/components/PageHeader.vue';

type PrivacyCase = {
  id: string;
  object: string;
  caseType: '信息副本' | '人工清除';
  description: string;
  status: '已完成' | '失败';
  handledBy: string;
  handledAt: string;
};

const RETENTION_ERROR = '留存期限必须是大于 0 的整数';
const columns = [
  { title: '对象', key: 'object', dataIndex: 'object', width: 200, ellipsis: true },
  { title: '类型', key: 'caseType', dataIndex: 'caseType', width: 110 },
  { title: '说明', key: 'description', dataIndex: 'description', ellipsis: true },
  { title: '状态', key: 'status', dataIndex: 'status', width: 96 },
  { title: '处置人', key: 'handledBy', dataIndex: 'handledBy', width: 130, ellipsis: true },
  { title: '时间', key: 'handledAt', dataIndex: 'handledAt', width: 176 },
];

const retentionLoading = ref(true);
const retentionFailed = ref(false);
const retentionSaving = ref(false);
const retentionValue = ref<number | null>(null);
const auditRetentionDays = ref<number | null>(null);
const retentionError = ref('');

const eraseSubmitting = ref(false);
const eraseFailed = ref('');
const eraseDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null);
const eraseForm = reactive({ appointmentId: '', reason: '' });
const eraseErrors = reactive<Record<string, string>>({});

const casesLoading = ref(true);
const casesFailed = ref(false);
const cases = ref<PrivacyCase[]>([]);
const casesTotal = ref(0);
const casesPage = ref(1);
const casesPageSize = ref(20);

function serverMessage(error: unknown): string {
  const candidate = error as { response?: { data?: { message?: string; field?: string } } };
  return candidate.response?.data?.message ?? '系统暂时无法处理，请稍后重试';
}

function serverField(error: unknown): string | undefined {
  const candidate = error as { response?: { data?: { field?: string } } };
  return candidate.response?.data?.field;
}

async function loadRetention(): Promise<void> {
  retentionLoading.value = true;
  retentionFailed.value = false;
  try {
    const response = await apiClient.get('/privacy/retention');
    retentionValue.value = Number(response.data.data.retentionDays);
    auditRetentionDays.value = Number(response.data.data.auditRetentionDays);
    retentionError.value = '';
  } catch {
    retentionFailed.value = true;
    retentionValue.value = null;
  } finally {
    retentionLoading.value = false;
  }
}

function onRetentionInput(value: number | null): void {
  if (Number.isInteger(value) && (value ?? 0) > 0) retentionError.value = '';
}

async function saveRetention(): Promise<void> {
  const value = retentionValue.value;
  if (!Number.isInteger(value) || (value ?? 0) <= 0) {
    retentionError.value = RETENTION_ERROR;
    return;
  }
  retentionSaving.value = true;
  retentionError.value = '';
  try {
    const response = await apiClient.put('/privacy/retention', { retentionDays: value });
    retentionValue.value = Number(response.data.data.retentionDays);
    auditRetentionDays.value = Number(response.data.data.auditRetentionDays);
    message.success('留存期限已保存');
  } catch (error) {
    retentionError.value = serverMessage(error);
  } finally {
    retentionSaving.value = false;
  }
}

function validateErase(): boolean {
  eraseErrors.appointmentId = eraseForm.appointmentId.trim() ? '' : '请输入预约编号';
  eraseErrors.reason = eraseForm.reason.trim() ? '' : '请输入清除原因';
  return !eraseErrors.appointmentId && !eraseErrors.reason;
}

function requestErase(): void {
  eraseFailed.value = '';
  if (!validateErase()) return;
  eraseDialog.value?.openDialog();
}

async function confirmErase(): Promise<void> {
  eraseSubmitting.value = true;
  eraseFailed.value = '';
  try {
    await apiClient.post(`/privacy/appointments/${encodeURIComponent(eraseForm.appointmentId.trim())}/erase`, {
      reason: eraseForm.reason.trim(),
    });
    message.success('个人信息已清除');
    eraseForm.appointmentId = '';
    eraseForm.reason = '';
    eraseErrors.appointmentId = '';
    eraseErrors.reason = '';
    casesPage.value = 1;
    await loadCases();
  } catch (error) {
    eraseFailed.value = serverMessage(error);
    if (serverField(error) === 'reason') eraseErrors.reason = serverMessage(error);
  } finally {
    eraseSubmitting.value = false;
  }
}

async function loadCases(): Promise<void> {
  casesLoading.value = true;
  casesFailed.value = false;
  try {
    const response = await apiClient.get('/privacy/cases', {
      params: { page: casesPage.value, page_size: casesPageSize.value },
    });
    const data = response.data.data;
    cases.value = data.items as PrivacyCase[];
    casesTotal.value = Number(data.total ?? 0);
  } catch {
    casesFailed.value = true;
    cases.value = [];
    casesTotal.value = 0;
  } finally {
    casesLoading.value = false;
  }
}

function onCasesPageChange(pagination: { current?: number; pageSize?: number }): void {
  casesPage.value = pagination.current ?? 1;
  casesPageSize.value = pagination.pageSize ?? 20;
  void loadCases();
}

function formatTime(value: string): string {
  return dayjs(value).format('YYYY-MM-DD HH:mm:ss');
}

onMounted(() => {
  void Promise.all([loadRetention(), loadCases()]);
});
</script>

<template>
  <section class="privacy-admin-page">
    <PageHeader title="信息保护" />

    <a-card class="privacy-section" :bordered="false">
      <h2 class="section-title">留存设置</h2>
      <LoadingState v-if="retentionLoading" />
      <ErrorState v-else-if="retentionFailed" @retry="loadRetention" />
      <EmptyState v-else-if="retentionValue === null" description="暂无数据" />
      <div v-else class="retention-content">
        <label class="field-label" for="retention-days">个人信息留存期限（天）</label>
        <p class="section-help">超过留存期限的记录在界面与导出中显示脱敏信息，原始数据按制度保留用于安全追溯</p>
        <div class="retention-row">
          <a-input-number
            id="retention-days"
            v-model:value="retentionValue"
            :precision="0"
            class="retention-input"
            @change="onRetentionInput"
          />
          <a-button type="primary" :loading="retentionSaving" :disabled="retentionSaving" @click="saveRetention">保存</a-button>
          <span v-if="auditRetentionDays !== null" class="audit-retention">审计日志保留 {{ auditRetentionDays }} 天</span>
        </div>
        <p v-if="retentionError" class="field-error">{{ retentionError }}</p>
      </div>
    </a-card>

    <a-card class="privacy-section" :bordered="false">
      <h2 class="section-title">人工清除个人信息</h2>
      <p class="section-help">输入预约编号后，该预约的姓名、手机号、证件号将从主记录中物理清除，操作日志保留</p>
      <a-alert v-if="eraseFailed" type="error" show-icon :message="eraseFailed" class="erase-error">
        <template #action><a-button size="small" @click="requestErase">重试</a-button></template>
      </a-alert>
      <a-form layout="vertical" class="erase-form">
        <a-form-item label="预约编号" :validate-status="eraseErrors.appointmentId ? 'error' : undefined" :help="eraseErrors.appointmentId || undefined">
          <a-input v-model:value="eraseForm.appointmentId" allow-clear placeholder="请输入预约编号" @change="eraseErrors.appointmentId = ''" />
        </a-form-item>
        <a-form-item label="清除原因" :validate-status="eraseErrors.reason ? 'error' : undefined" :help="eraseErrors.reason || undefined">
          <a-textarea v-model:value="eraseForm.reason" :rows="3" :maxlength="200" show-count placeholder="请输入清除原因" @change="eraseErrors.reason = ''" />
        </a-form-item>
        <a-button danger type="primary" :loading="eraseSubmitting" :disabled="eraseSubmitting" @click="requestErase">确认清除</a-button>
      </a-form>
    </a-card>

    <a-card class="privacy-section cases-section" :bordered="false">
      <h2 class="section-title">隐私处理记录</h2>
      <LoadingState v-if="casesLoading" />
      <ErrorState v-else-if="casesFailed" @retry="loadCases" />
      <EmptyState v-else-if="cases.length === 0" description="暂无处理记录" />
      <a-table
        v-else
        row-key="id"
        :columns="columns"
        :data-source="cases"
        :pagination="{ current: casesPage, pageSize: casesPageSize, total: casesTotal, showSizeChanger: true, itemRender: accessiblePaginationItem, showTotal: (value: number) => `共 ${value} 条` }"
        :scroll="{ x: 860 }"
        @change="onCasesPageChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'object'">
            <a-tooltip :title="record.object"><span class="single-line">{{ record.object }}</span></a-tooltip>
          </template>
          <template v-else-if="column.key === 'description'">
            <a-tooltip :title="record.description"><span class="single-line">{{ record.description || '—' }}</span></a-tooltip>
          </template>
          <template v-else-if="column.key === 'status'">
            <a-tag :color="record.status === '已完成' ? 'green' : 'red'">{{ record.status }}</a-tag>
          </template>
          <template v-else-if="column.key === 'handledAt'">{{ formatTime(record.handledAt) }}</template>
        </template>
      </a-table>
    </a-card>

    <ConfirmDialog
      ref="eraseDialog"
      title="确认清除个人信息"
      content="清除后主记录中的姓名、手机号、证件号不可恢复，操作日志中的记录保留。是否继续？"
      ok-text="确认清除"
      danger
      @confirm="confirmErase"
    />
  </section>
</template>

<style scoped>
.privacy-admin-page { display: flex; min-width: 0; flex-direction: column; gap: var(--space-4); }
.privacy-section { min-width: 0; overflow: hidden; }
.section-title { margin: 0 0 var(--space-3); color: var(--color-text-primary); font-size: var(--font-size-lg); font-weight: 600; }
.section-help { margin: 0 0 var(--space-4); color: var(--color-text-secondary); line-height: var(--line-height-base); }
.retention-content { max-width: 720px; }
.field-label { display: block; margin-bottom: 6px; color: var(--color-text-primary); font-weight: 600; }
.retention-row { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-3); }
.retention-input { width: 180px; }
.audit-retention { color: var(--color-text-secondary); font-size: var(--font-size-sm); }
.field-error { margin-top: 6px; color: var(--color-error); font-size: var(--font-size-sm); }
.erase-form { max-width: 720px; }
.erase-error { margin-bottom: var(--space-3); }
.single-line { display: block; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
</style>
