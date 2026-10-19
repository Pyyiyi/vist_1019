<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { message } from 'ant-design-vue';
import dayjs, { type Dayjs } from 'dayjs';
import { useRouter } from 'vue-router';

import apiClient from '@/api/client';
import ConfirmDialog from '@/components/ConfirmDialog.vue';
import EmptyState from '@/components/EmptyState.vue';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import StatusTag from '@/components/StatusTag.vue';
import { canReschedule, formatMinute, formatRange, isTerminal, serverMessage } from './helpers';
import type { AppointmentItem } from './types';

const router = useRouter();
const loading = ref(true);
const failed = ref(false);
const items = ref<AppointmentItem[]>([]);
const selectedId = ref<string | null>(null);
const detail = ref<AppointmentItem | null>(null);
const detailLoading = ref(false);
const detailFailed = ref(false);
const messagesExpanded = ref(false);
const rescheduleOpen = ref(false);
const rescheduleSaving = ref(false);
const rescheduleStart = ref<Dayjs | null>(null);
const rescheduleEnd = ref<Dayjs | null>(null);
const cancelConfirm = ref<{ openDialog: () => void } | null>(null);
const cancelOpen = ref(false);
const cancelSaving = ref(false);
const cancelReason = ref('');
const confirming = ref(false);

const visibleMessages = computed(() => {
  const list = detail.value?.messages ?? [];
  return messagesExpanded.value ? list : list.slice(0, 5);
});
const hasMoreMessages = computed(() => (detail.value?.messages?.length ?? 0) > 5);
const deadlineText = computed(() => {
  if (!detail.value?.rescheduleProposedAt) return '';
  return dayjs(detail.value.rescheduleProposedAt).add(3, 'hour').format('YYYY-MM-DD HH:mm');
});

async function load(): Promise<void> {
  loading.value = true; failed.value = false;
  try {
    const response = await apiClient.get('/visitor/appointments');
    items.value = (response.data.data.items ?? []) as AppointmentItem[];
    if (items.value.length > 0) await openDetail(items.value[0].id);
  } catch { failed.value = true; items.value = []; } finally { loading.value = false; }
}

async function openDetail(id: string): Promise<void> {
  selectedId.value = id; detailLoading.value = true; detailFailed.value = false; messagesExpanded.value = false;
  try {
    const response = await apiClient.get(`/visitor/appointments/${id}`);
    detail.value = response.data.data as AppointmentItem;
  } catch { detailFailed.value = true; detail.value = null; } finally { detailLoading.value = false; }
}

function openReschedule(): void {
  if (!detail.value) return;
  rescheduleStart.value = dayjs(detail.value.visitStart);
  rescheduleEnd.value = dayjs(detail.value.visitEnd);
  rescheduleOpen.value = true;
}

async function submitReschedule(): Promise<void> {
  if (!detail.value || !rescheduleStart.value || !rescheduleEnd.value) return;
  rescheduleSaving.value = true;
  try {
    await apiClient.put(`/visitor/appointments/${detail.value.id}/reschedule`, { visitStart: rescheduleStart.value.toISOString(), visitEnd: rescheduleEnd.value.toISOString() });
    message.success('改期成功'); rescheduleOpen.value = false; await Promise.all([load(), openDetail(detail.value.id)]);
  } catch (error) { message.error(serverMessage(error)); } finally { rescheduleSaving.value = false; }
}

async function confirmReschedule(): Promise<void> {
  if (!detail.value || confirming.value) return;
  confirming.value = true;
  try {
    await apiClient.post(`/visitor/appointments/${detail.value.id}/confirm-reschedule`);
    message.success('已确认改期，等待被访人重新审核'); await Promise.all([load(), openDetail(detail.value.id)]);
  } catch (error) { message.error(serverMessage(error)); } finally { confirming.value = false; }
}

function requestCancel(): void { cancelReason.value = ''; cancelConfirm.value?.openDialog(); }
function openCancelReason(): void { cancelOpen.value = true; }

async function submitCancel(): Promise<void> {
  if (!detail.value) return;
  cancelSaving.value = true;
  try {
    await apiClient.put(`/visitor/appointments/${detail.value.id}/cancel`, { reason: cancelReason.value.trim() || undefined });
    message.success('预约已取消'); cancelOpen.value = false; await Promise.all([load(), openDetail(detail.value.id)]);
  } catch (error) { message.error(serverMessage(error)); } finally { cancelSaving.value = false; }
}

onMounted(load);
</script>

<template>
  <section class="h5-my-page">
    <header class="h5-title-card"><p class="eyebrow">校园访客</p><h1>我的申请</h1></header>

    <LoadingState v-if="loading" />
    <ErrorState v-else-if="failed" @retry="load" />
    <EmptyState v-else-if="items.length === 0" description="您还没有提交过申请" action-text="重新扫码申请" @action="router.push('/h5/apply')" />
    <template v-else>
      <section class="page-card h5-card">
        <button v-for="item in items" :key="item.id" class="application-row" :class="{ active: item.id === selectedId }" @click="openDetail(item.id)">
          <span><strong>{{ item.visitorName }}</strong><small>{{ formatRange(item.visitStart, item.visitEnd) }}</small></span>
          <StatusTag :status="item.status" />
          <span class="view-link">查看详情</span>
        </button>
      </section>

      <LoadingState v-if="detailLoading" />
      <ErrorState v-else-if="detailFailed" @retry="selectedId && openDetail(selectedId)" />
      <template v-else-if="detail">
        <section class="page-card h5-card status-card">
          <div class="status-head"><h2>{{ detail.appointNo }}</h2><StatusTag :status="detail.status" /></div>
          <p>{{ detail.visitorTypeName }} · {{ detail.hostName }}</p>
          <p>{{ formatRange(detail.visitStart, detail.visitEnd) }} · {{ detail.reason }}</p>
        </section>

        <section v-if="detail.credential" class="page-card h5-card credential-card">
          <h2>进校凭证</h2>
          <div class="qr-wrap"><a-qrcode :value="detail.appointNo" :size="176" :bordered="false" /></div>
          <p class="short-code">{{ detail.credential.shortCode }}</p>
          <p>到校后请向门卫出示二维码或 6 位短码</p>
          <p class="muted">短码仅用于现场核对，不能用于查询他人信息</p>
        </section>

        <section v-if="detail.status === '已改期'" class="page-card h5-card reschedule-confirm">
          <p>被访人提议将到访时段调整为 {{ formatRange(detail.visitStart, detail.visitEnd) }}，请在 {{ deadlineText }} 前确认</p>
          <a-button type="primary" block :loading="confirming" @click="confirmReschedule">确认改期</a-button>
        </section>

        <section v-if="canReschedule(detail.status)" class="page-card h5-card actions-card">
          <a-button block @click="openReschedule">改期</a-button>
          <a-button block danger @click="requestCancel">取消预约</a-button>
        </section>

        <a-alert v-if="isTerminal(detail.status)" type="info" show-icon message="该申请已结束，如需来访请重新扫码申请" />

        <section v-if="detail.messages?.length" class="page-card h5-card messages-card">
          <h2>消息</h2>
          <article v-for="item in visibleMessages" :key="item.id" class="message-item">
            <strong>{{ item.title }}</strong><p>{{ item.content }}</p><small>{{ formatMinute(item.createdAt) }}</small>
          </article>
          <a-button v-if="hasMoreMessages" type="link" @click="messagesExpanded = !messagesExpanded">{{ messagesExpanded ? '收起' : '展开全部' }}</a-button>
        </section>
      </template>

      <footer class="privacy-entry"><button @click="router.push('/h5/privacy')">个人信息说明</button></footer>
    </template>

    <a-modal v-model:open="rescheduleOpen" title="修改到访时段" :confirm-loading="rescheduleSaving" ok-text="确定" cancel-text="取消" :mask-closable="false" @ok="submitReschedule">
      <a-form layout="vertical">
        <a-form-item label="开始时间"><a-date-picker v-model:value="rescheduleStart" show-time format="YYYY-MM-DD HH:mm" style="width: 100%" /></a-form-item>
        <a-form-item label="结束时间"><a-date-picker v-model:value="rescheduleEnd" show-time format="YYYY-MM-DD HH:mm" style="width: 100%" /></a-form-item>
      </a-form>
    </a-modal>

    <ConfirmDialog ref="cancelConfirm" title="确认取消预约" content="取消后该预约不能恢复，访客将收到取消通知。是否继续？" ok-text="确认取消预约" :danger="true" @confirm="openCancelReason" />
    <a-modal v-model:open="cancelOpen" title="确认取消预约" :confirm-loading="cancelSaving" ok-text="确认取消预约" cancel-text="取消" :mask-closable="false" @ok="submitCancel">
      <a-form layout="vertical"><a-form-item label="取消原因（选填）"><a-textarea v-model:value="cancelReason" placeholder="请说明取消原因" :rows="3" /></a-form-item></a-form>
    </a-modal>
  </section>
</template>

<style scoped>
.h5-my-page { width: 100%; max-width: 100%; overflow-x: hidden; }
.h5-title-card { margin: -4px -4px 12px; padding: 20px 16px; color: #fff; background: linear-gradient(135deg, #1677ff, #4096ff); border-radius: 0 0 16px 16px; }
.h5-title-card h1 { margin: 4px 0 0; color: #fff; font-size: 24px; }
.eyebrow { margin: 0; opacity: .82; }
.h5-card { margin-bottom: 12px; padding: 16px; }
.application-row { display: grid; grid-template-columns: 1fr auto; gap: 6px 10px; width: 100%; min-height: 64px; padding: 12px 4px; border: 0; border-bottom: 1px solid var(--color-border); text-align: left; background: transparent; cursor: pointer; }
.application-row:last-child { border-bottom: 0; }
.application-row.active { background: #f0f7ff; }
.application-row small { display: block; margin-top: 4px; color: var(--color-text-secondary); }
.view-link { grid-column: 2; color: var(--color-primary); font-size: 13px; }
.status-head { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.status-head h2 { margin: 0; font-size: 16px; word-break: break-all; }
.status-card p { margin: 8px 0 0; color: var(--color-text-secondary); }
.credential-card { text-align: center; }
.credential-card h2 { margin-bottom: 12px; }
.qr-wrap { display: flex; justify-content: center; padding: 8px; }
.short-code { margin: 8px 0; font-size: 30px; font-weight: 700; letter-spacing: 6px; color: var(--color-text-primary); }
.muted, .credential-card p:last-child { color: var(--color-text-secondary); font-size: 13px; }
.reschedule-confirm p { line-height: 1.7; }
.actions-card { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.actions-card :deep(.ant-btn) { min-height: 44px; }
.messages-card h2 { margin-bottom: 12px; }
.message-item { padding: 10px 0; border-bottom: 1px solid var(--color-border); }
.message-item p { margin: 4px 0; color: var(--color-text-secondary); }
.message-item small { color: #8f959e; }
.reschedule-confirm :deep(.ant-btn) { min-height: 44px; }
.privacy-entry { padding: 20px 0 8px; text-align: center; }
.privacy-entry button { min-height: 44px; padding: 0 12px; border: 0; color: var(--color-text-secondary); background: transparent; }
@media (max-width: 360px) { .actions-card { grid-template-columns: 1fr; } }
</style>
