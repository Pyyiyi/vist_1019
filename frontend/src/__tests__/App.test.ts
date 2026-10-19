import { mount } from '@vue/test-utils';
import Antd from 'ant-design-vue';
import { createPinia } from 'pinia';
import { describe, expect, it } from 'vitest';

import App from '../App.vue';

describe('App', () => {
  it('renders the required page title', () => {
    const wrapper = mount(App, {
      global: {
        plugins: [createPinia(), Antd],
      },
    });

    expect(wrapper.get('h1').text()).toBe('校园访客系统');
  });
});
