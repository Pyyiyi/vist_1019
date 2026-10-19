import { flushPromises, mount } from '@vue/test-utils';
import Antd from 'ant-design-vue';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { get, put, push } = vi.hoisted(() => ({
  get: vi.fn(),
  put: vi.fn(),
  push: vi.fn(),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push }),
}));

vi.mock('@/api/client', () => ({
  default: { get, put },
}));

import type { AuthUser } from '@/stores/auth';
import { useAuthStore } from '@/stores/auth';
import NotificationsPage from '../NotificationsPage.vue';

if (!window.matchMedia) {
  Object.defineProperty(window, 'matchMedia', {
    writable: true,
    value: (query: string) => ({
      matches: false,
      media: query,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    }),
  });
}

if (!globalThis.ResizeObserver) {
  class ResizeObserverMock {
    observe(): void {}
    unobserve(): void {}
    disconnect(): void {}
  }
  globalThis.ResizeObserver = ResizeObserverMock as unknown as typeof ResizeObserver;
}

const admin: AuthUser = {
  id: 'admin-id',
  username: 'admin',
  displayName: '系统管理员',
  roleCode: 'admin',
  hostId: null,
};

const guard: AuthUser = {
  id: 'guard-id',
  username: 'guard01',
  displayName: '门卫张师傅',
  roleCode: 'guard',
  hostId: null,
};

const unreadNotification = {
  id: 'notification-1',
  title: '黑名单人员提交预约',
  content: '访客韩梅提交预约',
  templateType: '黑名单命中',
  businessType: 'appointment',
  businessId: 'appointment-1',
  isSecurity: false,
  readAt: null,
  createdAt: '2026-10-19T12:00:00.000Z',
};

const channels = [
  { channelCode: '站内', enabled: true, updatedAt: '2026-10-19T12:00:00.000Z' },
  { channelCode: '短信', enabled: false, updatedAt: '2026-10-19T12:00:00.000Z' },
  { channelCode: '企微', enabled: false, updatedAt: '2026-10-19T12:00:00.000Z' },
];

function listResponse(items = [unreadNotification]) {
  return {
    data: {
      data: {
        items,
        total: items.length,
        page: 1,
        page_size: 20,
      },
    },
  };
}

function mountPage(user: AuthUser) {
  const pinia = createPinia();
  setActivePinia(pinia);
  useAuthStore().setUser(user);
  return mount(NotificationsPage, {
    global: { plugins: [pinia, Antd] },
  });
}

beforeEach(() => {
  get.mockReset();
  put.mockReset();
  push.mockReset();
  get.mockImplementation(async (url: string) => {
    if (url === '/notifications') {
      return listResponse();
    }
    if (url === '/notifications/unread-count') {
      return { data: { data: { unreadCount: 1 } } };
    }
    if (url === '/system/notification-channels') {
      return { data: { data: channels } };
    }
    throw new Error(`unexpected GET ${url}`);
  });
  put.mockImplementation(async (url: string) => {
    if (url === '/notifications/read-all') {
      return { data: { data: { updated: 1 } } };
    }
    if (url.endsWith('/read')) {
      return { data: { data: { id: 'notification-1', readAt: '2026-10-19T12:05:00.000Z' } } };
    }
    if (url === '/system/notification-channels') {
      return { data: { data: channels } };
    }
    throw new Error(`unexpected PUT ${url}`);
  });
});

describe('通知中心页面', () => {
  it('renders the data state, COPY-274 title, list, and admin channel section', async () => {
    const wrapper = mountPage(admin);
    await flushPromises();

    expect(wrapper.find('h1').text()).toBe('通知中心');
    expect(wrapper.text()).toContain('黑名单人员提交预约');
    expect(wrapper.text()).toContain('全部标为已读');
    expect(wrapper.text()).toContain('通知渠道');
    expect(wrapper.text()).toContain('预留 · 关闭');
    expect(wrapper.text()).toContain('站内消息为安全类通知的固定通道，不能关闭');
    expect(wrapper.text()).toContain('安全类通知始终发送站内消息，不受渠道开关影响');
  });

  it('renders the empty state with COPY-279', async () => {
    get.mockImplementation(async (url: string) => {
      if (url === '/notifications') return listResponse([]);
      if (url === '/notifications/unread-count') return { data: { data: { unreadCount: 0 } } };
      if (url === '/system/notification-channels') return { data: { data: channels } };
      throw new Error(`unexpected GET ${url}`);
    });

    const wrapper = mountPage(admin);
    await flushPromises();

    expect(wrapper.text()).toContain('暂无消息');
  });

  it('renders the error state and retries into the list', async () => {
    get.mockImplementation(async (url: string) => {
      if (url === '/notifications') throw new Error('offline');
      if (url === '/notifications/unread-count') return { data: { data: { unreadCount: 0 } } };
      if (url === '/system/notification-channels') return { data: { data: channels } };
      throw new Error(`unexpected GET ${url}`);
    });

    const wrapper = mountPage(admin);
    await flushPromises();
    expect(wrapper.text()).toContain('数据加载失败，请点击重试');
    expect(wrapper.text()).toContain('重试');

    get.mockImplementation(async (url: string) => {
      if (url === '/notifications') return listResponse();
      if (url === '/notifications/unread-count') return { data: { data: { unreadCount: 1 } } };
      if (url === '/system/notification-channels') return { data: { data: channels } };
      throw new Error(`unexpected GET ${url}`);
    });

    await wrapper.find('.error-state button').trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('黑名单人员提交预约');
  });

  it('does not render channel configuration for guard', async () => {
    const wrapper = mountPage(guard);
    await flushPromises();

    expect(wrapper.text()).not.toContain('通知渠道');
    expect(get.mock.calls.some(([url]) => url === '/system/notification-channels')).toBe(false);
  });

  it('navigates guard appointment notifications to /gate and marks them read first', async () => {
    const wrapper = mountPage(guard);
    await flushPromises();

    const row = wrapper.find('tr.notification-row');
    expect(row.exists()).toBe(true);
    await row.trigger('click');
    await flushPromises();

    expect(put).toHaveBeenCalledWith('/notifications/notification-1/read');
    expect(push).toHaveBeenCalledWith('/gate');
  });

  it('navigates admin appointment notifications to the appointment detail query', async () => {
    const wrapper = mountPage(admin);
    await flushPromises();

    const row = wrapper.find('tr.notification-row');
    expect(row.exists()).toBe(true);
    await row.trigger('click');
    await flushPromises();

    expect(push).toHaveBeenCalledWith('/appointments?appointmentId=appointment-1');
  });

  it('toggles unread-only and resets to page one', async () => {
    const wrapper = mountPage(admin);
    await flushPromises();
    get.mockClear();

    await wrapper.find('input[type="checkbox"]').setValue(true);
    await flushPromises();

    const listCall = get.mock.calls.find(([url]) => url === '/notifications');
    expect(listCall?.[1]).toMatchObject({ params: { page: 1, unreadOnly: true } });
  });

  it('calls read-all from the header action', async () => {
    const wrapper = mountPage(admin);
    await flushPromises();

    const button = wrapper.findAll('button').find((item) => item.text() === '全部标为已读')!;
    await button.trigger('click');
    await flushPromises();

    expect(put).toHaveBeenCalledWith('/notifications/read-all');
  });
});
