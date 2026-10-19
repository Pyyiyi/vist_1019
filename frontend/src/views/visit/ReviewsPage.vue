<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { message } from 'ant-design-vue';
import dayjs, { type Dayjs } from 'dayjs';

import apiClient from '@/api/client';
import { accessiblePaginationItem } from '@/utils/pagination';
import ConfirmDialog from '@/components/ConfirmDialog.vue';
import EmptyState from '@/components/EmptyState.vue';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import PageHeader from '@/components/PageHeader.vue';
import StatusTag from '@/components/StatusTag.vue';
import { useAuthStore } from '@/stores/auth';
import { formatRange, formatSecond, serverMessage } from './helpers';
import type { AppointmentItem, VisitFormOptions } from './types';

const authStore = useAuthStore();
const loading = ref(true);
const failed = ref(false);
const items = ref<AppointmentItem[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(20);
const actionLoadingId = ref<string | null>(null);
const approveTarget = ref<AppointmentItem | null>(null);
const approveConfirm = ref<{ openDialog: () => void } | null>(null);
const rejectOpen = ref(false);
const rejectTarget = ref<AppointmentItem | null>(null);
const rejectReason = ref('');
const rejectSaving = ref(false);
const rescheduleOpen = ref(false);
const rescheduleTarget = ref<AppointmentItem | null>(null);
const rescheduleStart = ref<Dayjs | null>(null);
const rescheduleEnd = ref<Dayjs | null>(null);
const rescheduleSaving = ref(false);
const detailOpen = ref(false);
const detail = ref<AppointmentItem | null>(null);
const logs = ref<Array<{ id: string; time: string; operator: string; decision: string; reason: string }>>([]);
const logsLoading = ref(false);
const logsFailed = ref(false);
const logAppointNo = ref('');
const ruleOpen = ref(false);
const rulesLoading = ref(false);
const rulesSaving = ref(false);
const rules = ref<Array<Record<string, unknown>>>([]);
const options = ref<VisitFormOptions>({ visitorTypes: [], hosts: [], gates: [], relations: [] });

const isAdmin = computed(() => authStore.role === 'admin');
const columns = [
  { title: '预约编号', dataIndex: 'appointNo', key: 'appointNo', width: 170 },
  { title: '访客', dataIndex: 'visitorName', key: 'visitorName', width: 100 },
  { title: '类型', dataIndex: 'visitorTypeName', key: 'visitorTypeName', width: 110 },
  { title: '到访时段', key: 'visitRange', width: 240 },
  { title: '事由', dataIndex: 'reason', key: 'reason', width: 220 },
  { title: '操作', key: 'actions', width: 260, fixed: 'right' as const },
];
const pagination = computed(() => ({ itemRender: accessiblePaginationItem, current: page.value, pageSize: pageSize.value, total: total.value, showSizeChanger: false, showTotal: (value: number) => `共 ${value} 条` }));

async function load(): Promise<void> {
  loading.value = true;
  failed.value = false;
  try {
    const response = await apiClient.get('/reviews', { params: { page: page.value, pageSize: pageSize.value } });
    items.value = (response.data.data.items ?? []) as AppointmentItem[];
    total.value = Number(response.data.data.total ?? 0);
  } catch {
    failed.value = true;
    items.value = [];
    total.value = 0;
  } finally {
    loading.value = false;
  }
}

async function loadOptions(): Promise<void> {
  if (!isAdmin.value) return;
  try {
    const response = await apiClient.get('/appointments/form-options');
    options.value = response.data.data as VisitFormOptions;
  } catch {
    // Reviewer rules still render; dropdowns can be empty when options fail.
  }
}

function onPageChange(next: { current?: number }): void { page.value = next.current ?? 1; void load(); }

function openApprove(row: AppointmentItem): void { approveTarget.value = row; approveConfirm.value?.openDialog(); }

async function confirmApprove(): Promise<void> {
  if (!approveTarget.value) return;
  actionLoadingId.value = approveTarget.value.id;
  try {
    await apiClient.post(`/reviews/${approveTarget.value.id}/approve`);
    message.success('已同意该预约');
    await load();
  } catch (error) {
    message.error(serverMessage(error));
  } finally {
    actionLoadingId.value = null;
  }
}

function openReject(row: AppointmentItem): void { rejectTarget.value = row; rejectReason.value = ''; rejectOpen.value = true; }

async function submitReject(): Promise<void> {
  if (!rejectTarget.value) return;
  if (!rejectReason.value.trim()) { message.warning('请填写拒绝原因'); return; }
  if (rejectReason.value.trim().length < 2) { message.warning('拒绝原因至少 2 个字符'); return; }
  if (rejectReason.value.trim().length > 100) { message.warning('拒绝原因不能超过 100 个字符'); return; }
  rejectSaving.value = true;
  actionLoadingId.value = rejectTarget.value.id;
  try {
    await apiClient.post(`/reviews/${rejectTarget.value.id}/reject`, { reason: rejectReason.value.trim() });
    message.success('已拒绝该预约，访客将收到拒绝原因');
    rejectOpen.value = false;
    await load();
  } catch (error) {
    message.error(serverMessage(error));
  } finally {
    rejectSaving.value = false;
    actionLoadingId.value = null;
  }
}

function openReschedule(row: AppointmentItem): void {
  rescheduleTarget.value = row;
  rescheduleStart.value = dayjs(row.visitStart);
  rescheduleEnd.value = dayjs(row.visitEnd);
  rescheduleOpen.value = true;
}

async function submitReschedule(): Promise<void> {
  if (!rescheduleTarget.value || !rescheduleStart.value || !rescheduleEnd.value) return;
  rescheduleSaving.value = true;
  actionLoadingId.value = rescheduleTarget.value.id;
  try {
    await apiClient.post(`/reviews/${rescheduleTarget.value.id}/reschedule`, { visitStart: rescheduleStart.value.toISOString(), visitEnd: rescheduleEnd.value.toISOString() });
    message.success('改期提议已发送，等待访客确认');
    rescheduleOpen.value = false;
    await load();
  } catch (error) {
    message.error(serverMessage(error));
  } finally {
    rescheduleSaving.value = false;
    actionLoadingId.value = null;
  }
}

async function loadLogs(id: string): Promise<void> {
  logsLoading.value = true;
  logsFailed.value = false;
  try {
    const response = await apiClient.get(`/reviews/${id}/logs`);
    logs.value = response.data.data.items ?? [];
  } catch {
    logsFailed.value = true;
    logs.value = [];
  } finally {
    logsLoading.value = false;
  }
}

async function openDetail(row: AppointmentItem): Promise<void> {
  detailOpen.value = true;
  detail.value = row;
  await loadLogs(row.id);
}

function searchLog(): void {
  const target = items.value.find((row) => row.appointNo === logAppointNo.value.trim());
  if (!target) { message.warning('暂无审核记录'); logs.value = []; return; }
  void openDetail(target);
}

async function openRules(): Promise<void> {
  ruleOpen.value = true;
  rulesLoading.value = true;
  try {
    const response = await apiClient.get('/reviews/assignment');
    rules.value = (response.data.data.rules ?? []) as Array<Record<string, unknown>>;
  } catch (error) {
    message.error(serverMessage(error));
  } finally {
    rulesLoading.value = false;
  }
}

function addRule(): void {
  rules.value.push({ visitorTypeId: null, gateId: null, startTime: null, endTime: null, reviewerKind: 'host', reviewerUserId: null, declarationOrder: rules.value.length + 1, status: 'active' });
}

function removeRule(index: number): void { rules.value.splice(index, 1); }

async function saveRules(): Promise<void> {
  rulesSaving.value = true;
  try {
    await apiClient.put('/reviews/assignment', { rules: rules.value });
    message.success('保存成功');
    ruleOpen.value = false;
  } catch (error) {
    message.error(serverMessage(error));
  } finally {
    rulesSaving.value = false;
  }
}

onMounted(async () => { await Promise.all([load(), loadOptions()]); });
</script>

<template>
  <section>
    <PageHeader title="被访人审核">
      <template #actions><a-button v-if="isAdmin" @click="openRules">审核人配置</a-button></template>
    </PageHeader>

    <div class="page-card section-card">
      <div class="section-title-row"><h2>待审核预约</h2><span class="count-text">共 {{ total }} 条</span></div>
      <LoadingState v-if="loading" />
      <ErrorState v-else-if="failed" @retry="load" />
      <EmptyState v-else-if="items.length === 0" description="暂无待审核预约" />
      <a-table v-else row-key="id" :columns="columns" :data-source="items" :pagination="pagination" :scroll="{ x: 1080 }" @change="onPageChange">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'visitRange'">{{ formatRange(record.visitStart, record.visitEnd) }}</template>
          <template v-else-if="column.key === 'status'"><StatusTag :status="record.status" /></template>
          <template v-else-if="column.key === 'actions'">
            <a-space>
              <a-button type="link" size="small" :loading="actionLoadingId === record.id" @click="openApprove(record)">同意</a-button>
              <a-button type="link" size="small" danger :loading="actionLoadingId === record.id" @click="openReject(record)">拒绝</a-button>
              <a-button type="link" size="small" :loading="actionLoadingId === record.id" @click="openReschedule(record)">提议改期</a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </div>

    <div v-if="isAdmin" class="page-card section-card rules-card">
      <h2>审核人配置</h2>
      <p>未配置规则时，由被访教职工本人审核</p>
      <a-button type="primary" :loading="rulesLoading" @click="openRules">审核人配置</a-button>
    </div>

    <div class="page-card section-card">
      <h2>审核留痕</h2>
      <a-space class="log-search"><a-input v-model:value="logAppointNo" placeholder="输入预约编号筛选" allow-clear /><a-button @click="searchLog">查询</a-button></a-space>
      <LoadingState v-if="logsLoading" :rows="3" />
      <ErrorState v-else-if="logsFailed" @retry="detail && loadLogs(detail.id)" />
      <EmptyState v-else-if="logs.length === 0" description="暂无审核记录" />
      <a-table v-else row-key="id" size="small" :pagination="false" :data-source="logs" :columns="[{ title: '时间', dataIndex: 'time', key: 'time' }, { title: '审核人', dataIndex: 'operator', key: 'operator' }, { title: '审核决定', dataIndex: 'decision', key: 'decision' }, { title: '说明', dataIndex: 'reason', key: 'reason' }]" />
    </div>

    <ConfirmDialog ref="approveConfirm" title="确认同意该预约" content="同意后预约进入已通过，访客将收到审核结果通知。是否继续？" ok-text="同意" @confirm="confirmApprove" />

    <a-modal v-model:open="rejectOpen" title="拒绝预约" :confirm-loading="rejectSaving" ok-text="拒绝" cancel-text="取消" :mask-closable="false" @ok="submitReject">
      <a-form layout="vertical"><a-form-item label="拒绝原因"><a-textarea v-model:value="rejectReason" placeholder="请输入 2–100 字的拒绝原因" :rows="4" /></a-form-item></a-form>
    </a-modal>

    <a-modal v-model:open="rescheduleOpen" title="提议新的到访时段" :confirm-loading="rescheduleSaving" ok-text="发送改期提议" cancel-text="取消" :mask-closable="false" @ok="submitReschedule">
      <a-alert type="info" show-icon message="访客需在 3 小时内确认，逾期预约将自动过期" class="modal-alert" />
      <a-form layout="vertical">
        <a-form-item label="开始时间"><a-date-picker v-model:value="rescheduleStart" show-time format="YYYY-MM-DD HH:mm" style="width: 100%" /></a-form-item>
        <a-form-item label="结束时间"><a-date-picker v-model:value="rescheduleEnd" show-time format="YYYY-MM-DD HH:mm" style="width: 100%" /></a-form-item>
      </a-form>
    </a-modal>

    <a-drawer v-model:open="detailOpen" title="预约详情" width="520">
      <template v-if="detail">
        <p><strong>{{ detail.appointNo }}</strong> · <StatusTag :status="detail.status" /></p>
        <p>{{ detail.visitorName }} · {{ detail.visitorPhone }}</p>
        <p>{{ detail.hostName }} · {{ formatRange(detail.visitStart, detail.visitEnd) }}</p>
        <p>事由：{{ detail.reason }}</p>
        <a-divider />
        <h3>审核留痕</h3>
        <a-timeline v-if="logs.length">
          <a-timeline-item v-for="log in logs" :key="log.id"><strong>{{ log.decision }}</strong><p>{{ formatSecond(log.time) }} · {{ log.operator }} · {{ log.reason }}</p></a-timeline-item>
        </a-timeline>
        <p v-else class="muted">暂无审核记录</p>
      </template>
    </a-drawer>

    <a-drawer v-model:open="ruleOpen" title="审核人配置" width="720">
      <p class="muted">未配置规则时，由被访教职工本人审核</p>
      <LoadingState v-if="rulesLoading" :rows="3" />
      <template v-else>
        <div v-for="(rule, index) in rules" :key="index" class="rule-row">
          <a-select v-model:value="rule.visitorTypeId" allow-clear placeholder="访客类型" :options="options.visitorTypes.map((item) => ({ label: item.name, value: item.id }))" />
          <a-select v-model:value="rule.gateId" allow-clear placeholder="校门" :options="options.gates.map((item) => ({ label: item.name, value: item.id }))" />
          <a-input v-model:value="rule.startTime" placeholder="开始 HH:mm" />
          <a-input v-model:value="rule.endTime" placeholder="结束 HH:mm" />
          <a-select v-model:value="rule.reviewerKind" :options="[{ label: '被访人', value: 'host' }, { label: '管理员', value: 'admin' }, { label: '指定人员', value: 'designated' }]" />
          <a-input v-if="rule.reviewerKind === 'designated'" v-model:value="rule.reviewerUserId" placeholder="审核人用户 ID" />
          <a-button danger type="link" @click="removeRule(index)">移除</a-button>
        </div>
        <a-space><a-button @click="addRule">新增规则</a-button><a-button type="primary" :loading="rulesSaving" @click="saveRules">保存</a-button></a-space>
      </template>
    </a-drawer>
  </section>
</template>

<style scoped>
.section-card { margin-bottom: var(--space-4); padding: var(--space-5); }
.section-card h2 { margin-bottom: var(--space-3); font-size: var(--font-size-lg); }
.section-title-row { display: flex; align-items: center; justify-content: space-between; }
.count-text, .muted { color: var(--color-text-secondary); }
.rules-card p { margin-bottom: var(--space-3); color: var(--color-text-secondary); }
.log-search { margin-bottom: var(--space-3); }
.modal-alert { margin-bottom: var(--space-4); }
.rule-row { display: grid; grid-template-columns: repeat(4, 1fr) 120px auto; gap: var(--space-2); margin-bottom: var(--space-2); }
</style>
