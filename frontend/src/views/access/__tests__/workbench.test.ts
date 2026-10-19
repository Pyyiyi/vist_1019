import { flushPromises, mount } from '@vue/test-utils';
import Antd from 'ant-design-vue';
import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { push, get } = vi.hoisted(() => ({ push: vi.fn(), get: vi.fn() }));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push }),
}));

vi.mock('@/api/client', () => ({
  default: { get },
}));

import type { AuthUser } from '@/stores/auth';
import { useAuthStore } from '@/stores/auth';
import WorkbenchPage from '../WorkbenchPage.vue';

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

const summary = {
  role: 'admin',
  todo: { pendingReview: 2, pendingVerify: 1, pendingIncident: 1 },
  kpi: { todayAppointments: 3, onCampus: 1 },
  unreadCount: 0,
  todos: [],
};

function mountPage(user: AuthUser) {
  const pinia = createPinia();
  setActivePinia(pinia);
  useAuthStore().setUser(user);
  return mount(WorkbenchPage, {
    global: { plugins: [pinia, Antd] },
  });
}

beforeEach(() => {
  push.mockReset();
  get.mockReset().mockImplementation(async (url: string) => {
    if (url === '/workbench/summary') {
      return { data: { data: { ...summary, role: 'admin' } } };
    }
    return {
      data: {
        data: {
          entryUrl: 'http://localhost/h5/apply',
          qrDataUrl: 'data:image/png;base64,AAAA',
        },
      },
    };
  });
});

describe('workbench KPI navigation', () => {
  it('renders all admin KPIs and pushes each documented route', async () => {
    const wrapper = mountPage(admin);
    await flushPromises();

    const cards = await wrapper.findAll('.kpi-card');
    expect(cards.map((card) => card.find('.kpi-title').text())).toEqual([
      '待审核',
      '待核验',
      '异常待处理',
      '今日预约',
      '在校访客',
    ]);

    for (const card of cards) await card.trigger('click');
    expect(push.mock.calls.map(([path]) => path)).toEqual([
      '/reviews',
      '/gate',
      '/gate',
      '/appointments',
      '/on-campus',
    ]);
  });

  it('omits admin/host-only KPIs and the QR card for guard', async () => {
    const wrapper = mountPage(guard);
    await flushPromises();

    expect(wrapper.findAll('.kpi-title').map((item) => item.text())).toEqual([
      '待核验',
      '异常待处理',
      '在校访客',
    ]);
    expect(wrapper.find('.entry-qr-card').exists()).toBe(false);
  });
});
