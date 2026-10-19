import type { RouteRecordRaw } from 'vue-router';

import RouterContainer from '@/components/RouterContainer.vue';
import { useAuthStore } from '@/stores/auth';

function redirectUnknownRoute(): { path: string } {
  const authStore = useAuthStore();
  return { path: authStore.isLoggedIn ? '/workbench' : '/login' };
}

export const sharedRoutes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'root',
    component: RouterContainer,
    redirect: '/login',
    children: [
      {
        path: ':pathMatch(.*)*',
        name: 'root-catch-all',
        redirect: redirectUnknownRoute,
      },
    ],
  },
  {
    path: '/h5',
    name: 'h5',
    component: RouterContainer,
    redirect: '/h5/apply',
    children: [
      {
        path: ':pathMatch(.*)*',
        name: 'h5-catch-all',
        redirect: '/h5/apply',
      },
    ],
  },
];
