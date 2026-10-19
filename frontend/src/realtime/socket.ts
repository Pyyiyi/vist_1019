import { io, type Socket } from 'socket.io-client';
import { useNotificationStore } from '@/stores/notification';
import type { NotificationItem } from '@/stores/notification';

let socket: Socket | null = null;

function handleNewNotification(payload: NotificationItem): void {
  useNotificationStore().receiveNotification(payload);
}

export function connectRealtime(): void {
  if (typeof window === 'undefined') {
    return;
  }

  if (!socket) {
    const endpoint = import.meta.env.VITE_WS_BASE ?? window.location.origin;
    socket = io(endpoint, {
      path: '/ws',
      withCredentials: true,
      reconnection: true,
      transports: ['websocket', 'polling'],
    });
    socket.on('notification:new', handleNewNotification);
    return;
  }

  if (!socket.connected) {
    socket.connect();
  }
}

export function disconnectRealtime(): void {
  if (!socket) {
    return;
  }
  socket.off('notification:new', handleNewNotification);
  socket.disconnect();
  socket = null;
}
