import { createPinia, setActivePinia } from 'pinia';
import {
  createMemoryHistory,
  createRouter,
  type RouteRecordRaw,
  type Router,
} from 'vue-router';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import type { AuthUser } from '@/stores/auth';
import { useAuthStore } from '@/stores/auth';
import { createAuthGuard } from '@/router';
import { sharedRoutes } from '@/router/shared.routes';
import RouterContainer from '@/components/RouterContainer.vue';

const StubPage = { template: '<div />' };

const adminUser: AuthUser = {
  id: 'admin-id',
  username: 'admin',
  displayName: '系统管理员',
  roleCode: 'admin',
  hostId: null,
};

const guardUser: AuthUser = {
  id: 'guard-id',
  username: 'guard01',
  displayName: '门卫张师傅',
  roleCode: 'guard',
  hostId: null,
};

const hostUser: AuthUser = {
  id: 'host-id',
  username: 'T001',
  displayName: '李明',
  roleCode: 'host',
  hostId: 'host-1',
};

const stubRoutes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'login',
    component: StubPage,
    meta: { layout: 'blank' },
  },
  {
    path: '/workbench',
    name: 'workbench',
    component: StubPage,
    meta: { layout: 'app', roles: ['admin', 'guard', 'host'] },
  },
  {
    path: '/system/settings',
    name: 'system-settings',
    component: StubPage,
    meta: { layout: 'app', roles: ['admin'] },
  },
  {
    path: '/h5/apply',
    name: 'h5-apply',
    component: StubPage,
    meta: { layout: 'h5' },
  },
  {
    path: '/403',
    name: 'forbidden',
    component: StubPage,
    meta: { layout: 'blank' },
  },
];

function createStubRouter(): Router {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [...sharedRoutes, ...stubRoutes],
  });
  router.beforeEach(createAuthGuard());
  return router;
}

function mockFetchMe(user: AuthUser | null) {
  const authStore = useAuthStore();
  return vi.spyOn(authStore, 'fetchMe').mockImplementation(async () => {
    if (user) {
      authStore.setUser(user);
    } else {
      authStore.clearSession();
    }
  });
}

beforeEach(() => {
  setActivePinia(createPinia());
});

describe('router auth guard', () => {
  it('defines only the root and H5 shared route records', () => {
    expect(sharedRoutes).toHaveLength(2);
    expect(sharedRoutes[0]).toMatchObject({
      path: '/',
      name: 'root',
      component: RouterContainer,
      redirect: '/login',
    });
    expect(sharedRoutes[0].children?.[0]?.path).toBe(':pathMatch(.*)*');
    expect(sharedRoutes[1]).toMatchObject({
      path: '/h5',
      redirect: '/h5/apply',
    });
    expect(sharedRoutes[1].children?.[0]?.path).toBe(':pathMatch(.*)*');
  });

  it('redirects an unauthenticated app route to login with redirect query', async () => {
    const fetchMe = mockFetchMe(null);
    const router = createStubRouter();

    await router.push('/workbench');

    expect(router.currentRoute.value.path).toBe('/login');
    expect(router.currentRoute.value.query.redirect).toBe('/workbench');
    expect(fetchMe).toHaveBeenCalledTimes(1);
  });

  it('redirects an authenticated user away from login', async () => {
    mockFetchMe(adminUser);
    const router = createStubRouter();

    await router.push('/login');

    expect(router.currentRoute.value.path).toBe('/workbench');
  });

  it('redirects a user without a required role to forbidden', async () => {
    mockFetchMe(guardUser);
    const router = createStubRouter();

    await router.push('/system/settings');

    expect(router.currentRoute.value.path).toBe('/403');
  });

  it('allows public H5 routes without a session', async () => {
    const fetchMe = mockFetchMe(null);
    const router = createStubRouter();

    await router.push('/h5/apply');
    expect(router.currentRoute.value.path).toBe('/h5/apply');

    await router.push('/workbench');
    expect(router.currentRoute.value.path).toBe('/login');
    expect(fetchMe).toHaveBeenCalledTimes(1);
  });

  it('keeps a refreshed authenticated session on the requested app route', async () => {
    mockFetchMe(hostUser);
    const router = createStubRouter();

    await router.push('/workbench');

    expect(router.currentRoute.value.path).toBe('/workbench');
  });

  it('sends the root catch-all to workbench when refresh restores a session', async () => {
    mockFetchMe(adminUser);
    const router = createStubRouter();

    await router.push('/missing-page');

    expect(router.currentRoute.value.path).toBe('/workbench');
  });

  it('sends the H5 catch-all to the H5 application route', async () => {
    mockFetchMe(null);
    const router = createStubRouter();

    await router.push('/h5/missing-page');

    expect(router.currentRoute.value.path).toBe('/h5/apply');
  });
});
