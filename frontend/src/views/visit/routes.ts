import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    path: '/appointments',
    name: 'appointments',
    component: () => import('./AppointmentsPage.vue'),
    meta: { layout: 'app', roles: ['admin', 'host'], title: '访客预约' },
  },
  {
    path: '/reviews',
    name: 'reviews',
    component: () => import('./ReviewsPage.vue'),
    meta: { layout: 'app', roles: ['admin', 'host'], title: '被访人审核' },
  },
  {
    path: '/gate',
    name: 'gate',
    component: () => import('./GatePage.vue'),
    meta: { layout: 'app', roles: ['admin', 'guard'], title: '门卫核验放行' },
  },
  {
    path: '/h5/apply',
    name: 'h5-apply',
    component: () => import('./H5ApplyPage.vue'),
    meta: { layout: 'h5', title: '来访申请' },
  },
  {
    path: '/h5/my',
    name: 'h5-my',
    component: () => import('./H5MyPage.vue'),
    meta: { layout: 'h5', title: '我的申请' },
  },
  {
    path: '/h5/privacy',
    name: 'h5-privacy',
    component: () => import('./H5PrivacyPage.vue'),
    meta: { layout: 'h5', title: '个人信息说明' },
  },
];

export default routes;
