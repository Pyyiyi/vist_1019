import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import App from '../App.vue';

describe('App', () => {
  it('renders the required page title', () => {
    const wrapper = mount(App);

    expect(wrapper.get('h1').text()).toBe('校园访客系统');
  });
});
