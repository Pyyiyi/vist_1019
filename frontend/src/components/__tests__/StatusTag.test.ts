import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import Antd from 'ant-design-vue';
import StatusTag from '../StatusTag.vue';

const mountOptions = {
  global: {
    plugins: [Antd],
  },
};

describe('StatusTag', () => {
  const appointmentStatuses = [
    '待审核',
    '已通过',
    '已拒绝',
    '已改期',
    '已过期',
    '已到访(在校中)',
    '已离校',
    '已取消',
  ];

  const incidentStatuses = ['待处理', '已处理', '已忽略'];
  const softStatuses = ['在用', '停用'];

  it('defines all eight appointment statuses', () => {
    expect(appointmentStatuses).toHaveLength(8);
  });

  it.each(appointmentStatuses)('renders appointment status %s', (status) => {
    const wrapper = mount(StatusTag, {
      props: { status, kind: 'appointment' },
      ...mountOptions,
    });

    expect(wrapper.text()).toBe(status);
  });

  it('defines all three incident statuses', () => {
    expect(incidentStatuses).toHaveLength(3);
  });

  it.each(incidentStatuses)('renders incident status %s', (status) => {
    const wrapper = mount(StatusTag, {
      props: { status, kind: 'incident' },
      ...mountOptions,
    });

    expect(wrapper.text()).toBe(status);
  });

  it.each(softStatuses)('renders soft status %s', (status) => {
    const wrapper = mount(StatusTag, {
      props: { status, kind: 'soft' },
      ...mountOptions,
    });

    expect(wrapper.text()).toBe(status);
  });
});
