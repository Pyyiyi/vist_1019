<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { message } from 'ant-design-vue';
import dayjs, { type Dayjs } from 'dayjs';
import { useRoute, useRouter } from 'vue-router';

import apiClient from '@/api/client';
import { accessiblePaginationItem } from '@/utils/pagination';
import ConfirmDialog from '@/components/ConfirmDialog.vue';
import CopyButton from '@/components/CopyButton.vue';
import EmptyState from '@/components/EmptyState.vue';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import PageHeader from '@/components/PageHeader.vue';
import StatusTag from '@/components/StatusTag.vue';
import AppointmentForm from './AppointmentForm.vue';
import { canReschedule, formatMinute, formatRange, formatSecond, isTerminal, serverMessage } from './helpers';
import type { AppointmentItem, VisitFormOptions } from './types';

const route = useRoute();
const router = useRouter();
const loading = ref(true);
const failed = ref(false);
const items = ref<AppointmentItem[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(20);
const formOpen = ref(false);
const detailOpen = ref(false);
const detailLoading = ref(false);
const detailFailed = ref(false);
const detail = ref<AppointmentItem | null>(null);
const rescheduleOpen = ref(false);
const rescheduleSaving = ref(false);
const rescheduleStart = ref<Dayjs | null>(null);
const rescheduleEnd = ref<Dayjs | null>(null);
const rescheduleTarget = ref<AppointmentItem | null>(null);
const cancelTarget = ref<AppointmentItem | null>(null);
const cancelReason = ref('');
const cancelOpen = ref(false);
const cancelSaving = ref(false);
const cancelConfirm = ref<{ openDialog: () => void } | null>(null);
const actionLoadingId = ref<string | null>(null);

const dateRange = ref<[Dayjs, Dayjs] | null>(null);
const filters = reactive({ visitorName: '', status: undefined as string | undefined });
const options = ref<VisitFormOptions>({ visitorTypes: [], hosts: [], gates: [], relations: [] });
const statusOptions = ['待审核', '已通过', '已拒绝', '已改期', '已过期', '已到访(在校中)', '已离校', '已取消'].map((value) => ({ label: value, value }));

const columns = [
  { title: '预约编号', dataIndex: 'appointNo', key: 'appointNo', width: 170 },
  { title: '访客', dataIndex: 'visitorName', key: 'visitorName', width: 110 },
  { title: '被访人', dataIndex: 'hostName', key: 'hostName', width: 110 },
  { title: '到访时段', key: 'visitRange', width: 240 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 130 },
  { title: '操作', key: 'actions', width: 220, fixed: 'right' as const },
];

const pagination = computed(() => ({ itemRender: accessiblePaginationItem, current: page.value, pageSize: pageSize.value, total: total.value, showSizeChanger: true, pageSizeOptions: ['20', '50', '100'], showTotal: (value: number) => `共 ${value} 条` }));

function queryParams(): Record<string, unknown> {
  return {
    page: page.value,
    pageSize: pageSize.value,
    visitorName: filters.visitorName || undefined,
    status: filters.status || undefined,
    dateFrom: dateRange.value?.[0]?.format('YYYY-MM-DD'),
    dateTo: dateRange.value?.[1]?.format('YYYY-MM-DD'),
  };
}

async function load(): Promise<void> {
  loading.value = true;
  failed.value = false;
  try {
    const response = await apiClient.get('/appointments', { params: queryParams() });
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
  try {
    const response = await apiClient.get('/appointments/form-options');
    options.value = response.data.data as VisitFormOptions;
  } catch (error) {
    message.error(serverMessage(error));
  }
}

function search(): void { page.value = 1; void load(); }
function reset(): void { filters.visitorName = ''; filters.status = undefined; dateRange.value = null; page.value = 1; void load(); }
function onPageChange(next: { current?: number; pageSize?: number }): void { page.value = next.current ?? 1; pageSize.value = next.pageSize ?? 20; void load(); }

function clearDeepLink(): void {
  if (!route.query.appointmentId) return;
  const query = { ...route.query };
  delete query.appointmentId;
  void router.replace({ query });
}

async function openDetail(id: string): Promise<void> {
  detailOpen.value = true;
  detailLoading.value = true;
  detailFailed.value = false;
  detail.value = null;
  try {
    const response = await apiClient.get(`/appointments/${id}`);
    detail.value = response.data.data as AppointmentItem;
  } catch (error) {
    detailFailed.value = true;
    detailOpen.value = false;
    message.error(serverMessage(error));
    clearDeepLink();
  } finally {
    detailLoading.value = false;
  }
}

function applyDeepLink(): void {
  const id = typeof route.query.appointmentId === 'string' ? route.query.appointmentId : '';
  if (id) void openDetail(id);
}

function closeDetail(): void { detailOpen.value = false; clearDeepLink(); }

function rowAction(row: AppointmentItem, action: 'reschedule' | 'cancel'): void {
  if (!canReschedule(row.status) || isTerminal(row.status)) {
    message.warning('当前状态不允许该操作，请刷新后重试');
    return;
  }
  if (action === 'reschedule') {
    rescheduleTarget.value = row;
    rescheduleStart.value = dayjs(row.visitStart);
    rescheduleEnd.value = dayjs(row.visitEnd);
    rescheduleOpen.value = true;
  } else {
    cancelTarget.value = row;
    cancelReason.value = '';
    cancelConfirm.value?.openDialog();
  }
}

async function submitReschedule(): Promise<void> {
  if (!rescheduleTarget.value) return;
  if (!rescheduleStart.value || !rescheduleEnd.value) { message.warning('请选择到访时段'); return; }
  if (!rescheduleEnd.value.isAfter(rescheduleStart.value)) { message.warning('结束时间必须晚于开始时间'); return; }
  rescheduleSaving.value = true;
  actionLoadingId.value = rescheduleTarget.value.id;
  try {
    await apiClient.put(`/appointments/${rescheduleTarget.value.id}/reschedule`, {
      visitStart: rescheduleStart.value.toISOString(),
      visitEnd: rescheduleEnd.value.toISOString(),
    });
    message.success('改期成功');
    rescheduleOpen.value = false;
    await load();
    if (detailOpen.value && detail.value) await openDetail(detail.value.id);
  } catch (error) {
    message.error(serverMessage(error));
  } finally {
    rescheduleSaving.value = false;
    actionLoadingId.value = null;
  }
}

function openCancelReason(): void { cancelOpen.value = true; }

async function submitCancel(): Promise<void> {
  if (!cancelTarget.value) return;
  cancelSaving.value = true;
  actionLoadingId.value = cancelTarget.value.id;
  try {
    await apiClient.put(`/appointments/${cancelTarget.value.id}/cancel`, { reason: cancelReason.value.trim() || undefined });
    message.success('预约已取消');
    cancelOpen.value = false;
    await load();
    if (detailOpen.value && detail.value) await openDetail(detail.value.id);
  } catch (error) {
    message.error(serverMessage(error));
  } finally {
    cancelSaving.value = false;
    actionLoadingId.value = null;
  }
}

function onSubmitted(): void { void load(); }

watch(() => route.query.appointmentId, () => applyDeepLink());
onMounted(async () => { await Promise.all([load(), loadOptions()]); applyDeepLink(); });
</script>

<template>
  <section>
    <PageHeader title="访客预约">
      <template #actions><a-button type="primary" @click="formOpen = true">新增预约</a-button></template>
    </PageHeader>

    <div class="page-card filter-card">
      <a-form layout="inline">
        <a-form-item label="访客姓名"><a-input v-model:value="filters.visitorName" allow-clear style="width: 180px" @pressEnter="search" /></a-form-item>
        <a-form-item label="状态"><a-select v-model:value="filters.status" allow-clear placeholder="状态" style="width: 160px" :options="statusOptions" /></a-form-item>
        <a-form-item label="到访日期"><a-range-picker v-model:value="dateRange" /></a-form-item>
        <a-form-item><a-button type="primary" @click="search">查询</a-button><a-button class="reset-button" @click="reset">重置</a-button></a-form-item>
      </a-form>
    </div>

    <div class="page-card table-card">
      <LoadingState v-if="loading" />
      <ErrorState v-else-if="failed" @retry="load" />
      <EmptyState v-else-if="items.length === 0" description="还没有预约记录" />
      <a-table
        v-else
        row-key="id"
        :columns="columns"
        :data-source="items"
        :pagination="pagination"
        :scroll="{ x: 980 }"
        @change="onPageChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'visitRange'">{{ formatRange(record.visitStart, record.visitEnd) }}</template>
          <template v-else-if="column.key === 'status'"><StatusTag :status="record.status" /></template>
          <template v-else-if="column.key === 'actions'">
            <a-space>
              <a-button type="link" size="small" @click="openDetail(record.id)">查看详情</a-button>
              <a-button v-if="canReschedule(record.status)" type="link" size="small" :loading="actionLoadingId === record.id" @click="rowAction(record, 'reschedule')">改期</a-button>
              <a-button v-if="canReschedule(record.status)" type="link" danger size="small" :loading="actionLoadingId === record.id" @click="rowAction(record, 'cancel')">取消预约</a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </div>

    <AppointmentForm :open="formOpen" :options="options" @update:open="formOpen = $event" @submitted="onSubmitted" />

    <a-drawer :open="detailOpen" title="预约详情" width="560" @close="closeDetail">
      <LoadingState v-if="detailLoading" />
      <ErrorState v-else-if="detailFailed" @retry="detail && openDetail(detail.id)" />
      <div v-else-if="detail" class="detail-body">
        <div class="detail-row"><span>预约编号</span><strong>{{ detail.appointNo }}</strong><CopyButton :text="detail.appointNo" /></div>
        <div class="detail-row"><span>访客信息</span><strong>{{ detail.visitorName }} · {{ detail.visitorPhone }}</strong></div>
        <div class="detail-row"><span>被访人</span><strong>{{ detail.hostName }}</strong></div>
        <div class="detail-row"><span>到访时段</span><strong>{{ formatRange(detail.visitStart, detail.visitEnd) }}</strong></div>
        <div class="detail-row"><span>状态</span><StatusTag :status="detail.status" /></div>
        <div class="detail-row"><span>随行人员</span><strong>{{ detail.peopleCount - 1 }} 人</strong></div>
        <div v-if="detail.companions?.length" class="companion-list">
          <p v-for="person in detail.companions" :key="person.id || person.name">{{ person.name }} · {{ person.relation }} · {{ person.idNo }}</p>
        </div>
        <a-divider />
        <h3>预约进度</h3>
        <a-timeline v-if="detail.history?.length">
          <a-timeline-item v-for="item in detail.history" :key="item.id">
            <strong>{{ item.toStatus }}</strong>
            <p>{{ formatSecond(item.occurredAt) }} · {{ item.changeReason }}</p>
          </a-timeline-item>
        </a-timeline>
        <p v-else class="muted">暂无进度记录</p>
        <a-alert v-if="isTerminal(detail.status)" type="info" show-icon message="该申请已结束，如需来访请重新扫码申请" />
      </div>
    </a-drawer>

    <a-modal v-model:open="rescheduleOpen" title="修改到访时段" :confirm-loading="rescheduleSaving" ok-text="确定" cancel-text="取消" :mask-closable="false" @ok="submitReschedule">
      <a-form layout="vertical">
        <a-form-item label="开始时间"><a-date-picker v-model:value="rescheduleStart" show-time format="YYYY-MM-DD HH:mm" style="width: 100%" placeholder="请选择开始时间" /></a-form-item>
        <a-form-item label="结束时间"><a-date-picker v-model:value="rescheduleEnd" show-time format="YYYY-MM-DD HH:mm" style="width: 100%" placeholder="请选择结束时间" /></a-form-item>
      </a-form>
    </a-modal>

    <ConfirmDialog
      ref="cancelConfirm"
      title="确认取消预约"
      content="取消后该预约不能恢复，访客将收到取消通知。是否继续？"
      ok-text="确认取消预约"
      :danger="true"
      @confirm="openCancelReason"
    />
    <a-modal v-model:open="cancelOpen" title="确认取消预约" :confirm-loading="cancelSaving" ok-text="确认取消预约" cancel-text="取消" :mask-closable="false" @ok="submitCancel">
      <a-form layout="vertical">
        <a-form-item label="取消原因（选填）"><a-textarea v-model:value="cancelReason" placeholder="请说明取消原因" :rows="3" /></a-form-item>
      </a-form>
    </a-modal>
  </section>
</template>

<style scoped>
.filter-card { margin-bottom: var(--space-4); padding: var(--space-4); }
.table-card { padding: var(--space-4); }
.reset-button { margin-left: var(--space-2); }
.detail-body { display: flex; flex-direction: column; gap: var(--space-3); }
.detail-row { display: grid; grid-template-columns: 92px 1fr auto; gap: var(--space-3); align-items: center; }
.detail-row > span { color: var(--color-text-secondary); }
.companion-list { padding: var(--space-3); background: var(--color-page-bg); border-radius: var(--radius-card); }
.companion-list p { margin: 2px 0; }
.muted { color: var(--color-text-secondary); }
</style>
