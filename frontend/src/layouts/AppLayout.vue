<script setup lang="ts">
import { computed, h, onMounted, onUnmounted, ref } from 'vue';
import type { Component, VNode } from 'vue';
import { message } from 'ant-design-vue';
import {
  AppstoreOutlined,
  BellOutlined,
  LogoutOutlined,
  UserOutlined,
} from '@ant-design/icons-vue';
import ConfirmDialog from '@/components/ConfirmDialog.vue';
import { filterNavigation, navigation } from '@/nav/navigation';
import type { NavItem } from '@/nav/navigation';
import { iconMap } from '@/nav/icons';
import { useAuthStore } from '@/stores/auth';
import { useNotificationStore } from '@/stores/notification';
import { connectRealtime, disconnectRealtime } from '@/realtime/socket';

type MenuEntry = {
  key: string;
  label: string;
  icon: () => VNode;
  children?: MenuEntry[];
};

const authStore = useAuthStore();
const notificationStore = useNotificationStore();
const logoutDialog = ref<InstanceType<typeof ConfirmDialog> | null>(null);

const visibleNavigation = computed(() =>
  authStore.role ? filterNavigation(navigation, authStore.role) : navigation,
);

const pathByKey = computed(() => {
  const paths = new Map<string, string>();
  const visit = (items: NavItem[]): void => {
    items.forEach((item) => {
      paths.set(item.key, item.path);
      if (item.children) {
        visit(item.children);
      }
    });
  };
  visit(navigation);
  return paths;
});

const selectedKeys = computed(() => {
  const path = window.location.pathname;
  return Array.from(pathByKey.value.entries())
    .filter(([, itemPath]) => itemPath === path)
    .map(([key]) => key);
});

function resolveIcon(iconKey: string): Component {
  return iconMap[iconKey] ?? AppstoreOutlined;
}

function toMenuEntry(item: NavItem): MenuEntry {
  return {
    key: item.key,
    label: item.title,
    icon: () => h(resolveIcon(item.icon)),
    children: item.children?.map(toMenuEntry),
  };
}

const menuItems = computed<MenuEntry[]>(() =>
  visibleNavigation.value.map(toMenuEntry),
);

function handleMenuClick({ key }: { key: string }): void {
  const path = pathByKey.value.get(String(key));
  if (path && path !== window.location.pathname) {
    window.location.assign(path);
  }
}

function goToNotifications(): void {
  window.location.assign('/notifications');
}

function handleUserMenu({ key }: { key: string }): void {
  if (key === 'logout') {
    logoutDialog.value?.openDialog();
  }
}

async function handleLogout(): Promise<void> {
  try {
    await authStore.logout();
    window.location.assign('/login');
  } catch {
    message.error('系统暂时无法处理，请稍后重试');
  }
}

onMounted(() => {
  if (!authStore.user) {
    return;
  }
  void notificationStore.fetchUnreadCount();
  connectRealtime();
});

onUnmounted(() => {
  disconnectRealtime();
});
</script>

<template>
  <div class="app-layout">
    <aside class="app-sidebar no-print">
      <div class="app-brand">校园访客系统</div>
      <a-menu
        mode="inline"
        theme="dark"
        :items="menuItems"
        :selected-keys="selectedKeys"
        @click="handleMenuClick"
      />
    </aside>

    <section class="app-shell">
      <header class="app-header no-print">
        <div class="app-header-spacer" />
        <div class="app-header-actions">
          <a-tooltip title="未读消息">
            <a-badge
              :count="notificationStore.unreadCount"
              :overflow-count="99"
              class="notification-badge"
            >
              <a-button
                type="text"
                shape="circle"
                aria-label="未读消息"
                @click="goToNotifications"
              >
                <template #icon><BellOutlined /></template>
              </a-button>
            </a-badge>
          </a-tooltip>

          <a-dropdown trigger="click">
            <a-button
              type="text"
              class="app-user-menu"
              :aria-label="authStore.user?.displayName ?? '退出登录'"
            >
              <template #icon><UserOutlined /></template>
              <span v-if="authStore.user?.displayName">
                {{ authStore.user.displayName }}
              </span>
            </a-button>
            <template #overlay>
              <a-menu @click="handleUserMenu">
                <a-menu-item key="logout">
                  <LogoutOutlined />
                  退出登录
                </a-menu-item>
              </a-menu>
            </template>
          </a-dropdown>
        </div>
      </header>

      <main class="app-content">
        <slot />
      </main>
    </section>

    <ConfirmDialog
      ref="logoutDialog"
      title="确认退出登录"
      content="退出后需要重新输入账号和密码才能继续使用，是否退出？"
      danger
      @confirm="handleLogout"
    />
  </div>
</template>

<style scoped>
.app-layout {
  display: flex;
  min-height: 100vh;
  background: var(--color-page-bg);
}

.app-sidebar {
  position: fixed;
  inset: 0 auto 0 0;
  z-index: 20;
  width: var(--layout-sider-width);
  overflow-y: auto;
  background: var(--color-sider-bg);
}

.app-brand {
  display: flex;
  align-items: center;
  height: var(--layout-header-height);
  padding: 0 var(--space-6);
  overflow: hidden;
  color: #ffffff;
  font-size: var(--font-size-lg);
  font-weight: 600;
  white-space: nowrap;
}

.app-sidebar :deep(.ant-menu) {
  border-inline-end: 0;
}

.app-shell {
  width: calc(100% - var(--layout-sider-width));
  min-width: var(--layout-content-min-width);
  margin-left: var(--layout-sider-width);
}

.app-header {
  position: sticky;
  top: 0;
  z-index: 10;
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: var(--layout-header-height);
  padding: 0 var(--layout-content-padding);
  background: var(--color-header-bg);
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.06);
}

.app-header-spacer {
  flex: 1;
}

.app-header-actions {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.app-header-actions :deep(.ant-btn) {
  min-width: 32px;
  min-height: 32px;
}

.notification-badge {
  display: inline-flex;
}

.app-user-menu {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
}

.app-content {
  min-width: var(--layout-content-min-width);
  padding: var(--layout-content-padding);
  overflow-x: auto;
}
</style>
