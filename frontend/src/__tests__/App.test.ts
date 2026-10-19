import { mount } from '@vue/test-utils';
import Antd from 'ant-design-vue';
import { createPinia } from 'pinia';
import {
  createMemoryHistory,
  createRouter,
  type RouteRecordRaw,
} from 'vue-router';
import { describe, expect, it } from 'vitest';

import App from '../App.vue';

const StubPage = { template: '<div data-test="page" />' };

function createLayoutRouter(layout: 'app' | 'h5' | 'blank') {
  const routes: RouteRecordRaw[] = [
    {
      path: '/',
      name: 'layout-test',
      component: StubPage,
      meta: { layout },
    },
  ];
  return createRouter({
    history: createMemoryHistory(),
    routes,
  });
}

async function mountForLayout(layout: 'app' | 'h5' | 'blank') {
  const router = createLayoutRouter(layout);
  await router.push('/');
  await router.isReady();

  return mount(App, {
    global: {
      plugins: [createPinia(), router, Antd],
    },
  });
}

describe('App', () => {
  it('renders AppLayout for app routes', async () => {
    const wrapper = await mountForLayout('app');

    expect(wrapper.find('.app-layout').exists()).toBe(true);
    expect(wrapper.find('[data-test="page"]').exists()).toBe(true);
  });

  it('renders H5Layout for H5 routes', async () => {
    const wrapper = await mountForLayout('h5');

    expect(wrapper.find('.h5-layout').exists()).toBe(true);
    expect(wrapper.find('[data-test="page"]').exists()).toBe(true);
  });

  it('renders no shell layout for blank routes', async () => {
    const wrapper = await mountForLayout('blank');

    expect(wrapper.find('.app-layout').exists()).toBe(false);
    expect(wrapper.find('.h5-layout').exists()).toBe(false);
    expect(wrapper.find('[data-test="page"]').exists()).toBe(true);
  });
});
