import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'login',
    component: () => import('./LoginPage.vue'),
    meta: { layout: 'blank', title: '登录' },
  },
  {
    path: '/403',
    name: 'forbidden',
    component: () => import('./ForbiddenPage.vue'),
    meta: { layout: 'blank', title: '无权访问' },
  },
  {
    path: '/workbench',
    name: 'workbench',
    component: () => import('./WorkbenchPage.vue'),
    meta: { layout: 'app', roles: ['admin', 'guard', 'host'], title: '工作台' },
  },
  {
    path: '/users',
    name: 'users',
    component: () => import('./UsersPage.vue'),
    meta: { layout: 'app', roles: ['admin'], title: '用户与角色' },
  },
];

export default routes;
