import { ref } from 'vue';
import { defineStore } from 'pinia';
import apiClient from '@/api/client';

export type NotificationItem = {
  id: string;
  title: string;
  templateType: string;
  createdAt: string;
  readAt: string | null;
};

type NotificationPayload = {
  items?: NotificationItem[];
  list?: NotificationItem[];
  results?: NotificationItem[];
};

function extractNotifications(payload: unknown): NotificationItem[] {
  if (Array.isArray(payload)) {
    return payload as NotificationItem[];
  }
  if (payload && typeof payload === 'object') {
    const page = payload as NotificationPayload;
    return page.items ?? page.list ?? page.results ?? [];
  }
  return [];
}

export const useNotificationStore = defineStore('notification', () => {
  const unreadCount = ref(0);
  const items = ref<NotificationItem[]>([]);

  async function fetchUnreadCount(): Promise<void> {
    const response = await apiClient.get('/notifications/unread-count');
    const data = response.data.data ?? {};
    unreadCount.value = Number(data.unreadCount ?? data.count ?? 0);
  }

  async function fetchItems(unreadOnly = false): Promise<void> {
    const response = await apiClient.get('/notifications', {
      params: { unreadOnly },
    });
    items.value = extractNotifications(response.data.data);
  }

  async function markRead(id: string): Promise<void> {
    const response = await apiClient.put(`/notifications/${id}/read`);
    const readAt = response.data.data?.readAt ?? new Date().toISOString();
    const item = items.value.find((entry) => entry.id === id);
    if (item && !item.readAt) {
      item.readAt = readAt;
      unreadCount.value = Math.max(0, unreadCount.value - 1);
    }
  }

  async function markAllRead(): Promise<void> {
    await apiClient.put('/notifications/read-all');
    const readAt = new Date().toISOString();
    items.value.forEach((item) => {
      item.readAt = item.readAt ?? readAt;
    });
    unreadCount.value = 0;
  }

  function receiveNotification(notification: NotificationItem): void {
    if (!notification?.id) {
      return;
    }
    const existing = items.value.find((item) => item.id === notification.id);
    if (!existing) {
      items.value.unshift({ ...notification, readAt: notification.readAt ?? null });
      unreadCount.value += 1;
      return;
    }
    if (!existing.readAt) {
      return;
    }
    existing.readAt = null;
    unreadCount.value += 1;
  }

  return {
    unreadCount,
    items,
    fetchUnreadCount,
    fetchItems,
    markRead,
    markAllRead,
    receiveNotification,
  };
});
