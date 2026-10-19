import {
  createRouter,
  createWebHistory,
  type RouteLocationNormalized,
  type RouteLocationRaw,
  type RouteRecordRaw,
} from 'vue-router';

import { useAuthStore } from '@/stores/auth';
import { sharedRoutes } from './shared.routes';

type RoutesModule = {
  default: RouteRecordRaw[];
};

export function createAuthGuard() {
  let initialized = false;

  return async function authGuard(
    to: RouteLocationNormalized,
  ): Promise<true | RouteLocationRaw> {
    const authStore = useAuthStore();

    if (!initialized) {
      initialized = true;
      try {
        await authStore.fetchMe();
      } catch {
        authStore.clearSession();
      }
    }

    if (to.meta.layout === 'h5' || to.path === '/403') {
      return true;
    }

    if (to.path === '/login') {
      return authStore.isLoggedIn ? { path: '/workbench' } : true;
    }

    if (!authStore.isLoggedIn) {
      return {
        path: '/login',
        query: { redirect: to.fullPath },
      };
    }

    const requiredRoles = to.meta.roles;
    if (
      requiredRoles?.length &&
      (!authStore.role || !requiredRoles.includes(authStore.role))
    ) {
      return { path: '/403' };
    }

    return true;
  };
}

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [],
});

sharedRoutes.forEach((route) => {
  router.addRoute(route);
});

const viewRouteModules = import.meta.glob<RoutesModule>(
  '@/views/*/routes.ts',
  { eager: true },
);

Object.values(viewRouteModules).forEach((module) => {
  module.default.forEach((record) => {
    router.addRoute('root', record);
  });
});

router.beforeEach(createAuthGuard());

export default router;
