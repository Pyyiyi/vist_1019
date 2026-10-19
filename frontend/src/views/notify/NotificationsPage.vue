<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import dayjs from 'dayjs';
import { message } from 'ant-design-vue';

import apiClient from '@/api/client';
import EmptyState from '@/components/EmptyState.vue';
import ErrorState from '@/components/ErrorState.vue';
import LoadingState from '@/components/LoadingState.vue';
import PageHeader from '@/components/PageHeader.vue';
import { useAuthStore } from '@/stores/auth';
import { useNotificationStore } from '@/stores/notification';

type NotificationRow = {
  id: string;
  title: string;
  content: string;
  templateType: string;
  businessType: string;
  businessId: string | null;
  isSecurity: boolean;
  readAt: string | null;
  createdAt: string;
};

type ChannelRow = {
  channelCode: '站内' | '短信' | '企微';
  enabled: boolean;
  updatedAt?: string;
  updatedBy?: string | null;
};

const router = useRouter();
const authStore = useAuthStore();
const notificationStore = useNotificationStore();

const loading = ref(true);
const failed = ref(false);
const items = ref<NotificationRow[]>([]);
const page = ref(1);
const pageSize = ref(20);
const total = ref(0);
const unreadOnly = ref(false);
const markingAll = ref(false);
const markingIds = ref(new Set<string>());

const channels = ref<ChannelRow[]>([
  { channelCode: '站内', enabled: true },
  { channelCode: '短信', enabled: false },
  { channelCode: '企微', enabled: false },
]);
const smsEnabled = ref(false);
const wecomEnabled = ref(false);
const channelsLoading = ref(false);
const channelSaving = ref(false);

const isAdmin = computed(() => authStore.role === 'admin');

const columns = [
  { title: '标题', dataIndex: 'title', key: 'title', ellipsis: true },
  { title: '类型', dataIndex: 'templateType', key: 'templateType', width: 150 },
  { title: '时间', dataIndex: 'createdAt', key: 'createdAt', width: 180 },
  { title: '状态', key: 'status', width: 100 },
  { title: '操作', key: 'actions', width: 140, fixed: 'right' as const },
];

const pagination = computed(() => ({
  current: page.value,
  pageSize: pageSize.value,
  total: total.value,
  showSizeChanger: false,
  showTotal: (value: number) => `共 ${value} 条`,
}));

const channelLabels: Record<ChannelRow['channelCode'], string> = {
  站内: '站内消息',
  短信: '短信',
  企微: '企业微信',
};

function serverMessage(error: unknown): string {
  const response = (error as { response?: { data?: { message?: string } } }).response;
  return response?.data?.message ?? '系统暂时无法处理，请稍后重试';
}

function formatTime(value: string): string {
  return value ? dayjs(value).format('YYYY-MM-DD HH:mm') : '—';
}

function onPageChange(next: { current?: number }): void {
  page.value = next.current ?? 1;
  void loadNotifications();
}

async function loadNotifications(): Promise<void> {
  loading.value = true;
  failed.value = false;
  try {
    const response = await apiClient.get('/notifications', {
      params: {
        page: page.value,
        pageSize: pageSize.value,
        unreadOnly: unreadOnly.value,
      },
    });
    const data = response.data.data ?? {};
    items.value = (data.items ?? []) as NotificationRow[];
    total.value = Number(data.total ?? 0);
  } catch {
    failed.value = true;
  } finally {
    loading.value = false;
  }
}

async function refreshUnread(): Promise<void> {
  try {
    await notificationStore.fetchUnreadCount();
  } catch {
    // The list itself remains usable when the counter refresh fails.
  }
}

async function loadChannels(): Promise<void> {
  if (!isAdmin.value) {
    return;
  }
  channelsLoading.value = true;
  try {
    const response = await apiClient.get('/system/notification-channels');
    const rows = (response.data.data ?? []) as ChannelRow[];
    if (rows.length > 0) {
      channels.value = rows;
    }
    smsEnabled.value = rows.find((row) => row.channelCode === '短信')?.enabled ?? false;
    wecomEnabled.value = rows.find((row) => row.channelCode === '企微')?.enabled ?? false;
  } catch (error) {
    message.error(serverMessage(error));
  } finally {
    channelsLoading.value = false;
  }
}

function handleUnreadChange(): void {
  page.value = 1;
  void loadNotifications();
}

function notificationTarget(record: NotificationRow): string | null {
  if (!record.businessId) {
    return null;
  }
  if (record.isSecurity) {
    return '/gate';
  }
  if (record.businessType === 'appointment') {
    if (authStore.role === 'admin' || authStore.role === 'host') {
      return `/appointments?appointmentId=${encodeURIComponent(record.businessId)}`;
    }
    if (authStore.role === 'guard') {
      return '/gate';
    }
  }
  return null;
}

async function markRowRead(record: NotificationRow, silent = false): Promise<boolean> {
  if (record.readAt || markingIds.value.has(record.id)) {
    return Boolean(record.readAt);
  }
  markingIds.value.add(record.id);
  markingIds.value = new Set(markingIds.value);
  try {
    const response = await apiClient.put(`/notifications/${record.id}/read`);
    record.readAt = response.data.data?.readAt ?? new Date().toISOString();
    await refreshUnread();
    if (!silent) {
      message.success('已标记为已读');
    }
    return true;
  } catch (error) {
    message.error(serverMessage(error));
    return false;
  } finally {
    markingIds.value.delete(record.id);
    markingIds.value = new Set(markingIds.value);
  }
}

async function handleMarkRead(record: NotificationRow): Promise<void> {
  const ok = await markRowRead(record);
  if (ok && unreadOnly.value) {
    await loadNotifications();
  }
}

async function handleOpen(record: NotificationRow): Promise<void> {
  if (!record.readAt) {
    const ok = await markRowRead(record, true);
    if (!ok) {
      return;
    }
  }
  const target = notificationTarget(record);
  if (target) {
    await router.push(target);
  }
}

function rowProps(record: NotificationRow): Record<string, unknown> {
  return {
    class: 'notification-row',
    onClick: () => {
      void handleOpen(record);
    },
  };
}

async function handleMarkAllRead(): Promise<void> {
  if (markingAll.value) {
    return;
  }
  markingAll.value = true;
  try {
    await apiClient.put('/notifications/read-all');
    message.success('已全部标为已读');
    await Promise.all([loadNotifications(), refreshUnread()]);
  } catch (error) {
    message.error(serverMessage(error));
  } finally {
    markingAll.value = false;
  }
}

function onSmsChange(value: boolean): void {
  smsEnabled.value = value;
}

function onWecomChange(value: boolean): void {
  wecomEnabled.value = value;
}

async function saveChannels(): Promise<void> {
  if (channelSaving.value) {
    return;
  }
  channelSaving.value = true;
  try {
    await apiClient.put('/system/notification-channels', {
      sms: smsEnabled.value,
      wecom: wecomEnabled.value,
    });
    message.success('通知渠道已保存');
    await loadChannels();
  } catch (error) {
    message.error(serverMessage(error));
  } finally {
    channelSaving.value = false;
  }
}

onMounted(() => {
  void loadNotifications();
  void refreshUnread();
  if (isAdmin.value) {
    void loadChannels();
  }
});
</script>

<template>
  <div class="notifications-page">
    <PageHeader title="通知中心">
      <template #actions>
        <a-button
          type="primary"
          :loading="markingAll"
          :disabled="markingAll"
          @click="handleMarkAllRead"
        >
          全部标为已读
        </a-button>
      </template>
    </PageHeader>

    <div class="notification-toolbar">
      <a-checkbox v-model:checked="unreadOnly" @change="handleUnreadChange">
        只看未读
      </a-checkbox>
    </div>

    <LoadingState v-if="loading && items.length === 0" :rows="6" />
    <ErrorState v-else-if="failed" @retry="loadNotifications" />
    <EmptyState v-else-if="items.length === 0" description="暂无消息" />
    <section v-else class="table-card page-card">
      <a-table
        row-key="id"
        :columns="columns"
        :data-source="items"
        :pagination="pagination"
        :loading="loading"
        :custom-row="rowProps"
        :scroll="{ x: 900 }"
        @change="onPageChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'title'">
            <a-tooltip :title="record.title">
              <span class="notification-title">{{ record.title }}</span>
            </a-tooltip>
          </template>
          <template v-else-if="column.key === 'createdAt'">
            {{ formatTime(record.createdAt) }}
          </template>
          <template v-else-if="column.key === 'status'">
            <a-tag :color="record.readAt ? 'default' : 'blue'">
              {{ record.readAt ? '已读' : '未读' }}
            </a-tag>
          </template>
          <template v-else-if="column.key === 'actions'">
            <a-button
              v-if="!record.readAt"
              type="link"
              size="small"
              :loading="markingIds.has(record.id)"
              :disabled="markingIds.has(record.id)"
              @click.stop="handleMarkRead(record)"
            >
              标记已读
            </a-button>
            <span v-else class="read-text">已读</span>
          </template>
        </template>
      </a-table>
    </section>

    <a-card v-if="isAdmin" class="channel-card" :loading="channelsLoading">
      <template #title>通知渠道</template>
      <div
        v-for="channel in channels"
        :key="channel.channelCode"
        class="channel-row"
        :class="{ 'channel-row-fixed': channel.channelCode === '站内' }"
      >
        <span class="channel-name">{{ channelLabels[channel.channelCode] }}</span>
        <a-switch
          v-if="channel.channelCode === '站内'"
          :checked="true"
          disabled
          :aria-label="channelLabels[channel.channelCode]"
        />
        <a-switch
          v-else-if="channel.channelCode === '短信'"
          :checked="smsEnabled"
          :aria-label="channelLabels[channel.channelCode]"
          @change="onSmsChange"
        />
        <a-switch
          v-else
          :checked="wecomEnabled"
          :aria-label="channelLabels[channel.channelCode]"
          @change="onWecomChange"
        />
        <a-tag v-if="channel.channelCode === '站内'" color="green">已启用</a-tag>
        <a-tag v-else>预留 · 关闭</a-tag>
      </div>
      <p class="channel-note">站内消息为安全类通知的固定通道，不能关闭</p>
      <p class="channel-note">安全类通知始终发送站内消息，不受渠道开关影响</p>
      <div class="channel-actions">
        <a-button type="primary" :loading="channelSaving" :disabled="channelSaving" @click="saveChannels">
          保存
        </a-button>
      </div>
    </a-card>
  </div>
</template>

<style scoped>
.notifications-page {
  min-width: 0;
}

.notification-toolbar {
  display: flex;
  align-items: center;
  margin-bottom: var(--space-4);
}

.table-card {
  padding: var(--space-4);
  overflow: hidden;
}

.notification-title {
  display: block;
  max-width: 360px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.read-text {
  color: var(--color-text-secondary);
}

:deep(.notification-row) {
  cursor: pointer;
}

.channel-card {
  margin-top: var(--space-6);
}

.channel-row {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  min-height: 44px;
  border-bottom: 1px solid var(--color-border-secondary, #f0f0f0);
}

.channel-row:last-of-type {
  border-bottom: 0;
}

.channel-name {
  width: 120px;
  color: var(--color-text-primary);
  font-weight: 550;
}

.channel-note {
  margin-top: var(--space-3);
  color: var(--color-text-secondary);
  font-size: var(--font-size-sm);
}

.channel-actions {
  display: flex;
  justify-content: flex-end;
  margin-top: var(--space-4);
}
</style>
